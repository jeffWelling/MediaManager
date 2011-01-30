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
    raise "MMSpecUtils.scanDir()'s to_scan argument must be a string or array of strings" unless
      to_scan.class==String or to_scan.class==Array
    raise "MMSpecUtils.scanDir()'s output_file argument must be a string" unless
      output_file.class==String

    glob=Array.new
    puts "Scanning #{to_scan}"
    to_scan=[to_scan] unless to_scan.class==Array
    to_scan.each {|path_to_scan|
      Dir.glob( path_to_scan ) {|path| 
        puts path
        glob.push path unless glob.include? path
      }
    }
  end
end

#If there are arguments, pass them, otherwise don't.
$*==[] ? MMSpecUtils.scanDir : MMSpecUtils.scanDir($*)

#If MMSpecUtils is being run, not simply loaded
if $0 == __FILE__
  #Do things 
  
end
