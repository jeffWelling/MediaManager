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
        MMCommon.pprint "importing!"
      end
    end
  end
end
