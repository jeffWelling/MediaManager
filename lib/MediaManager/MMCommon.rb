=begin
  Copyright 2009, Jeff Welling

    This file is part of MediaManager.

    MediaManager is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    MediaManager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MediaManager.  If not, see <http://www.gnu.org/licenses/>.
  
=end
module MediaManager
  #Functions/methods that are common to all of the MediaManager app
  class MMCommon
    class << self
      #scans a target, returning the full path of every item found, in an array
      def scan_target target
        items=[]
        Find.find(File.expand_path(target)) do |it|
          items << it
        end
        items
      end

      #returns true if str matches any of the exclusion matches
      #ar_of_excludes must be an array of regexes
      def excluded? str, ar_of_excludes
        ar_of_excludes.each {|exclude|
          return true if str.match(exclude)
        }
        false
      end

      def pprint str
        puts str
      end

      def readConfig filename=nil
        filename||= $config_file
        return OpenStruct.new unless File.exists?(File.expand_path(filename))
        YAML.load readFile(filename).join
      end

      def saveConfig config, filename=nil
        filename||= $config_file
        writeFile( YAML.dump(config), filename)
      end

      def writeFile contents, filename
        File.open( File.expand_path(filename), 'w') {|f| f.write contents }
      end
      def readFile filename, maxlines=0
        i=0
        read_so_far=[]
        f=File.open(File.expand_path(filename), 'r')
        while (line=f.gets)
          break if maxlines!=0 and i >= maxlines
          read_so_far << line and i+=1
        end
        read_so_far
      end
    end
  end
end
