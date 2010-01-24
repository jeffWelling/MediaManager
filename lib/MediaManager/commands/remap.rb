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
#This file will hold the code for the part of the program that creates shortcuts from the media to the Library dir.
module MediaManager
  module Command
    #This module assists with the creation of a Library from your media database
    module Remap
      def parser(o)
        o.banner= "Usage: mmanager remap"
      end
      
      def execute
        MMCommon.pprint "Finish me!"
      end
    end
  end
end
