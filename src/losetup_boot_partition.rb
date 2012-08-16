#!/usr/bin/env ruby

require 'shellwords'
require 'fileutils'

if ARGV.size != 1 || ARGV.any? {|a| ['-h', '--help'].include?(a) }
  puts "Usage: partition_offset.rb <disk_or_image_file>"
  exit(1)
end

imgfile = File.realpath(ARGV[0])

lines = `parted -m -s #{Shellwords.escape(imgfile)} unit B print list all`.split("\n")
raise "Parted command failed: #{$?}" unless $?.success?

lines = lines.drop_while {|line| !line.start_with?(imgfile) }
lines = lines.take_while {|line| !line.empty? }
raise "Parted returned weird output" if lines.empty?

partitions = []

lines.each do |line|
  raise "Weird line by parted: #{line}" unless line.end_with?(";")
  cols = line.split(":")
  raise "Expected exactly 7 cols instead of #{cols.size} in line by parted: #{line}" if cols.size != 7
  
  partitions << {
    :offset => cols[1].to_i,
    :size => cols[3].to_i,
    :fs => cols[4],
    :flags => cols[6][0..-2] # drop the semicolon
  }
  offset = cols[1]
  size = cols[3]
  fs = cols[4]
  flags = cols[6]
end


boot_partitions = partitions.select {|part| part[:flags] == 'boot' }

case boot_partitions.size
when 0
  raise "No bootable partitions found"
when 1
  target = boot_partitions.first
else
  raise "More than one bootable partition found"
end

exec("losetup --offset #{target[:offset]} --sizelimit #{target[:size]} -f --show #{Shellwords.escape(imgfile)}")
