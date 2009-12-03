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
      @title=nil
      @path=nil
      attr_reader :path, :title
    end
    class Movie<MediaFile
    end
    class TVShow<MediaFile
      @tvdb_series_ID=nil    #thetvdbSeriesID, id, seriesid
      @episode_ID=nil         #episodeID
      @episode_number=nil     #episodeNumber
      @season=nil            #Season
      @series_ID=nil          #seriesID
      @series_first_aired=nil#FirstAired
      @banners=[]            #banner
      @series_overview=nil   #Overview
      @language=nil          #lang
      @title=nil             #SeriesName, Title
      attr_reader :tvdb_series_ID, :episode_ID, :episode_number, :season, :series_ID, :series_first_aired, :banners,
        :series_overview, :language, :title
    end
  end
end
