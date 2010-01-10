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

      def sliding_window str
        excludes=searchTermExcludes if excludes.nil?
        window=str.gsub(/(\.|_)/, ' ')
        i=0
        searchTerms=[]
        until window.strip.empty?
          queue=window
          loop do
            searchTerms[i]||=''
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
        searchTerms
      end

      def getSearchTerms string, excludes=nil
        excludes=searchTermExcludes if excludes.nil?
        raise "getSearchTerms():  Only takes strings" unless string.class==String
        raise "getSearchTerms():  second argument must be nil or an array of strings to exclude from the search terms" unless excludes.nil? or excludes.class==Array
        return [] if string.strip.empty?

        i=0
        searchTerms=[]
        file_extention=string.match(/\..{3,4}$/)[0]
        filename=string.split('/').last 3
        searchTerms=filename.collect {|str| sliding_window str }.inject {|a,b| a + b }

        searchTerms=searchTerms.delete_if {|search_term|
          search_term.nil? ||
          Match.basic_match?( search_term,file_extention,:no ) ||
          search_term.strip.length <= 3
        }.collect(&:strip)

        unless excludes.nil?
          searchTerms=searchTerms.delete_if {|search_term| TRUE if excludes.include?(search_term)}
        end
        searchTerms
      end
      #getEpisodeID will search for all of the episodeIDs in random_string, and will return them.
      #If theres more than one, it will return them in an array, with the first episodeID as the first item.
      #If the reformat argument is set to anything that is not :no, it will reformat the episodeID into 
      #the standard 's2e22' format.
      def getEpisodeID random_string, reformat=:no
        #this regex is meant to match 's2e23' and '1x23' formats.
        #NOTE Make sure to check that this does give you a resolution (make sure it is a sane series number and episode number)
        episodeID_regex=/(s[\d]+e[\d]+|[\d]+x[\d]+)/i
        return nil if ( episodeID=random_string.match(episodeID_regex) ).nil?
        
        #check that its a sane series and episode number
        #series number = 1-99
        #episode number= 1-700              700 should be enough for one season right?
        seriesNumber=episodeID[0].match(/^(s)?[\d]+/i)[0]
        seriesNumber=seriesNumber.reverse.chop.reverse if seriesNumber.include? 's' or seriesNumber.include? 'S'
        seriesNumber=seriesNumber.to_i
        episodeNumber=episodeID[0].match(/[\d]+$/)[0].to_i
        if seriesNumber < 1 or seriesNumber > 99 or episodeNumber < 1 or episodeNumber > 700
          #episodeID is bad
          
          #look for other episodeIDs, return nil
          return getEpisodeID(random_string.gsub(episodeID[0],''),reformat) if getEpisodeID(random_string.gsub(episodeID[0],''))
          return nil
        end

        if reformat!=:no
          #reformat to 's3e12'
          return (["s#{seriesNumber}e#{episodeNumber}"]+[getEpisodeID(random_string.gsub(episodeID[0],''),reformat)]).flatten if getEpisodeID(random_string.gsub(episodeID[0],''),reformat)
          return "s#{seriesNumber}e#{episodeNumber}"
        end
        
        #look for more episodeIDs, return the one we already have
        return ([episodeID[0]]+[getEpisodeID(random_string.gsub(episodeID[0],''),reformat)]).flatten if getEpisodeID(random_string.gsub(episodeID[0],''),reformat)
        return episodeID[0]
      end
    end
  end
end
