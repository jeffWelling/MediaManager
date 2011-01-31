#!/usr/bin/env ruby
#You're expected to be in the MediaManager project base dir
require 'fileutils'
require 'lib/MediaManager.rb'
require 'pp'
require 'find'

module MMSpecUtils
  @@filename='scanned_list.txt'

  #scans a dir, and saves all of the path names to a file
  #Intended use is for taking a snapshot of existing raw,
  #freshly downloaded file names, for use match testing
  def self.scanDir to_scan, output_file=@@filename
    raise "MMSpecUtils.scanDir()'s to_scan argument must be a string or array of strings" unless
      to_scan.class==String or to_scan.class==Array
    raise "MMSpecUtils.scanDir()'s output_file argument must be a string" unless
      output_file.class==String

    File.delete output_file
    glob=Array.new
    puts "Scanning #{to_scan}"
    to_scan=[to_scan] unless to_scan.class==Array
    to_scan.each {|path_to_scan|
      Find.find( path_to_scan ) {|path| 
        puts path
        path= path + "\n"
        glob.push path unless glob.include? path
      }
    }

    MediaManager::MMCommon.writeFile( glob, output_file )
    glob
  end
end

#If __FILE__ is "(eval)", we are likely bring run through
#the interactive_editor gem.
if __FILE__ == "(eval)"
  MMSpecUtils.makeFakeFiles "/tmp/fakefiles"
else
  MMSpecUtils.makeFakeFiles $*[0]
end

#If MMSpecUtils is being run, not simply loaded
if $0 == __FILE__
  #Do things 
  
end
