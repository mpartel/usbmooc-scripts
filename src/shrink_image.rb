#!/usr/bin/env ruby

$LOAD_PATH << File.dirname(File.realpath(__FILE__))

require 'shellwords'
require 'tempfile'
require 'disk_image'
require 'mountpoint'
require 'shell_utils'

class DiskShrinkOperation
  def initialize(imgfile)
    @imgfile = imgfile
    @disk = DiskImage.new(imgfile)
  end
  
  def execute
    main_partition = find_main_partition
    new_size = shrink_fs(@imgfile, main_partition.offset, main_partition.size)
    rebuild_partition_table(main_partition, new_size)
    main_partition = find_main_partition # read changed partition table
    shrink_image_file(main_partition.end_offset)
    update_grub
    ShellUtils.sh! 'sync'
  end
  
private
  def find_main_partition
    partitions = @disk.partitions
    raise "Empty partition table in source file" if partitions.empty?
    raise "We currently only support one partition images" if partitions.size > 1
    raise "We only support a main partition that is the first primary partition" if @disk.single_main_partition.index != 1
    partitions.find {|part| part.index == 1 }
  end
  
  def shrink_fs(img_path, offset, orig_size)
    mountpoint = Mountpoint.new({
      :img_path => img_path,
      :dir_path => Mountpoint.default_mntdir,
      :loopback_only => true,
      :offset => offset,
      :size => orig_size
    })
    mountpoint.mount do
      # Could eventually drop the need for root permissions if this were done through UML
      # instead of a loopback file. Alternatively it could be copied to a tempfile.
      lofile = mountpoint.loopback_file
      fsck lofile
      begin
        puts "Running resize2fs"
        output = ShellUtils.sh! ["resize2fs", '-M', lofile]

        if output.include?("Nothing to do!")
          puts "Partition already at minimum size"
          return orig_size
        end

        if output =~ /Resizing the filesystem.*\((\d+)k\) blocks./
          block_size = $1.to_i
        else
          raise "Unexpected output from resize2fs -M:\n#{output}"
        end

        if output =~ /The filesystem.*is now (\d+) blocks long./
          block_count = $1.to_i
        else
          raise "Unexpected output from resize2fs -M:\n#{output}"
        end

        return block_count * block_size * 1024
      ensure
        begin
          fsck lofile
        rescue
        end
      end
    end
  end

  def fsck(file)
    puts "Running fsck"
    output = `e2fsck -f -p #{Shellwords.escape(file)}`
    if !$?.exited? || ![0, 1].include?($?.exitstatus)
      raise "e2fsck exited with #{$?}. Output:\n#{output}"
    end
  end

  def parted(cmd)
    puts "Running parted command #{cmd.join(' ')}"
    ShellUtils.sh!(['parted', '-s', '-m', @imgfile] + cmd)
  end

  def rebuild_partition_table(partition, new_size)
    puts "Remaking partition table"
    parted ['mklabel', 'msdos']
    parted ['mkpart', partition.partition_type, "#{partition.offset}B", "#{partition.offset + new_size}B"]
    parted ['set', partition.index, 'boot', 'on']
  end

  def shrink_image_file(new_size)
    puts "Truncating image file"
    File.truncate(@imgfile, new_size)
  end

  def update_grub
    raise "Please run 'make' in chrooter/ first." unless File.exist?('chrooter/build/linux.uml')
    puts "Updating grub"
    ShellUtils.sh! [
      'chrooter/build/linux.uml',
      'mem=64M',
      "ubda=#{@imgfile}",
      'initrd=chrooter/build/initrd.img',
      'REINSTALL_GRUB'
    ]
  end
end


if ARGV.size != 1 || ARGV.any? {|a| ['-h', '--help'].include?(a) }
  puts "Usage: shrink_disk.rb <image>"
  puts 
  puts "Must be run as root."
  puts
  exit 1
end

raise "Must be run as root" if Process.uid != 0

imgfile = ARGV[0]

DiskShrinkOperation.new(imgfile).execute
