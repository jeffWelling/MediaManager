#!/usr/bin/env ruby
require 'fileutils'

module MMSpecUtils
  #scans a dir, and saves all of the path names to a file
  def self.scanDir to_scan, output_file='output.txt'
    puts "Searching for #{to_scan}"
    Dir.glob( to_scan ) {|path| puts path}
  end
end

$*==[] ? MMSpecUtils.scanDir : MMSpecUtils.scanDir($*)

#If MMSpecUtils is being run, not simply loaded
if $0 == __FILE__
  #Do things 
  
end
