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
  #Metadata is a class to assist with working with, extracting and manipulating of, media metadata.
  class Metadata
    class << self
      #Extract an episodeID from a string, return it as an array.  
      #Multiple episodeIDs will be returned respectively in the array by operating recursively on str.
      #Standard is to not reformat the output, which produces an episodeID in the format of "S02E13".
      def extractEpID str, reformat=nil
        #This regex is intended to match the 'S02E13' and '2x13' formats of episodeIDs.
        episodeID_regex=/(s[\d]+e[\d]+|[\d]+x[\d]+)/i
        return nil if ( episodeID=str[episodeID_regex] ).nil?

        sane_series_range=    1..99
        sane_episode_range=   1..700  #Increase this, if you ever come across something with a legit epID >700
        
        #Get the series number, strip out any "s" or "x" we may have matched before
        series_num= episodeID[/^(s)?[\d]+/i]
        series_num= series_num.reverse.chop.reverse if series_num.include?('s') or series_num.include?('S')
        series_num= series_num.to_i

        #Do the same for the episode number
        episode_num= episodeID[/[\d]+$/].to_i

        unless sane_series_range.include?(series_num) and sane_episode_range.include?(episode_num)
          #The episodeID we locked onto is bad, discard it and start over.
          return extractEpID(str.gsub(episodeID, ''), reformat)
        end

        if !reformat.nil?
          return ([episodeID] + [getEpisodeID(str.gsub(episodeID, ''), reformat)] ).flatten if getEpisodeID(str.gsub(episodeID, ''), reformat)
          return episodeID
        end
      end
    end
  end
end
