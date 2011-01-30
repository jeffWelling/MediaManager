#!/usr/bin/env ruby
#You're expected to be in the MediaManager project base dir
require 'fileutils'
require 'lib/MediaManager.rb'
require 'pp'

module MMSpecUtils
  #scans a dir, and saves all of the path names to a file
  #Intended use is for taking a snapshot of existing raw,
  #freshly downloaded file names, for use match testing
  def self.scanDir to_scan, output_file='scanned_list.txt'
    puts "Searching for #{to_scan}"
    Dir.glob( to_scan ) {|path| puts path}
  end
end

#If there are arguments, pass them, otherwise don't.
$*==[] ? MMSpecUtils.scanDir : MMSpecUtils.scanDir($*)

#If MMSpecUtils is being run, not simply loaded
if $0 == __FILE__
  #Do things 
  
end
