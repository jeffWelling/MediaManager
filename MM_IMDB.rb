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
		#FIXME TODO the moviedb's title program does not properly handle searches for names that match 1 to 1
		def self.searchIMDB name, aka=nil
			#THIS WOULD BE SO MUCH FUCKING EASIER IF THE IMDB SEARCH PROGRAM 
			#WAS AT THE VERY LEAST, GIVING CONSISTENT OUTPUT!!!!!!!!!!!!!!1112
	
			#Don't process small words, or blacklisted words
			if (inBlacklist?(name) || name.length < 4)
				puts "searchIMDB():  Searchterm '#{name}' is blacklisted, skipping."
				return []
			end
			puts "searchIMDB():  Searching for '#{name}'"

			#check the proxy
			#FIXME This function can be called with an optional argument, aka. If
			#this argument is called, the output of 'title' may be different than when
			#previously invoked with the same name, but the
			#proxy does not recognize this and may return old/invalid data.
			nameHash = Digest::SHA1.hexdigest(name.downcase)
			puts "searchIMDB():  '#{$IMDB_CACHE[nameHash].length}' results for '#{name}' from cache." if $IMDB_CACHE.include?(nameHash)
			return $IMDB_CACHE[nameHash] if $IMDB_CACHE.include?(nameHash)

			
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
			if ret==9 or ret==137 or ret.to_i==35072
				add2Blacklist name
				puts "Blacklisted '#{name}', won't search for that term again.  Sorry!"
				return ""
			elsif ret==11 || result.empty?
				#We could return 'result' here, which should be a very large
				#array of information, but it is clear that this is an ambiguous
				#term so there is a greater chance of accuracy by using other terms
				puts "searchIMDB():  '0' results for '#{name}'"
				return ""
			elsif ret!=0
				raise "Error:  WTF, unexpected error value from moviedb? #{ret.inspect}"
			end	
			formatted_result=mdb2info(result)
			$IMDB_CACHE[nameHash] = formatted_result
			puts "searchIMDB():  '#{$IMDB_CACHE[nameHash].length}' titles found for '#{name}'"
			return formatted_result
		end

		#Check the blacklist for an item
		def self.inBlacklist? badItem
			#no need to check file, kept in sync by add2Blacklist
			$IMDB_BLACKLIST.include?(badItem.downcase)
		end

		#Add an item to the blacklist
		def self.add2Blacklist badItem
			#Add an item to the blacklist, and write to file.
			raise "Cannot add item to blacklist.txt #{badItem.downcase}" unless `echo '#{badItem.downcase}' >> #{$MMCONF_MOVIEDB_BLACKLIST}`
			$IMDB_BLACKLIST << badItem.downcase
		end

		#This function takes the result of the IMDB moviedb 'title' operation
		#and returns the titles and related information in a pretty formatted array
		#Or FALSE
		def self.mdb2info outputBlob
			return FALSE if outputBlob.empty?
			outputBlob = outputBlob.split("\n").reject {|line| line==""}
			result={}

			#Need to know where all the 'page breaks' are for parsing
			pageBreaks=[]   #Populate pageBreaks with a list of all the line numbers which contain page breaks
			outputBlob.each_index {|index|
				pageBreaks << index if outputBlob[index].match( /^[-]*$/ )
			}	

			if pageBreaks.length == 1  #Output was cutoff  FIXME!
				if outputBlob[1]=='Titles Matched:'
					#list of movies
					outputBlob.each_index {|index|
						next if index <= 1  #First two lines are garbage in this case, "-----.." and "Titles Matched:"
						result.merge!( { "#{outputBlob[index].strip}" => [] } )
					}	
					return result
				else
					#single instance returned with no list
					title=''
					key=''
					value=''
					movieblob_cache=outputBlob
					movieblob_cache.each_index {|current_line_index|
						next if (current_line_index > movieblob_cache.length-2) or movieblob_cache[current_line_index].match(/^-*$/)
						if movieblob_cache[current_line_index].gsub(/:$/, '')=='Title'
							title=movieblob_cache[current_line_index+1].strip
							result.merge!({ title => [] })
						end
	
						if movieblob_cache[current_line_index].match(/^\s/) or movieblob_cache[current_line_index].match(/^[a-zA-Z\s]*:/).nil?
							#not a new key/value pair, add this line to the value
							value << "#{movieblob_cache[current_line_index].strip}, "
						else
							#new pair
							unless value=='' or key==''
								result[title] << {key => value}
							end
							value=''
							key=movieblob_cache[current_line_index].match(/^.*?:/)[0].chop
						end

					}
					return result
				end
				
			end

			#pageBreaks should never be less than 2 {unless 1 item returned}
			raise "Unparsable output from 'title'; Insufficient delimiters for parsing <--->." if pageBreaks.length < 2
			
			second_area=false
			movieblob_cache=[]
			title=''   #used to keep track of the movie title while processing the movieblob_cache's
			outputBlob.each_index {|index|
				next if index > (outputBlob.length-2)  #Don't process the bottom two lines (copyright information)
				next if index <= 1 #Don't process the first two lines, '---...' and 'Titles Matched:'
				second_area=true if outputBlob[index].match(/^-*$/)
				result.merge!({ "#{outputBlob[index].strip}" => [] }) unless second_area.class==TrueClass
				next unless second_area.class==TrueClass

				if outputBlob[index].match(/^-*$/)
					next if movieblob_cache.empty?
					
					key=''
					value=''
					movieblob_cache.each_index {|current_line_index|
						next if (current_line_index > movieblob_cache.length-2) or movieblob_cache[current_line_index].match(/^-*$/)
						if movieblob_cache[current_line_index].gsub(/:$/, '')=='Title'
							title=movieblob_cache[current_line_index+1].strip
							pp movieblob_cache if movieblob_cache[current_line_index].match(/99:/)
						end
	
						if movieblob_cache[current_line_index].match(/^\s/) or movieblob_cache[current_line_index].match(/^[a-zA-Z\s]*:/).nil?
							#not a new key/value pair, add this line to the value
							value << "#{movieblob_cache[current_line_index].strip}, "
						else
							#new pair
							unless value=='' or key==''
								result[title] << {key => value}
							end
							value=''
							key=movieblob_cache[current_line_index].match(/^.*?:/)[0].chop
						end

					}
					movieblob_cache=[]
					title=''
				end

				#fill up the movieblob untill we reach the '---' mark, at which point we process the blob, zero it out, and start over
				movieblob_cache << outputBlob[index]
			}

			return result
		end


	end
end
