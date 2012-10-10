#!/usr/bin/env ruby

require 'shellwords'

if ARGV.empty? || ARGV.any? {|a| ['-h', '--help'].include?(a) }
  puts "Usage: write-to-all-disks.rb <image-file>"
  exit(1)
end

image_file = ARGV[0]

def get_current_devices
  Dir.glob('/dev/sd?')
end

ignored_devices = get_current_devices.sort

puts <<EOS
Ok, listen up!
This script will wait for USB media to be plugged in and
then it will OVERWRITE THEM ALL with the given disk image!

More precisely, it operates as follows:
First it will look at all initial /dev/sd? files and
put them in a safe list. Then it will poll for all /dev/sd?
every 0.5 seconds to see if new ones appeared or old ones
were removed. Whenever a new one appears, the script
forks a 'dd' process to overwrite it. It should be safe
to remove it after a few seconds.

The script may be stopped with Ctrl+C.
EOS

puts
puts "/dev/sd? disks currently plugged in that will not be written to:"
ignored_devices.each do |dev|
  puts dev
end

unless Process.pid == 0
  puts
  puts "You probably want to run this as root."
end

puts
print 'If you understand and accept the above, please type "Yes" > '
confirmation = $stdin.gets.strip.downcase

if confirmation != 'yes'
    puts "Exiting"
    exit
end

puts
puts
puts "Waiting for new devices..."


stop = false
trap("SIGINT") do
  stop = true;
end

active_devices = []
dd_pids = []
until stop
  sleep 0.5
  current_devices = get_current_devices
  new_devices = current_devices - ignored_devices - active_devices
  active_devices = current_devices - ignored_devices

  new_devices.each do |dev|
    puts "Writing to #{dev}"
    pid = Process.spawn(Shellwords.join(['dd', 'if=' + image_file, 'of=' + dev, 'bs=8M']))
    dd_pids << pid
  end

  unless dd_pids.empty?
    pid = Process.waitpid(-1, Process::WNOHANG)
    if pid
      system("sync &")
      dd_pids.delete(pid)
    end
  end
end
