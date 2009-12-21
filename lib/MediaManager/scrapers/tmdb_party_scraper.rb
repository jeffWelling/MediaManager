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
  module Scrapers
    #Note that the name of the module is the same as the capitalized filename 
    module Tmdb_party_scraper
      #All scrapers should have a search() method
      #This search method should return an array of MediaFiles (or decendants)
      #MediaManager::Media::MediaFile
      class << self
        def search str
          tmdb= TMDBParty::Base.new MediaManager::MMCommon.readFile('tmdb_party/apikey.txt').first.strip
          results= tmdb.search str

          formatted_results=[]
          results.each {|result|
            formatted_results<< reformat(result)
          }
          formatted_results
        end
        def reformat result
          m=MediaManager::Media::Movie.new
          m.title= result.name
          m.overview= result.attributes['overview']
          m.tmdb_id= result.attributes['id']
          m.imdb_id= result.attributes['imdb_id']
          m.movie_type= result.attributes['movie_type']
          m.tmdb_url= result.attributes['url']
          m.tmdb_popularity= result.attributes['popularity']
          m.alternative_title= result.attributes['alternative_name']
          m.released= result.attributes['released'].to_s
          m.posters= result.posters
          m.homepage= result.homepage
          m.trailer= result.trailer
          m.runtime= result.runtime
          m.genres= result.genres
          m.cast= result.cast
          m.countries= result.attributes['countries']
          m.rating= result.attributes['rating']
          m.backdrops= result.backdrops
          m.studios= result.attributes['studios']
          m.budget= result.attributes['budget']
          m.score= result.score
          m.revenue= result.attributes['revenue']
          m
        end
      end
    end
  end
end
