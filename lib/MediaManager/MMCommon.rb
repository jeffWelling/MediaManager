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
  module MMCommon
    #scans a target, returning the full path of every item found, in an array
    def self.scan_target target
      items=[]
      Find.find(target) do |it|
        items << it
      end
      items
    end

    #returns true if str matches any of the exclusion matches
    #ar_of_excludes must be an array of regexes
    def self.excluded? str, ar_of_excludes
      ar_of_excludes.each {|exclude|
        return true if str.match(exclude)
      }
      false
    end

    def self.pprint str
      puts str
    end

    def self.readConfig filename=nil
			filename||= $config_file
      return {} unless File.exists?(filename)
			YAML.load File.read(File.expand_path(filename)
    end

    def self.saveConfig config, filename=nil
		  filename||= $config_file
			File.open( File.expand_path(filename), 'w') {|f| f.write config.to_yaml }
    end  
  end
end
