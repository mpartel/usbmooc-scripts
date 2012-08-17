#!/usr/bin/env ruby

$LOAD_PATH << File.dirname(File.realpath(__FILE__))

require 'shellwords'
require 'tempfile'
require 'disk_image'
require 'mountpoint'
require 'shell_utils'

class DiskResizeOperation
  def initialize(old_imgfile, new_imgfile)
    raise "Source and destination file may not be the same" if File.realpath(old_imgfile) == File.realpath(new_imgfile)
    
    @old_imgfile = old_imgfile
    @new_imgfile = new_imgfile
    @new_size = file_or_blockdev_size(new_imgfile)
    @old_disk = DiskImage.new(old_imgfile)
    
    find_partitions
    plan_commands
  end
  
  def print_plan
    puts "=== Resize plan (size change: #{@size_delta} bytes) ==="
    for command in @commands
      puts command.to_s
    end
  end
  
  def execute
    for command in @commands
      puts "Executing: #{command.to_s}"
      command.call
    end
  end
  
  def dest_is_blockdev?
    File.blockdev?(@new_imgfile)
  end
  
private
  def file_or_blockdev_size(path)
    if File.blockdev?(path)
      ShellUtils.sh!(['blockdev', '--getsize64', path]).strip.to_i
    else
      File.size(path)
    end
  end

  def find_partitions
    @partitions = @old_disk.partitions
    if @partitions.empty?
      raise "Empty partition table in source file"
    end
    if @old_disk.single_main_partition.index != 1
      raise "We only support a main partition that is the first primary partition"
    end
    @main_partition = @partitions.find {|part| part.index == 1 }
    @size_delta = @new_size - File.size(@old_imgfile)
    
    if @main_partition.size + @size_delta < min_partition_size
      raise "Certainly not enough room left for shrunk main partition."
    end
  end
  
  def min_partition_size
    1*1024*1024 # Let's say 1MB
  end
  
  def plan_commands
    @commands = []
    
    parted_cmd = ['parted', '-s', '-m', @new_imgfile]
    
    # Zero out the file
    if !dest_is_blockdev?
      @commands << ['truncate', '-s', '0', @new_imgfile]
      @commands << ['truncate', '-s', "#{@new_size}", @new_imgfile]
    end
    
    # Create partition table
    @commands << parted_cmd + ['mklabel', 'msdos']
    
    # Shrink main partition
    if @size_delta < 0
      @commands << PartitionResizeCommand.new(
        @old_imgfile,
        @main_partition.offset,
        @main_partition.size,
        @main_partition.size + @size_delta
      )
      main_part_copy_size = @main_partition.size + @size_delta
    else
      main_part_copy_size = @main_partition.size
    end
    
    # Create partitions and copy them over
    copy_ops = []
    part_start = @main_partition.offset
    part_end = @main_partition.end_offset + @size_delta
    @commands << parted_cmd + ['mkpart', @main_partition.partition_type, "#{part_start}B", "#{part_end}B"]
    @commands << parted_cmd + ['set', 1, 'boot', 'on']
    copy_ops << CopyCommand.new(@old_imgfile, @new_imgfile, @main_partition.offset, part_start, main_part_copy_size)
    
    @partitions.reject {|part| part == @main_partition }.each do |part|
      if part.offset < @main_partition.offset
        raise "There was a partition before the main partition. This is not currently supported."
      end
      part_start = part.offset + @size_delta
      part_end = part.end_offset + @size_delta
      @commands << parted_cmd + ['mkpart', part.partition_type, "#{part_start}B", "#{part_end}B"]
      if part.partition_type != 'extended'
        copy_ops << CopyCommand.new(@old_imgfile, @new_imgfile, part.offset, part_start, part.size)
      end
    end
    
    @commands += copy_ops
    
    # Grow main partition back to original size
    if @size_delta < 0
      @commands << PartitionResizeCommand.new(
        @old_imgfile,
        @main_partition.offset,
        @main_partition.size + @size_delta,
        @main_partition.size
      )
    end
    
    # Grow new partition
    if @size_delta > 0
      @commands << PartitionResizeCommand.new(
        @new_imgfile,
        @main_partition.offset,
        @main_partition.size,
        @main_partition.size + @size_delta
      )
    end
    
    # Update GRUB
    raise "Please run 'make' in chrooter/ first." unless File.exist?('chrooter/build/linux.uml')
    @commands << [
      'chrooter/build/linux.uml',
      'mem=64M',
      "ubda=#{@new_imgfile}",
      'initrd=chrooter/build/initrd.img',
      'con=null',
      'REINSTALL_GRUB'
    ]
    
    @commands << ['sync']
    
    @commands.map! do |cmd|
      if cmd.is_a?(Array)
        ShellCommand.new(cmd)
      else
        cmd
      end
    end
  end
  
  class ShellCommand
    def initialize(cmd_array)
      @cmd_array = cmd_array.map(&:to_s)
    end
    
    def call
      ShellUtils.sh!(@cmd_array)
    end
    
    def to_s
      Shellwords.join(@cmd_array)
    end
  end
  
  CopyCommand = Struct.new(:from_file, :to_file, :from_offset, :to_offset, :size)
  class CopyCommand
    def call
      File.open(from_file, 'rb') do |fin|
        File.open(to_file, 'r+b') do |fout|
          fin.seek(from_offset)
          fout.seek(to_offset)
          
          chunk_size = 32*1024*1024
          buf = ""
          remaining = size
          while remaining > 0
            fin.read([remaining, chunk_size].min, buf)
            fout.write(buf)
            remaining -= buf.size
          end
        end
      end
    end
    
    def to_s
      "<copy #{size} bytes from #{from_file} offset #{from_offset} to #{to_file} offset #{to_offset}>"
    end
  end
  
  PartitionResizeCommand = Struct.new(:img_path, :offset, :old_size, :new_size)
  class PartitionResizeCommand
    def call
      mountpoint = Mountpoint.new({
        :img_path => img_path,
        :dir_path => Mountpoint.default_mntdir,
        :loopback_only => true,
        :offset => offset,
        :size => [old_size, new_size].max
      })
      mountpoint.mount do
        # Could eventually drop the need for root permissions if this were done through UML
        # instead of a loopback file. Alternatively it could be copied to a tempfile.
        lofile = mountpoint.loopback_file
        fsck! lofile
        begin
          puts "Running resize2fs..."
          ShellUtils.sh! ["resize2fs", lofile, "#{new_size / 1024}K"]
        ensure
          begin
            fsck! lofile
          rescue
          end
        end
      end
    end
    
    def fsck!(file)
      puts "Running fsck..."
      ShellUtils.sh! ["e2fsck", "-f", "-p", file]
    end
    
    def to_s
      "<resize2fs in #{img_path} at #{offset} from #{old_size} to #{new_size}>"
    end
  end
end


if ARGV.size != 2 || ARGV.any? {|a| ['-h', '--help'].include?(a) }
  puts "Usage: resize_disk.rb <old_disk_or_image> <new_disk_or_image>"
  puts 
  puts "Must be run as root."
  puts "There will be an interactive confirmation before changes are written."
  puts
  exit 1
end

raise "Must be run as root" if Process.uid != 0

old_imgfile = ARGV[0]
new_imgfile = ARGV[1]

operation = DiskResizeOperation.new(old_imgfile, new_imgfile)
operation.print_plan
puts
puts "Shall I proceed? (y/n)"
if $stdin.gets.strip.downcase == 'y'
  operation.execute
else
  puts "Ok, cancelling"
end



