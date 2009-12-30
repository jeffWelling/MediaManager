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
  module Media
    #Ever file in the library will be represented by an object, this class defines those objects such as movies, tv shows, books, pictures...
    class MediaFile
      @categoryTags=nil
      @title=nil
      @path=nil
      attr_accessor :path, :title, :categoryTags
      #get_compare_strings is expected to return an array of strings to use in comparisons (strings such as title,  episode name, etc)
      #called by Match.compare(path, MediaFile).
      def get_compare_strings
        [@title]
      end
    end

    class Movie<MediaFile
      def get_compare_strings
        [@title, @alternative_title]
      end
      @overview=nil
      @tmdb_id=nil
      @imdb_id=nil
      @movie_type=nil
      @tmdb_url=nil
      @tmdb_popularity=nil
      @alternative_title=nil
      @released=nil
      @posters=nil
      @homepage=nil
      @trailer=nil
      @runtime=nil
      @genres=nil
      @cast=nil
      @countries=nil
      @rating=nil
      @backdrops=nil
      @studios=nil
      @budget=nil
      @score=nil
      @revenue=nil
      attr_accessor :overview, :tmdb_id, :imdb_id, :movie_type, :tmdb_url, :tmdb_popularity,
        :alternative_title, :released, :posters, :homepage, :trailer, :runtime, :genres,
        :cast, :countries, :rating, :backdrops, :studios, :budget, :score, :revenue 
    end
    class TVShow<MediaFile
      def get_compare_strings
        [@title, @episode_name]
      end                    #Thetvdb API key map
      @tvdb_series_ID=nil    #thetvdbSeriesID, id, seriesid
      @episode_ID=nil         #episodeID
      @episode_number=nil     #EpisodeNumber
      @episode_name=nil       #EpisodeName
      @season=nil            #Season
      @series_first_aired=nil#FirstAired
      @banners=[]            #banner
      @series_overview=nil   #Overview
      @language=nil          #lang
      @title=nil             #SeriesName, Title
      attr_accessor :tvdb_series_ID, :episode_ID, :episode_number, :episode_name, :season, :series_first_aired, :banners,
        :series_overview, :language, :title
    end
  end
end
