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
  #The Match module contains methods for advanced pattern matching
  #intended for use matching filenames to movie information to
  #id files.
  module Match
    @change_to_whitespace=/[\._-]/
    class << self
      #basic_match?(name, epName) searches for epName in name and returns true if found
      #Return true if they match, return false if they do not
      #If they do not match as is, try stripping various special characters
      #such as "'", ",", and ".". 
      def basic_match?(str1, str2, verbose=:no)
        str1=str1.downcase.strip
        str2=str2.downcase.strip
        if str2.nil? or str2.length==0
          MMCommon.pprint "basic_match?(): arg2 is empty??" unless verbose==:no
          return FALSE
        elsif str1.nil? or str1.length==0
          MMCommon.pprint "basic_match?(): arg1 is empty??" unless verbose==:no
          return FALSE
        end

        #Extra verbose option
        MMCommon.pprint "basic_match?():  (Extra Verbose)   str1: '#{str1}'\tstr2: '#{str2}'\n" if verbose.to_s.downcase.to_sym==:extra

        if str1==str2
          MMCommon.pprint "basic_match?():  Matched one-to-one" unless verbose==:no
          return TRUE
        end
        
        if str1.match(Regexp.new(Regexp.escape(str2), TRUE))   #Basic match
          MMCommon.pprint "basic_match?():  Regexp matched str2 to str1" unless verbose==:no
          return TRUE
        end
        if str2.match(Regexp.new(Regexp.escape(str1), TRUE))   #Basic match
          MMCommon.pprint "basic_match?():  Regexp matched str1 to str2" unless verbose==:no
          return TRUE
        end

        if str1.include?("'")    #If the str1 includes as "'" then strip it out, it only makes trouble
          if str1.gsub("'", '').match(Regexp.new( Regexp.escape(str2), TRUE))
            MMCommon.pprint "basic_match?():  Regexp matched str2 to str1 sans \"'\"." unless verbose==:no
            return TRUE
          end
        end
        if str2.include?("'")
          if str1.match(Regexp.new(Regexp.escape(str2.gsub("'", '')), TRUE))
            MMCommon.pprint "basic_match?():  Regexp matched str1 to str2 sans \"'\"." unless verbose==:no
            return TRUE
          end
        end

        if str2.include?(',')
          if str1.match(Regexp.new(Regexp.escape(str2.gsub(",",'')), TRUE))
            MMCommon.pprint "basic_match?():  Regexp matched str2 to str1 sans \",\"." unless verbose==:no
            return TRUE
          end
        end
        if str1.include?(',')
          if str1.gsub(',', '').match(Regexp.new(Regexp.escape(str2), TRUE))
            MMCommon.pprint "basic_match?():  Regexp matched str1 to str2 sans \",\"." unless verbose==:no
            return TRUE
          end
        end

        if str2.include?('.')
          if str1.match(Regexp.new(Regexp.escape(str2.gsub('.', '')), TRUE))
            MMCommon.pprint "basic_match?():  Regexp matched str2 to str1 sans \".\"" unless verbose==:no
            return TRUE
          end
        end
        if str1.include?('.')
          if str2.match(Regexp.new(Regexp.escape(str1.gsub('.', '')), TRUE))
            MMCommon.pprint "basic_match?():  Regexp matched str1 to str2 sans \".\"." unless verbose==:no
            return TRUE
          end
        end
        
        #no match
        return FALSE
      end


      #Tries to match the two strings using various methods.  Intended to be used to match a title or
      #episode name to the filename (or one of it's parent dirs) on your disc.
      #It will return FALSE if no match was found, or it will return one of the following return values
      #which tells how it was matched.
      #:oneToOne :basic_match? :digits_bothSides :digits_partNumber :romanNumeral_str1 :romanNumeral_str2 :bothParts_str2 :str2_before_aka :str2_after_aka
      #:wordBoundaries_str2 :numword_str1_ns :numword_str1_s
      def fuzzy_match(str1, str2, verbose=:no)
        #name=str1 and epName=str2

        ##Begin attempting to match	
        if str1==str2
          MMCommon.pprint "fuzzyMatch(): Matched one to one" unless verbose==:no
          return :oneToOne
        end

        if (str2.length > 1 and basic_match?(str1, str2))
          MMCommon.pprint "fuzzyMatch(): Matched basic_match?()" unless verbose==:no
          return :basic_match?
        end
      
        #Try to match 2 part (or more) episodes.  Sometimes these have the part number in the middle of the name with 
        #another title on the other side, if thats the case try and match the titles.  Otherwise, try and match
        #the part number.	
        if str2.index(/\([\d]+\)/)
          unless str1.match(/\(.*[\d]+.*\)/)    #No need to process this if the filename has no ([\d]+.*) in it
            str2_sans_stuff=str2.gsub(/[:;]/, '')
            part2= str2_sans_stuff.slice( str2_sans_stuff.index(/\([\d]+\)/)+str2_sans_stuff.match(/\([\d]+\)/)[0].length,str2_sans_stuff.length ).downcase.strip
            #regex1 matches the first part of the string up to the (\d+) and regex2 matches the second part trailing it, if there is anything
            regex1= Regexp.new( Regexp.escape(str2_sans_stuff.slice( 0,str2_sans_stuff.index(/\([\d]+\)/) ).downcase))
            regex2= Regexp.new( Regexp.escape(part2) )
            unless part2.empty?   #If there are strings on both side of the digit, use that.  Otherwise, attempt to use the [\d] provided
              if str1.downcase.match(regex1) and str1.downcase.match(regex2)
                MMCommon.pprint "fuzzyMatch(): Matched based on both sides of a digit thingy" 
                return :digits_bothSides
              end
            end 
          
            #Should only get here if the string following ([\d]) is empty or the match above wasn't successful
            #Use the first digit in the ( ) as the part number if it matches.
            regex2= Regexp.new( Regexp.escape(str2.match(/\([\d]+\)/)[0].chop.reverse.chop.reverse) )
            if part=str1.match(/\(.*[\d]+.*\)/)    #If the filename has ([\d]) in it
              part=part[0].match(/[\d]+/)[0]
              if part.match(regex2)  #Match
                MMCommon.pprint "fuzzyMatch(): Matched based on part number  (alternative digit thingy match)" unless verbose==:no
                return :digits_partNumber
              end
            end
          end #of unless str1.match(...)
        end
      
        #FIXME See the NOTEs a few lines down	
        #Attempt to deal with Roman Numerals
        #The following regex was adapted from Example 7.8 of http://thehazeltree.org/diveintopython/7.html
        numeralMatch=/\s[M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})]+\s/
        romName= (((str1.reverse) + ' ').reverse) + ' ' # This allows us to use whitespace as delimiters for either side of a RN (Roman Numeral)
        romEpName= ((str2 + ' ').reverse + ' ').reverse
        if romEpName.match(numeralMatch) or romName.match(numeralMatch)
          #NOTE We do not anticipate more than one Roman Numeral in the str
          #NOTE We do not anticipate a roman numeral in both str1 and str1
          if romName.match( numeralMatch )
            romName=romName.gsub(Regexp.new(Regexp.escape(romName.match(numeralMatch)[0])), 
              "#{toArabic( romName.match(numeralMatch)[0].strip ).to_s} " ) unless toArabic(romName.match(numeralMatch)[0].strip)==0
            if romEpName.match(Regexp.new(Regexp.escape(romName), TRUE))
              MMCommon.pprint "fuzzyMatch():  Matched based on roman numeral in str1 and converted" unless verbose==:no
              return :romanNumeral_str1
            end
          elsif romEpName.match(numeralMatch)
            romEpName=romEpName.gsub(Regexp.new(Regexp.escape(romEpName.match(numeralMatch)[0])), 
              " #{toArabic(romEpName.match(numeralMatch)[0].strip).to_s} " ) unless toArabic(romEpName.match(numeralMatch)[0].strip)==0
            if romName.match(Regexp.new(Regexp.escape(romEpName), TRUE))
              MMCommon.pprint "fuzzyMatch(): Matched based on roman numeral found in str2 and converted" unless verbose==:no
              return :romanNumerals_str2
            end
          end
        end

        #FIXME Should do the same for str1 as well
        if str2.index(':') #May be split into parts, try and match each side of the :
          str2=str2.gsub(/\([\d]+\)/, '')   #Strip out any (\d+) parts for easier matching
          regex1= Regexp.new( Regexp.escape(str2.slice(0,str2.index(':')).downcase) )
          regex2= Regexp.new( Regexp.escape(str2.slice(str2.index(':')+1,str2.length).downcase) )

          if str1.downcase.match(regex1) and str1.downcase.match(regex2)
            MMCommon.pprint "fuzzyMatch():  Matched both sides of a ':'" unless verbose==:no
            return :bothParts_str2
          end
        end
        
        #FIXME Should do this for str1 as well
        #If str2 has 'a.k.a.' in it, check either side.  Just like any other delimiter
        if str2.index('a.k.a.')
          #For the purposes of matching the 'a.k.a.' it appears necessary to strip out parenthesis
          #from str2, Regexp throws an error if it encounters unmatched parenthesis
          str_sans_parenthesis=str2.gsub('(', '').gsub(')', '')
          str2_upto_aka= str_sans_parenthesis.slice( 0,str_sans_parenthesis.index('a.k.a.')-1 )
          str2_after_aka= str_sans_parenthesis.slice( str_sans_parenthesis.index('a.k.a.')+ 'a.k.a.'.length, str_sans_parenthesis.length)
          if str1.match(Regexp.new(str2_upto_aka, TRUE))
            MMCommon.pprint "fuzzyMatch(): Matched the first part of the str2, up to 'a.k.a.'." unless verbose==:no
            return :str2_before_aka
          elsif str1.match(Regexp.new(str2_after_aka, TRUE))
            MMCommon.pprint "fuzzyMatch(): Matched the last part of the str2, after the 'a.k.a.'." unless verbose==:no
            return :str2_after_aka
          end
        end

        #Here I am trying to look for the str2 in str1 the same way that I would as a human
        #I think the way to do this is to break the string into words, and look for a single 
        #character from the beginning and end of each respective word in str2 and try
        #match those beginnings and ends of words to beginnings and ends of words in str1.
        #This can be further refined by looking for characters that stand out, like 't' or 'g'
        #as opposed to ones that don't like 'a' or 'c'.  Looking for characters that stand out 
        #in str1 that aren't in str2 can accomplish this.
        #Note: Admittedly, this cannot catch spelling mistakes at the beginning or end of a word.
        #FIXME This needs to be done for both str1 and str2, and could be cleaned up more
        if str1.gsub('-', ' ').gsub('_', ' ').gsub('.', ' ').split(' ').length > 2
          str2_stripped=str2.strip
          distance=3
          str2_compare_results=[]

          str2_words=[]
          str1_words=[]
          str2_stripped.split(' ').each {|word|
            str2_words << word unless word.length <= 2
          }
          
          str1.gsub('-', ' ').gsub('_', ' ').gsub('.', ' ').split(' ').each {|word|
            str1_words << word unless word.length <= 2
          }
          str2_words.each_index {|words2_i|
            str1_words.each_index { |words1_i|
              if str2_words[words2_i].slice(0,1)==str1_words[words1_i].slice(0,1) and
                  str2_words[words2_i].slice(str2_words[words2_i].length-1, 1)==str1_words[words1_i].slice(str1_words[words1_i].length-1, 1)

                str2_compare_results[words2_i]=TRUE
              else
                str2_compare_results[words2_i]=FALSE
              end
            }
          }
          str2_compare_results= str2_compare_results.delete_if {|word_matched| word_matched == FALSE}
          if str2_compare_results.length == str1_words.length
            MMCommon.pprint "fuzzyMatch(): Matched based solely on looking at word boundaries." unless verbose==:no
            return :wordBoundaries_str2
          end
        end

        #Convert integer to word and try to match
        #FIXME This should be done for both str1 and str2
        #FIXME Linguistics::EN.numwords returns in the format 'twenty-four'.  Should try replacing '-' with ' '
        #		various other matches as well for better chance at matching
        #FIXME This should probably be done in a sliding window fashion, like how getSearchTerms() works, so that
        #		it can properly handle multiple integers in the strings, converting them into all into words in sequence
        #		for a better match
        if str1.match(/\d+/)
          longName=str1.gsub(str1.match(/\d+/)[0], Linguistics::EN.numwords(str1.match(/\d+/)[0]))
          if longName.match(Regexp.new(Regexp.escape(str2), TRUE))
            unless str2.empty?    #To prevent matching an empty episode name
              MMCommon.pprint "fuzzyMatch(): Matched after converting a number to a word in str1, no space." unless verbose==:no
              return :numword_str1_ns
            end
          end

          longName=str1.gsub(str1.match(/\d+/)[0], " #{Linguistics::EN.numwords(str1.match(/\d+/)[0])} ")
          if longName.match(Regexp.new(Regexp.escape(str2), TRUE))
            unless str2.empty?
              MMCommon.pprint "fuzzyMatch():  Matched after converting the number to a word, with space."
              return :numword_str1_s
            end
          end
        end

=begin
        #FIXME Need to also match EpisodeID tags in the form of 1x08, and hopefully, 108
        #TODO This section should match even if the str1 does not match the filename, but it should issue a warning that the only thing that indicates this name is the EpisodeID tag and the series title
        #TODO Remember to use the variable we have stored the EpisodeID tag in, because it is stripped from str1
        #If we already have the EpisodeID tag then we can look for that instead of trying to match the str1.
        #Note, cannot account for filename giving inaccurate EpisodeID tag, simply will not match
        #This match still in development, not useful yet due to the high chance of being given a false positive EpisodeID tag
        # if... the tvdb seriesID of the top ranking series in occurance[] matches the current seriesID in seriesHash OR basic_match?
        if seasonNum and epNum and (occurance[0][0][0]==seriesHash[0][0] or basic_match?( str1,seriesHash[1]['Title'][0], :no))
          episodes_seasonNum=episode['EpisodeID'].match(/s[\d]+/i)[0].reverse.chop.reverse.to_i
          episodes_epNum=episode['EpisodeID'].match(/[\d]+$/)[0]
          #printf "seasonNum: #{seasonNum}  episodes_seasonNum: #{episodes_seasonNum}  epNum: #{epNum}  episodes_epNum: #{episodes_epNum}      \n"
          if seasonNum.to_i==episodes_seasonNum.to_i and epNum.to_i==episodes_epNum.to_i
            MMCommon.pprint "db_include?(): Match based on title found in filename, and season and episode number match from filename."
            matches << episode.merge('Matched'=>:epid)
            next
          end
        end
=end
        
        #Try joining words together to see if that helps matching
        return FALSE
      end
      #compares path to media, returns true if positive match
      def compare path, media
        results={}
        searchResults=[]
        #media is a tv show or movie etc, populated with various fields to test against path
        whitespaced_path=path.gsub(@change_to_whitespace, ' ').squeeze(' ').strip
        
        #Remove source path from beginning of path?

        path_segments=Metadata.pathToArray path

        searchTerms=Metadata.getSearchTerms(path, Metadata.searchTermExcludes)

        
        
        return true
      end
    end
  end
end
