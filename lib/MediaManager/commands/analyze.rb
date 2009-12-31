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
  module Command
    #Module to handle analyzing of files, determining which episode of which series, or what movie, a
    #file may be.
    module Analyze
      def parser(o)
        o.banner= "Usage: mmanager analyze\nThis will analyze every file that you have imported."
      end
      def execute
        MMCommon.pprint "holycrap! dont use me yet!\n"
        paths=Storage.readPaths
        pp paths.length
        LibraryData.loadLibraryData
        paths.each {|path|
          #paths needs to be added to LibraryData before here
          LibraryData.eachUnmatchedItem.each {|unmatched|
            results=[]
            search_terms=Metadata.getSearchTerms(unmatched)
            search_terms.each {|search_term|
              results += Scrapers.searchFor search_term
            }
            results.each {|result|
              LibraryData.identifyFile(path, result) if compare(path, result) 
            }
            
            #search for keywords found in path
            #for each search result, compare
            #set ID if compare
          }
        }
        LibraryData.saveLibraryData
        #read path_key to metadata list
        #for each un_id'd file, attempt to id
        #save all lists
        #exit
      end
    end
  end
end
