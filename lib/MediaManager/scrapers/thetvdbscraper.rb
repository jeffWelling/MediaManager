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
#Example scraper module
module MediaManager
  module Scrapers
    #Note that the name of the module is the same as the 
    module Thetvdbscraper
      #All scrapers should have a search() method
      #This search method should return an array of MediaFiles (or decendants)
      #MediaManager::Media::MediaFile
      def search str
        require 'pp'
        results= [Thetvdb.search(str)]
        return [] if results[0].class==Hash and results[0].empty?
        details= Thetvdb.formatTvdbResults results
        
        results
      end
      class << self
        #Takes a hash, expecting the values stored to be in an array such as [x].  It returns a hash with the values taken out of the array
        def flatten hash
          x={}
          hash.each_pair {|k,v|
            x.merge!({ k=> (v.class==Array and v.length == 1 ? (v[0]) : (v)) })
          }
          x
        end
      end
    end
  end
end
