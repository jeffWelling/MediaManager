
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
#This file holds code for the part that hashes all of ze media filzes.
module MediaManager
  module Command
    module Hasher
      def parser(o)
        o.banner= "Usage: mmanager hasher"
      end
      def execute
        paths=Storage.readPaths
        hashes={}
        MMCommon.pprint "Hashing #{paths.length} items.  Turn the volcano on, this will take a while.\n"
        paths.each {|p|
          #p[0] = it's ID, and p[1]= the path
          hashes.merge!({ p[0] => [MMCommon.sha1(p[1], true), p[1]] })
        }
        Storage.saveHashes hashes.sort
      end
    end
  end
end
