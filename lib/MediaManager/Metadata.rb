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

      #take a full file path and turn it into an array, including turning the extention into the first element.
      def pathToArray fPath
        return( [ fPath.match(/\..{3,4}$/)[0] , fPath.gsub(/\..{3,4}$/, '') ] ) unless fPath.include?('/')
        first=TRUE
        fPath = fPath.split('/').reverse.collect {|pathSeg|
          unless first==FALSE then
            first=FALSE
            extBegins= pathSeg=~/\.([^\.]+)$/
            if extBegins then pathSeg = { pathSeg.slice(0,extBegins) => pathSeg.slice(extBegins,pathSeg.length) } end
          end
          pathSeg
        }
        fPath.pop

        #Flatten it out again; make first element extention and second the file's name
        clipboard=fPath[0].select { TRUE }[0].reverse
        fPath = fPath.insert( 0,clipboard[0])
        fPath = fPath.insert( 1, clipboard[1])
        fPath.delete( fPath[2] )

        return fPath
      end

      def searchTermExcludes
        ['xvid', 'eng', 'ac3', 'dvdrip']
      end

      def getSearchTerms string, excludes=nil
        excludes=searchTermExcludes if excludes.nil?
        raise "getSearchTerms():  Only takes strings" unless string.class==String
        raise "getSearchTerms():  second argument must be nil or an array of strings to exclude from the search terms" unless excludes.nil? or excludes.class==Array
        return [] if string.strip.empty?

        i=0
        searchTerms=[]
        filename=string.split('/')
        file_extention=string.match(/\..{3,4}$/)[0]
        filename.each_index {|filename_index|

          #This implements the sliding window
          window=filename[filename_index].gsub(/(\.|_)/, ' ')
          until window.strip.empty?

            queue=window
            ignore=FALSE
            loop do
              searchTerms[i]||=''
              ignore=FALSE
              break if queue.empty? or queue.match(/[\w']*\b/i).nil?
              
              searchTerms[i]=match=queue.match(/[\w']*\b/i)
              match=match[0]
              if getEpisodeID(searchTerms[i][0]).nil? and !excludes.include?(match) and !excludes.include?(match.downcase)
                searchTerms[i]=searchTerms[i][0]
                searchTerms[i]= "#{searchTerms[i-1]} " << searchTerms[i] unless i==0
              else
                searchTerms[i]=''
              end
              queue=queue.slice( queue.index(match)+match.length, queue.length ).strip
              i+=1 #unless searchTerms[i].strip.empty?
            end
            i+=1 #unless searchTerms[i].strip.empty?
            break if window.match(/^[\w']*\b/i).nil?
            window=window.gsub(/^[\w']*\b/i, '').strip
          end
        }

        searchTerms=searchTerms.delete_if {|search_term| TRUE if (search_term.nil? or name_match?( search_term,file_extention,:no ) or search_term.strip.length <= 3)}.each_index {|line_number| searchTerms[line_number]=searchTerms[line_number].strip}

        unless excludes.nil?
          searchTerms=searchTerms.delete_if {|search_term| TRUE if excludes.include?(search_term)}
        end
        searchTerms
      end
    end
  end
end
