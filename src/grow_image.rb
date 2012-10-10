#!/usr/bin/env ruby

$LOAD_PATH << File.dirname(File.realpath(__FILE__))

require 'shellwords'
require 'tempfile'
require 'disk_image'
require 'mountpoint'
require 'shell_utils'
require 'misc'

class DiskGrowOperation
  def initialize(imgfile, new_size, options)
    if File.size(imgfile) > new_size
      raise "The image is already larger than the size you gave."
    end

    @options = {
      :img_only => false
    }.merge(options)

    @imgfile = imgfile
    @disk = DiskImage.new(imgfile)
    @new_size = new_size
  end

  def execute
    grow_image_file
    return if @options[:img_only]

    main_partition = find_main_partition
    rebuild_partition_table(main_partition, @new_size - main_partition.offset - end_padding)
    main_partition = find_main_partition
    grow_fs(@imgfile, main_partition.offset, main_partition.size)
    update_grub
    ShellUtils.sh! 'sync'
  end

private

  def grow_image_file
    puts "Growing image file"
    old_size = File.size(@imgfile)
    to_add = @new_size - old_size
    ShellUtils.sh! ['src/fallocator', @imgfile, old_size, to_add] unless to_add == 0
  end

  def find_main_partition
    partitions = @disk.partitions
    raise "Empty partition table in source file" if partitions.empty?
    raise "We currently only support one partition images" if partitions.size > 1
    raise "We only support a main partition that is the first primary partition" if @disk.single_main_partition.index != 1
    partitions.find {|part| part.index == 1 }
  end

  def grow_fs(img_path, offset, orig_size)
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
        output = ShellUtils.sh! ["resize2fs", lofile]

        if output.include?("Nothing to do!")
          puts "Partition already at maximum size"
        end
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

  def end_padding
    1024
  end

  def rebuild_partition_table(partition, new_partition_size)
    puts "Remaking partition table"
    parted ['mklabel', 'msdos']
    parted ['mkpart', partition.partition_type, "#{partition.offset}B", "#{partition.offset + new_partition_size}B"]
    parted ['set', partition.index, 'boot', 'on']
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


img_only = false

ARGV.reject! do |arg|
  if arg == '--img-only'
    img_only = true
    true
  else
    false
  end
end

if ARGV.size != 2 || ARGV.any? {|a| ['-h', '--help'].include?(a) }
  puts "Usage: grow_disk.rb <image> [--img-only] <new_size>"
  puts
  puts "Must be run as root."
  puts
  puts "  --img-only resizes the image but not the partition nor the file system"
  puts
  exit 1
end

raise "Must be run as root" if Process.uid != 0

imgfile = ARGV[0]
new_size = Misc.parse_size(ARGV[1])

DiskGrowOperation.new(imgfile, new_size, :img_only => img_only).execute
