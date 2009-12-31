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
  class LibraryData
    @path=nil
    @path_key=nil
    @MediaFile=nil
    @data=nil
    #return true if the object has not yet been positively identified as a movie, tvshow, etc.
    def unmatched?
      return false
    end
    class << self
      def loadLibraryData
        begin
          @data= Storage.loadLibraryData
        rescue Errno::ENOENT => e
          LibraryData.new
        end
      end
      def saveLibraryData
        Storage.saveLibraryData @data
      end
      def eachUnmatchedItem
        res=[]
        @data.each {|obj|
          res << obj unless obj.title or obj.episodeName
        }
        res
      end
    end
  end
end
