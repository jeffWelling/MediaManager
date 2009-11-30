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
  #This module interfaces with the various scrapers.
  #It will only return MediaFiles so you don't have to worry about dealing with various formats
  #for each of the scrapers. 
  module Scrapers
    SCRAPERS=[]
    class << self
      #Load the scrapers in the scrapers/ dir.
      def loadScrapers
        Dir.glob(File.expand_path("lib/MediaManager/scrapers/*")).each {|scraper|
          load scraper
          SCRAPERS << eval( "MediaManager::Scrapers::#{File.basename(scraper, '.rb').capitalize}" )
          SCRAPERS.uniq!
        }
      end
      def wrapper searchterm,  &block
        yield(searchterm)
      end
      #search all available scrapers for str, returning all results (which will be MediaFiles or decendants of)
      def searchFor str
        results=[]
        SCRAPERS.each {|scraper|
          extend(scraper)
          (results += wrapper(str, &method(:search)) )
        }
        results
      end
    end
    loadScrapers
  end
end
