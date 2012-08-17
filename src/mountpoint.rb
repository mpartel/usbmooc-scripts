
require 'fileutils'
require 'shell_utils'

class Mountpoint
  def self.default_mntdir
    @default_mntdir ||= begin
      path = File.dirname(File.dirname(File.realpath(__FILE__))) + '/mnt'
      FileUtils.mkdir_p(path)
      path
    end
  end
  
  @@active_mountpoints = []
  
  def initialize(options = {})
    self.options = options
    
    @loopback_file = nil
    @mounted = false
  end
  
  def img_path
    @options[:img_path]
  end
  
  def dir_path
    @options[:dir_path]
  end
  
  def options=(new_options)
    raise "Cannot change options while mounted" if @mounted
    
    @options = {
      :img_path => nil,
      :dir_path => nil,
      :loopback => false,
      :offset => nil,
      :size => nil,
      :loopback_only => false
    }.merge(new_options)
    
    @options[:loopback] = true if @options[:loopback_only]
  end
  
  def loopback?
    @options[:loopback]
  end
  
  def loopback_only?
    @options[:loopback_only]
  end
  
  attr_reader :loopback_file
  
  def mount
    raise "already mounted" if @mounted
    
    if loopback?
      cmd = ['losetup']
      cmd << '--offset' << @options[:offset] if @options[:offset]
      cmd << '--sizelimit' << @options[:size] if @options[:size]
      cmd << '-f'
      cmd << '--show'
      cmd << img_path
      @loopback_file = sh!(cmd).strip
      mount_file = @loopback_file
    else
      mount_file = img_path
    end
    
    sh!(['mount', mount_file, dir_path]) unless loopback_only?
    
    @mounted = true
    @@active_mountpoints << self
    
    if block_given?
      begin
        yield
      ensure
        begin
          `sync`
          sleep 1
          umount
        rescue
          puts "Warning: failed to unmount #{img_path}: #{$!.message}"
        end
      end
    end
  end
  
  def umount
    if @mounted
      sh!(['umount', img_path]) unless loopback_only?
      @mounted = false
      @@active_mountpoints.delete(self)
    end
    
    if @loopback_file
      sh!(['losetup', '-d', @loopback_file])
      @loopback_file = nil
    end
  end
  
  def self.umount_all
    `sync`
    sleep 1 unless @@active_mountpoints.empty?
    while !@@active_mountpoints.empty?
      @@active_mountpoints.pop.umount
    end
  end
  
private
  def sh!(cmd)
    ShellUtils.sh!(cmd)
  end
end

at_exit { Mountpoint.umount_all }

