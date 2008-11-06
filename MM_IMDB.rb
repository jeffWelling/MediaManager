require 'MMCommon'
require 'digest/sha1'

module MediaManager
	module MM_IMDB
		extend MMCommon
		def self.searchIMDB name, aka=nil
			#THIS WOULD BE SO MUCH FUCKING EASIER IF THE IMDB SEARCH PROGRAM 
			#WAS AT THE VERY LEAST, GIVING CONSISTENT OUTPUT!!!!!!!!!!!!!!1112
	
			#Don't process small words, or blacklisted words
			return "" if inBlacklist? name || name.length < 4

			#check the proxy
			nameHash = Digest::SHA1.hexdigest(name.downcase)
			return $IMDB_CACHE[nameHash] if $IMDB_CACHE.include?(nameHash)

			
			command=$MMCONF_MOVIEDB_LOC+"title -t '#{name.downcase}' -s"
			command << ' -aka' if aka

			result=`#{command}`
			ret = $?    #return codes
			#35584  =  Segmentation Fault, output produced.  Term too ambiguous.
			#   11  =  Segmentation Fault, output produced.  Term too ambiguous.
			#    9  =  Killed, DO NOT RUN AGAIN!! No output.  Term too ambiguous.
			#    0  =  Output produced, cache results.  Success.
				
			if ret==9
				add2Blacklist name
				puts "Blacklisted #{name}, won't search for that term again.  Sorry!"
				return ""
			elsif ret==11 || result.empty? || ret==35584
				#We could return 'result' here, which should be a very large
				#array of information, but it is clear that this is an ambiguous
				#term so there is a greater chance of accuracy by using other terms
				return ""
			elsif ret!=0
				raise "Error:  WTF, unexpected error value from moviedb? #{ret.inspect}"
			end

			#Process result
			return mdb2info(result)
			
		end

		#Check the blacklist for an item
		def self.inBlacklist? badItem
			#no need to check file, kept in sync by add2Blacklist
			$IMDB_BLACKLIST.include?(badItem.downcase)
		end

		#Add an item to the blacklist
		def self.add2Blacklist badItem
			#Add an item to the blacklist, and write to file.
			raise "Cannot add item to blacklist.txt #{badItem.downcase}" unless `echo #{badItem.downcase} >> #{$MMCONF_MOVIEDB_BLACKLIST}`
			$IMDB_BLACKLIST << badItem.downcase
		end

		#This function takes the result of the IMDB moviedb 'title' operation
		#and returns the titles that match in an array
		#Or FALSE
		def self.mdb2info outputBlob
			return FALSE if outputBlob.empty?
			outputBlob = outputBlob.split("\n").reject {|line| line==""}
			result=[]

			#Need to know where all the 'page breaks' are for parsing
			pageBreaks=[]
			outputBlob.each_index {|index|
				pageBreaks << index if outputBlob[index].match( /^[-]*$/ )
			}	

			if pageBreaks.length == 1  #One result
				result[0]={ 'Titles' => [outputBlob[2].strip]} #This array can be used as a reference for a list of
				result[1]={ 'Title' => outputBlob[2].strip}        #all available titles.  It just makes processing
				result[1].merge! { 'Url' =>  }													#the return value more streamline
				outputBlob.each_index {|index|
					result[1].merge! { 'URL' => outputBlob[index+1].strip } if outputBlob[index].match( /URL:/ )
					break if result[1]['URL']
				}
				return result
			end

			#pageBreaks should never be less than 2 {unless 1 item returned}
			raise "Unparsable output from 'title'; Insufficient delimiters for parsing <--->." if pageBreaks.length < 2
			numItemsReturned = pageBreaks[1] - 2
			
			result[0]={ 'Titles'=>[] }
			numItemsReturned.times do
				#Don't process TV show episodes that are returned in results
				#TV show episodes can be identified as having '{' and '}' in the
				#name, enclosing the episode title.
				result[0]['Titles'] << outputBlob[numItemsReturned+1] unless outputBlob[numItemsReturned+1].match( /[{].*[}]/ )
				numItemsReturned=numItemsReturned-1
			end

			return result
		end 

	end
end
