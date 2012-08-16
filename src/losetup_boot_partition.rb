#!/usr/bin/env ruby

$LOAD_PATH << File.dirname(File.realpath(__FILE__))

require 'shellwords'
require 'disk_image'

if ARGV.size != 1 || ARGV.any? {|a| ['-h', '--help'].include?(a) }
  puts "Usage: partition_offset.rb <disk_or_image_file>"
  exit(1)
end

imgfile = File.realpath(ARGV[0])

disk = DiskImage.new(imgfile)
target = disk.single_main_partition

exec("losetup --offset #{target.offset} --sizelimit #{target.size} -f --show #{Shellwords.escape(imgfile)}")

