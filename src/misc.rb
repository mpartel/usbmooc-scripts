
module Misc
  def self.parse_size(size)
    return size if size.is_a?(Integer)
    return size.to_i if size =~ /^\d+B?$/

    if size =~ /^(\d+)(k|M|G)B?$/
      $1.to_i * case $2
      when 'k'; 1024
      when 'M'; 1024*1024
      when 'G'; 1024*1024*1024
      end
    else
      raise "Invalid size: #{size}"
    end
  end
end
