
require 'shellwords'

class DiskImage
  class Partition
    def initialize(args)
      for k, v in args
        self.instance_variable_set ('@' + k.to_s).to_sym, v
      end
    end
    
    attr_accessor :index, :offset, :size, :fs, :partition_type, :flags
    
    def end_offset
      offset + size
    end
    
    def main_partition?
      flags == 'boot' && fs == 'ext4'
    end
    
    def contains?(other)
      self.offset >= other.offset && self.end_offset <= other.end_offset
    end
  end

  def initialize(path)
    @path = File.realpath(path)
  end
  
  attr_reader :path
  
  def partitions
    lines = `parted -m -s #{Shellwords.escape(@path)} unit B print`.split("\n")
    raise "Parted command failed: #{$?}" unless $?.success?

    lines = lines.drop_while {|line| !line.start_with?(@path) }
    lines = lines.drop(1)
    lines = lines.take_while {|line| !line.empty? }
    raise "Parted returned weird output" if lines.empty?

    result = lines.map do |line|
      raise "Weird line by parted: #{line}" unless line.end_with?(";")
      cols = line.split(":")
      raise "Expected exactly 7 cols instead of #{cols.size} in line by parted: #{line}" if cols.size != 7
      
      Partition.new({
        :index => cols[0].to_i,
        :offset => cols[1].to_i,
        :size => cols[3].to_i,
        :fs => cols[4],
        :flags => cols[6][0..-2] # drop the semicolon
      })
    end
    
    result.each do |part|
      container = (result - [part]).find {|other| other.contains?(part) }
      if container
        part.partition_type = 'extended'
        container.partition_type = 'logical'
      else
        part.partition_type = 'primary' if part.partition_type == nil
      end
    end
    
    result
  end
  
  def main_partitions
    partitions.select(&:main_partition?)
  end
  
  def single_main_partition
    mps = main_partitions
    case mps.size
    when 0
      raise "No bootable ext4 partitions found"
    when 1
      mps.first
    else
      raise "More than one bootable ext4 partition found"
    end
  end
end
