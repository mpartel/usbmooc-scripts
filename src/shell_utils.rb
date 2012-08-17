
require 'shellwords'

module ShellUtils
  extend self
  
  def sh!(cmd)
    cmd = Shellwords.join(cmd.map(&:to_s)) if cmd.is_a?(Array)
    output = `#{cmd} 2>&1`
    raise "#{cmd} failed with status #{$?}. Output:\n#{output}" unless $?.success?
    output
  end
end

