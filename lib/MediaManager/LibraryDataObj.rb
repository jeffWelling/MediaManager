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
    def initialize(p, k)
      @path=p
      @path_key=k
      @@data={} unless @@data.class==Hash
      @MediaFile=nil
      @matched=false
      @@data.merge!({p=>self}) unless @@data.has_key? p
    end
    attr_accessor :path, :path_key, :matched
    #return true if the object has not yet been positively identified as a movie, tvshow, etc.
    def unmatched?
      !@matched
    end
    class << self
      def has_path p
        @@data.has_key? p rescue false
      end
      def loadLibraryData
        begin
          @@data= Storage.loadLibraryData
        rescue Errno::ENOENT => e
          {}
        end
      end
      def saveLibraryData
        Storage.saveLibraryData @@data
      end
      #return an array of every object that has yet to be positively identified
      def eachUnmatchedItem
        res=[]
        @@data.each_value {|obj|
          res << obj unless (obj.respond_to?(:title) and obj.title) or (obj.respond_to?(:episodeName) and obj.episodeName)
        } unless @@data.nil?
        res
      end
      def identifyFile path, mediaFile
        @@data[path]= mediaFile.matched=(true)
      end
      #Update @@data's instance of libr_obj
      def updateWith libr_obj
        @@data.has_key?(libr_obj.path) ? @@data[libr_obj.path]=libr_obj : @@data.merge!({libr_obj.path=>libr_obj})
      end
      def importPathsToLibrary
        paths=Storage.readPaths
        paths.each {|path|
          unless has_path(path[1])
            lib_obj=LibraryData.new(path[1], path[0])
            LibraryData.updateWith lib_obj
          end
        }
      end
    end
  end
end
