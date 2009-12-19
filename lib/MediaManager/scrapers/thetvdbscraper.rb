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
      class << self
        def search str
          require 'pp'
          results= [Thetvdb.search(str)]
          return [] if results[0].class==Hash and results[0].empty?
          details= Thetvdb.formatTvdbResults results[0]
          results= results[0]  #Should now be a hash

          series={}
          series_details={}
          results['Series'].each {|series_hash|
            series.merge!({  series_hash['id'][0] => flatten(series_hash) })
          }
          details.each {|details_hash|
            series_details.merge!({ details_hash['tvdbSeriesID'][0] => flatten(details_hash) })
          }

          list_of_results=[] 
          series_details.each_pair {|k,h|
            $it=h
            puts h.inspect
            h['EpisodeList'].each {|episode|
              item=MediaManager::Media::TVShow.new
              item.tvdb_series_ID= h['tvdbSeriesID'] 
              item.title= h['Title']
              item.episode_ID= episode['EpisodeID']
              item.episode_number= episode['EpisodeNumber']
              item.season= episode['Season']
              item.series_first_aired= series[item.tvdb_series_ID]['FirstAired']
              item.banners= series[item.tvdb_series_ID]['banner']  if series[item.tvdb_series_ID].has_key?('banner')
              item.series_overview= series[item.tvdb_series_ID]['Overview']
              item.language= series[item.tvdb_series_ID]['language']
              list_of_results << item
            }
          }
          list_of_results
        end
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
