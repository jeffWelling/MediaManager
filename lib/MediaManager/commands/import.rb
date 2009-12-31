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
#This file will hold the code for the import part of  the program.
module MediaManager
  module Command
    #The importing module
    module Import
      def parser(o)
        o.banner= "Usage: mmanager import foo/bar/ foo/bar1\nAdds the dir foo/bar/ and the file foo/bar1"
      end
      def execute
        MMCommon.pprint "Importing!\n"
        import ARGV[0]
        MMCommon.pprint "Done!\n"
      end

      #Scan for files, import them into the db
      def import path
        i=0
        paths={}
        MMCommon.scan_target(File.expand_path(path)).each {|file_found|
          next if File.directory? file_found
          paths.merge!( {i=>file_found} )
          i+=1
        }
        Storage.savePaths paths.sort
        return nil
      end
    end
  end
end
