load 'MMCommon.rb'
require 'digest/sha1'

module MediaManager
	module MM_IMDB
		extend MMCommon
		#Take a name, and search for it in IMDB
		#Returns array of movies, or FALSE
		#This function is called directly by a helper function,       db_include?( source, dbname)
		#which takes the name, and continues searching until a
		#result is found, or the source is exhausted.

		def self.searchIMDB name, aka=nil
			#THIS WOULD BE SO MUCH FUCKING EASIER IF THE IMDB SEARCH PROGRAM 
			#WAS AT THE VERY LEAST, GIVING CONSISTENT OUTPUT!!!!!!!!!!!!!!1112
	
			#Don't process small words, or blacklisted words
			return [] if inBlacklist? name || name.length < 4

			#check the proxy
			#FIXME This function can be called with an optional argument, aka. If
			#this argument is called, the output of 'title' may be different than when
			#previously invoked with the same name, but the
			#proxy does not recognize this and may return old/invalid data.
			name_hash = Digest::SHA1.hexdigest(name.downcase)
			puts "retrieved from cache." if $IMDB_CACHE.include?(name_hash)
			return $IMDB_CACHE[name_hash] if $IMDB_CACHE.include?(name_hash)

			
			command=$MMCONF_MOVIEDB_LOC+"title -t '#{name.downcase}' -s"
			command << ' -aka' if aka

			#FIXME Cannot yet handle single quotes, 'sh' gets confused and throws syntax errori
			#double slashes ('\\') to escape quotes?
			raise "Cannot handle quotes in filenames yet." if name.index("'") || name.index('"')

			result=`#{command}`
			ret = $?    #return codes
			#35584  =  Segmentation Fault, output produced.  Term too ambiguous.
			#   11  =  Segmentation Fault, output produced.  Term too ambiguous.
			#    137,9  =  Killed, DO NOT RUN AGAIN!! No output.  Term too ambiguous.
			#    0  =  Output produced, cache results.  Success.
				
			if ret==9 or ret==137
				add2Blacklist name
				puts "Blacklisted #{name}, won't search for that term again.  Sorry!"
				return ""
			elsif ret==11 || result.empty? || ret==35072
				#We could return 'result' here, which should be a very large
				#array of information, but it is clear that this is an ambiguous
				#term so there is a greater chance of accuracy by using other terms
				return ""
			elsif ret!=0
				raise "Error:  WTF, unexpected error value from moviedb? #{ret.inspect}"
			end	
			return $IMDB_CACHE[name_hash] = mdb2info(result)
		end

		#Check the blacklist for an item
		def self.inBlacklist? bad_item
			#no need to check file, kept in sync by add2Blacklist
			$IMDB_BLACKLIST.include?(bad_item.downcase)
		end

		#Add an item to the blacklist
		def self.add2Blacklist bad_item
			#Add an item to the blacklist, and write to file.
			raise "Cannot add item to blacklist.txt #{bad_item.downcase}" unless `echo #{bad_item.downcase} >> #{$MMCONF_MOVIEDB_BLACKLIST}`
			$IMDB_BLACKLIST << bad_item.downcase
		end

		#This function takes the result of the IMDB moviedb 'title' operation
		#and returns the titles that match in an array
		#Or FALSE
		def self.mdb2info output_blob
			return FALSE if output_blob.empty?
			output_blob = output_blob.split("\n").reject {|line| line==""}
			result=[]

			#Need to know where all the 'page breaks' are for parsing
			pageBreaks=[]   #Populate pageBreaks with a list of all the line numbers which contain page breaks
			output_blob.each_index {|index|
				pageBreaks << index if output_blob[index].match( /^[-]*$/ )
			}	

			if pageBreaks.length == 1  #One result
				result[0]={ 'Titles' => output_blob[2].strip} #This array can be used as a reference for a list of
				result[1]={ 'Title' => output_blob[2].strip}        #all available titles.  It just makes processing
				#get url from output
				urlLine=0
				pp output_blob
				output_blob.each_index {|index|
					urlLine=index
					break if output_blob[index].match( /URL:/ )
				}
				result[1].merge!({'Url' => "#{output_blob[urlLine+1].strip}"})												#the return value more streamline
				output_blob.each_index {|index|
					result[1].merge!({'URL' => output_blob[index+1].strip}) if output_blob[index].match( /URL:/ )
					break if result[1]['URL']
				}
				return result
			end

			#pageBreaks should never be less than 2 {unless 1 item returned}
			raise "Unparsable output from 'title'; Insufficient delimiters for parsing <--->." if pageBreaks.length < 2
			num_items = pageBreaks[1] - 2
			
			result[0]={ 'Titles'=>[] }
			num_items.times do
				#Don't process TV show episodes that are returned in results
				#TV show episodes can be identified as having '{' and '}' in the
				#name, enclosing the episode title.
				result[0]['Titles'] << output_blob[num_items+1] unless output_blob[num_items+1].match( /[{].*[}]/ )
				num_items=num_items-1
			end

			return result
		end


	end
end
