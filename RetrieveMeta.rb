load 'MMCommon.rb'
load 'Hasher.rb'
load 'romanNumerals.rb'

module MediaManager
	module RetrieveMeta
		extend MMCommon
		#Tries to match the two strings using various methods.  Intended to be used to match a title or
		#episode name to the filename (or one of it's parent dirs) on your disc.
		#It will return FALSE if no match was found, or it will return one of the following return values
		#which tells how it was matched.
		#:oneToOne :name_match? :digits_bothSides :digits_partNumber :romanNumeral_str1 :romanNumeral_str2 :bothParts_str2 :str2_before_aka :str2_after_aka
		#:wordBoundaries_str2 :numword_str1_ns :numword_str1_s
		def fuzzyMatch(str1, str2, verbose=:no)
			#name=str1 and epName=str2

			##Begin attempting to match	
			if str1==str2
				puts "fuzzyMatch(): Matched one to one" unless verbose==:no
				return :oneToOne
			end

			if (str2.length > 1 and MediaManager.name_match?(str1, str2))
				puts "fuzzyMatch(): Matched name_match?()" unless verbose==:no
				return :name_match?
			end
		
			#Try to match 2 part (or more) episodes.  Sometimes these have the part number in the middle of the name with 
			#another title on the other side, if thats the case try and match the titles.  Otherwise, try and match
			#the part number.	
			if str2.index(/\([\d]+\)/)
				unless str1.match(/\(.*[\d]+.*\)/)    #No need to process this if the filename has no ([\d]+.*) in it
					str2_sans_stuff=str2.gsub(/[:;]/, '')
					part2= str2_sans_stuff.slice( str2_sans_stuff.index(/\([\d]+\)/)+str2_sans_stuff.match(/\([\d]+\)/)[0].length,str2_sans_stuff.length ).downcase.stripi
					#regex1 matches the first part of the string up to the (\d+) and regex2 matches the second part trailing it, if there is anything
					regex1= Regexp.new( Regexp.escape(str2_sans_stuff.slice( 0,str2_sans_stuff.index(/\([\d]+\)/) ).downcase))
					regex2= Regexp.new( Regexp.escape(part2) )
					unless part2.empty?   #If there are strings on both side of the digit, use that.  Otherwise, attempt to use the [\d] provided
						if str1.downcase.match(regex1) and str1.downcase.match(regex2)
							puts "fuzzyMatch(): Matched based on both sides of a digit thingy" 
							return :digits_bothSides
						end
					end 
				
					#Should only get here if the string following ([\d]) is empty or the match above wasn't successful
					#Use the first digit in the ( ) as the part number if it matches.
					regex2= Regexp.new( Regexp.escape(str2.match(/\([\d]+\)/)[0].chop.reverse.chop.reverse) )
					if part=str1.match(/\(.*[\d]+.*\)/)    #If the filename has ([\d]) in it
						part=part[0].match(/[\d]+/)[0]
						if part.match(regex2)  #Match
							puts "fuzzyMatch(): Matched based on part number  (alternative digit thingy match)" unless verbose==:no
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
						puts "fuzzyMatch():  Matched based on roman numeral in str1 and converted" unless verbose==:no
						return :romanNumeral_str1
					end
				elsif romEpName.match(numeralMatch)
					romEpName=romEpName.gsub(Regexp.new(Regexp.escape(romEpName.match(numeralMatch)[0])), 
						" #{toArabic(romEpName.match(numeralMatch)[0].strip).to_s} " ) unless toArabic(romEpName.match(numeralMatch)[0].strip)==0
					if romName.match(Regexp.new(Regexp.escape(romEpName), TRUE))
						puts "fuzzyMatch(): Matched based on roman numeral found in str2 and converted" unless verbose==:no
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
					puts "fuzzyMatch():  Matched both sides of a ':'" unless verbose==:no
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
					puts "fuzzyMatch(): Matched the first part of the str2, up to 'a.k.a.'." unless verbose==:no
					return :str2_before_aka
				elsif str1.match(Regexp.new(str2_after_aka, TRUE))
					puts "fuzzyMatch(): Matched the last part of the str2, after the 'a.k.a.'." unless verbose==:no
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
					puts "fuzzyMatch(): Matched based solely on looking at word boundaries." unless verbose==:no
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
						puts "fuzzyMatch(): Matched after converting a number to a word in str1, no space." unless verbose==:no
						return :numword_str1_ns
					end
				end

				longName=str1.gsub(str1.match(/\d+/)[0], " #{Linguistics::EN.numwords(str1.match(/\d+/)[0])} ")
				if longName.match(Regexp.new(Regexp.escape(str2), TRUE))
					unless str2.empty?
						puts "fuzzyMatch():  Matched after converting the number to a word, with space."
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
			# if... the tvdb seriesID of the top ranking series in occurance[] matches the current seriesID in seriesHash OR name_match?
			if seasonNum and epNum and (occurance[0][0][0]==seriesHash[0][0] or name_match?( str1,seriesHash[1]['Title'][0], :no))
				episodes_seasonNum=episode['EpisodeID'].match(/s[\d]+/i)[0].reverse.chop.reverse.to_i
				episodes_epNum=episode['EpisodeID'].match(/[\d]+$/)[0]
				#printf "seasonNum: #{seasonNum}  episodes_seasonNum: #{episodes_seasonNum}  epNum: #{epNum}  episodes_epNum: #{episodes_epNum}      \n"
				if seasonNum.to_i==episodes_seasonNum.to_i and epNum.to_i==episodes_epNum.to_i
					puts "db_include?(): Match based on title found in filename, and season and episode number match from filename."
					matches << episode.merge('Matched'=>:epid)
					next
				end
			end
=end
			
			#Try joining words together to see if that helps matching
			return FALSE
		end		

		def self.get_episode_id(random_string, reformat_to_standard=:no)
			#Note that the order here matters, search for the most likely format first
			tag=random_string.match(/s[\d]+e[\d]+/i)
			unless tag.nil?
				return [tag[0]]
			end

			tag=random_string.match(/[\d]+x[\d]+/i)
			unless tag.nil?
				bad=:no
				#verify that we aren't looking at a resolution
				bad=:yes if tag[0].match(/^\d+/)[0].to_i > 59    #There shouldn't be any season number higher than this
				bad=:yes if tag[0].match(/\d+$/)[0].to_i > 999		#There shouldn't be any episode number higher than this
				
				if bad==:yes
					#Recurse, stripping out each resolution (if theres more than one?) until we get something good, or nothing at all
					return get_episode_id(random_string.gsub(tag[0],' '))
				else
					reformat_to_standard==:no ? (return [tag[0]]) : (return ["s#{tag[0].match(/^\d+/)[0]}e#{tag[0].match(/\d+$/)[0]}"])
				end

				
				#End of trying to match an episodeID, and we got nothing.
			end
			return nil
		end
	
		#Returns info in the form of a hash conforming to movieInfo_Specification.rb
		#isRar is :yes if the filename passed is a folder containing a rared file
	  def self.filenameToInfo(filename, isRar=:no)
	    puts "\nWorking on #{filename}"
			movieData=$movieInfoSpec.clone
			movieData['Path']=filename
			need_to_add_filesha=FALSE
			sqlresult=sqlSearch( "SELECT * FROM mediaFiles WHERE PathSHA = '#{hash_filename movieData['Path']}'" )
			unless sqlresult.empty?
				movieData=sqlresult[0]
				need_to_add_filesha=TRUE if movieData['FileSHA'].empty?
				puts "Metainformation is available based on a hash of the filename."
				puts "Checking that file has not changed..."
			end			
			
			if movieData['FileSHA'].empty?
				movieData['FileSHA']=hash_file(filename) if $MM_MAINT_FILE_INTEGRITY==TRUE
			end
			
			#Check the consistency of the file
			filehash= ($MM_MAINT_FILE_INTEGRITY==TRUE) ? (hash_file(filename)) : ('')
			unless filehash.length == 0 or filehash==movieData['FileSHA']
				raise "filenameToInfo: File hash has changed!" \
					<< "\nIf you have not changed the file, it may have become corrupt."
			end

			#Don't need to update if they're the same...
			#Get data from MySQL if possible
			sqlresult2=''
			sqlresult2=sqlSearch( "SELECT * FROM mediaFiles WHERE FileSHA = '#{movieData['FileSHA']}'" ) unless $MM_MAINT_FILE_INTEGRITY!=TRUE
			unless sqlresult2.empty?
				unless sqlresult.empty?
					if sqlresult[0]['id'] != sqlresult2[0]['id']
						raise "filenameToInfo(): Lookup Conflict! filename based lookup and file based lookup product conflicting results."
					end
				end

				#Because this sqlresult is produced based on the file's hash, the filename may not match
				#FIXME When comparing paths, some filesystems are case senesetive and others are not.  
				if movieData['Path'] != sqlresult2[0]['Path'] and $MM_MAINT_FILE_INTEGRITY==TRUE
					puts "filenameToInfo():  Looking up the file's hash produces a different path!"
					if File.exist?(sqlresult2[0]['Path'])
						if File.exist?(movieData['Path'])
							#By not doing anything here, the movieData is overwritten with the 'old' path which
							#is still valid.  This MUST be detected after filenameToInfo() returns to properly
							#handle duplicates!
							puts "WARNING!!: this file is a duplicate!"					
						end
					else #The sqlresult2 path leads to a file that doesn't exist.
						puts "NOTICE: The file's hash brings up database results whos path points to a non-existant file."
						puts "NOTICE: Old path: #{sqlresult2[0]['Path']}"
						puts "NOTICE: Because the old file is not accessible, continuing using new path for file."
						sqlresult2[0]['PathSHA']= hash_filename(movieData['Path'])     #Just for posterities sake, don't want to show the old hash for the new path ><
						sqlresult2[0]['Path']= movieData['Path']
					end
				end
				movieData=sqlresult2[0]
			end
			if !movieData['id'].nil? and need_to_add_filesha==TRUE and $MM_MAINT_FILE_INTEGRITY==TRUE
				puts "filenameToInfo():  This file was just hashed for the first time, adding hash to file's db entry."
				raise "filenameToInfo(): Failed updating sql?" unless sqlAddUpdate("UPDATE mediaFiles SET FileSHA='#{movieData['FileSHA']}' WHERE PathSHA='#{movieData['PathSHA']}'")==1
			end
			pp movieData
			puts "File already in database, using info..." unless movieData['id'].nil?
			return movieData unless movieData['id'].nil?


			#Can't process escaped slashes yet, attempting to may cause inexplicable behaviour.
			if filename.index('//') || filename.index('\/')
	      raise "Not yet able to process files with '//' or escaped slashes such as '\/'.\n"    #what if OMGKERNELPANIC...  ?
				return FALSE
	    end 

			#seperated into two lines so that extractData() is run once not twice
			it= extractData(movieData, isRar)
			return it if it==:ignore
	    if it != FALSE then movieData = it end

			#Save the size of the file for reference
			movieData['Size']=File.size?(movieData['Path'])

			return movieData
	   #FIXME  Continue from here 
	  end 

		#This function does its  best to extract information from the filename
		def self.extractData(movieData, isRar=:no)
			puts "extractData():  Reaching up my /dev/null and pulling out some meta-data...."
			raise "OMG CANT HANDLE RARS YET!!FIXMEYOUIDIOT!!" if isRar!=:no
			#Return False unless is movie, then

		  #Store the results from each assesment attempt
		  #for reference and recalculation at end of function
		  answers=[]
	
			#split the path to make it searchable, but retain full path
			#file_path is array of the seperated names of each parent folder
			file_path=movieData['Path'].split('/')
			counter=0
	
			#0.
			#Does the path contain 'movie' in it?
			file_path.each do |filepath_segment|
				if filepath_segment.downcase.index("movie")
					answers[0]=TRUE
				else
					answers[0]=FALSE
				end
			end
	
			#1.
			#Does the path also contain 'tv' or 'television' in it?
			file_path.each do |filepath_segment|
				if filepath_segment.downcase.index("tv")
					answers[1]=TRUE
				elsif filepath_segment.downcase.index("television")
					answers[1]=TRUE
				else
					answers[1]=FALSE
				end
			end
	
			#2.
			#What size is it? (in bytes)    >= 650 = movie
			answers[2] = movieData['Size']
			if answers[2]==nil
				print "Warning: File doesn't exist, or has zero size? #{movieData['Path']}"
			end
	
			#3.
			#Is it in VIDEO_TS format?
			movieData['Path'].index("VIDEO_TS") != nil ? answers[3]=TRUE : answers[3]=FALSE

			#4.
			#Does it have a series tag (S01E02)?
			answers[4]=FALSE
			id=MediaManager::RetrieveMeta.get_episode_id(movieData['Path'], :reformat_to_standard)
			unless id.nil?
				id=id[0]
				puts "Found season tag #{id} (may have been reformatted), extracting Season and EpisodeID..."
				movieData['Season'] = id.match(/\d+/)[0].to_i
				movieData['EpisodeID'] = id.upcase
				answers[4]=TRUE
				#TODO Debug line, remove before publishing
				raise "Failed to set movieData fields with extracted data?" if movieData['Season'].nil? || movieData['EpisodeID'].nil?
			end

			#Is it in IMDB/TVDB?
			result=''
			result= db_include?( :tvdb, movieData)
			imdb_results= db_include?( :imdb, movieData)
			return :ignore if result==:ignore or imdb_results==:ignore
#			puts "extractData(): db_include?() returned this match..."
#			pp result
			answers[5]=TRUE unless result.empty?
			unless result.empty?
				movieData['tvdbSeriesID']= result[0]['tvdbSeriesID']
				movieData['Season']= result[0]['SeasonNumber']
				movieData['Title']= result[0]['Title']
				movieData['EpisodeID']= result[0]['EpisodeID'].upcase
				movieData['imdbID']= result[0]['IMDB_ID']
				movieData['EpisodeName']= result[0]['EpisodeName']
			end
			unless imdb_results.empty?
				imdb_results=imdb_results[0]
				movieData['Title']=imdb_results['Title']
				movieData['Year']=imdb_results['Year']
				movieData['EpisodeName']=imdb_results['EpisodeName']
				movieData['EpisodeID']=imdb_results['EpisodeID']
				movieData['Season']=imdb_results['Season']
#				if (!imdb_results['EpisodeName'].nil? and imdb_results['EpisodeName'].empty?) and (!imdb_results['EpisodeID'].nil? and imdb_results['EpisodeID'].empty?) and (!imdb_results['Season'].nil? and imdb_results['Season'].empty?)
				if imdb_results['tv/movie']==:movie
					movieData['Categorization']='Library/Movies'
				else
					movieData['Categorization']='Library/TVShows'
				end
			end
	
			#TODO Calculate results from answers obtained in above operations
			if answers[0]==TRUE
				cat='movie'
				if answers[1]==TRUE
					cat=''
				end
			end
			if answers[1]==TRUE
				cat='tv'
				if answers[0]==TRUE
					cat=''
				end
			end
			if ((answers[2].to_i) /1024/1024) > 600
				unless answers[1]
					cat='movie'
				end
			end
			if answers[4]
				cat='tv'
			end
			if answers[5]
				cat='tv'
			end
			if cat=='tv'
				movieData['Categorization']='Library/TVShows'
			elsif cat=='movie'
				movieData['Categorization']='Library/Movies'
			end

			return FALSE

			#FIXME Decide if movie, return answers else FALSE
		end

		#This function takes a source, either :tvdb or :imdb, and a filePath to search for within that DB
		def self.db_include?( source, movieData )
			fpath = movieData['Path'] #FIXME  Just use movieData['Path'] everywhere instead of fpath

			#remove any sourceDirs from fpath
			$MEDIA_SOURCES_DIR.each {|sourceDir|
				if fpath.match(Regexp.new(sourceDir))
					fpath=fpath.gsub(Regexp.new(sourceDir), '')
				end
			}
			filename=pathToArray(fpath)

			searchTerm=getSearchTerms( fpath, ['xvid', 'eng', 'ac3', 'dvdrip'] )
			results={}
			searchResults=[]
			if source==:tvdb
				searchTerm.each_index {|i|
					temp=[]
					results[searchTerm[i]]||=[]
					temp= MediaManager::MM_TVDB2.searchTVDB( searchTerm[i] )
					next if temp.length == 0
					searchResults << temp
				}
				searchResults.each_index {|i|
					temp=searchResults[i]
					temp=MediaManager::MM_TVDB2.populate_results(temp)

					#reformat it to what is expected from MM_TVDB by the code below
					temp.each {|series|
						series.each_key {|attribute|
							if series[attribute].class==Array
								series[attribute].each_index {|ep_i|
#									series[attribute][ep_i].each_key {|ep_attr|
#										series[attribute][ep_i][ep_attr]=[series[attribute][ep_i][ep_attr]]
#									}
									series[attribute][ep_i]['EpisodeID']="S#{series[attribute][ep_i]['SeasonNumber'].to_i}E#{series[attribute][ep_i]['EpisodeNumber']}"
								}
							else
								series[attribute]=[series[attribute]]
							end
						}
						series['EpisodeList']=series['Episodes']
					}
					results[searchTerm[i]]= temp
				}
			else
				searchTerm.each_index {|i|
					temp=false
					temp= MediaManager::MM_IMDB.searchIMDB( searchTerm[i] )
					next if temp.empty? or temp.class==FalseClass
					results[searchTerm[i]]||=[]
					results[searchTerm[i]]= temp
				}
			end
			occurance={}
			#Try and pick a few top results
			results.each_key {|searchWord|
				#For each result returned for each search, increase the popularity counter for that series
				results[searchWord].each {|result|
					occurance[hash_filename result.to_s] ||=0
					occurance[hash_filename result.to_s]=occurance[hash_filename result.to_s]+1
				}
			}
			series={}
			results.each {|listOfSeries|
					listOfSeries[1].each {|seriesHash|
						if seriesHash.class==Array and seriesHash.length==2
							unless series.has_key? seriesHash[0]
								series.merge!({ seriesHash[0] => seriesHash[1]})
							end
						else
							unless series.has_key? seriesHash['thetvdb_id']
								series.merge!({ seriesHash['thetvdb_id'] => seriesHash })
							end
						end
						
					}
			}
			occurance=occurance.sort {|a,b| a[1]<=>b[1]}.reverse
			#No longer have to use results array, can use series.
			matches=[]
			if (seasonNum=movieData['EpisodeID'].match(/s[\d]+/i)) and (epNum=movieData['EpisodeID'].match(/[\d]+$/))
				seasonNum=seasonNum[0].reverse.chop.reverse.to_i unless seasonNum.nil?
				epNum=epNum[0] unless epNum.nil?
			end
			name=filename[1].gsub($change_to_whitespace, ' ').squeeze(' ')
			name=name.gsub(MediaManager::RetrieveMeta.get_episode_id(name)[0], '').squeeze(' ') if MediaManager::RetrieveMeta.get_episode_id(name)
			cleaned_path=movieData['Path'].gsub($change_to_whitespace, ' ').squeeze(' ')
			series.each {|seriesHash|
				#movie_object=nil

				#seriesHash[1] may sometimes be an empty array, in cases where the title program returned it's title but did not present full information on said title
				#Extrapolate some information from the title if we can
				if source!=:tvdb
					movieInfo=MovieInfo.new
					#movie_object=[seriesHash[0], []]
					pp seriesHash[0] unless seriesHash[0].match(/^.+?[\d]{4}.*?\)/)

					clean_title=seriesHash[0].match(/^.+?[\d]{4}.*?\)/)
					episode_info=seriesHash[0].match(/\{.+?\}$/)
					is_tv_show=false
					if clean_title.nil? or clean_title[0].match(/[\d]{4}.*?\).*?$/).nil?
						puts 'wtf is this?'
						pp seriesHash
					end
					year=clean_title[0].match(/[\d]{4}.*?\).*?$/)[0]
					year=year.match(/[\d]{4}/)[0]
					clean_title=clean_title[0].gsub(/\((([.]{1,4})?(\d){4}|(\d){4}([.]{1,4})?)\)$/, '').strip
					unless year.nil?
#						year=year.chop.reverse.chop.reverse
					end
					movieInfo.setYear year
#					movie_object[1] << {'Year'=>year} 
				

					#only sure way to tell if it's a tv show or not is to look for '"'
					is_tv_show=true if clean_title.strip.match(/^".+?"/)

					if (episode_info.nil? and is_tv_show.class==FalseClass)
						if clean_title.match(/"/)
							pp seriesHash
							pp clean_title
						end
						#isn't tvshow
						movieInfo.Become({'Title'=>clean_title, 'tv/movie'=>:movie})
#						movie_object[1] << {'Title'=>clean_title} 
#						movie_object[1] << {'tv/movie'=>:movie}
					else
						#Is tvshow
						clean_title=clean_title.gsub(/\([\d]{4}-[\d]{2}-[\d]{2}\)/,'').strip.gsub(/^"/, '').gsub(/"$/, '')
						if episode_info.nil?
							date_aired=nil
							episode_id=nil
						else
							date_aired=episode_info[0].match(/\([\d]{4}-[\d]{2}-[\d]{2}\)/)
							episode_id=episode_info[0].match(/\(#[\d]+?\.[\d]+?\)/)
						end

						movieInfo.Become({'Title'=>clean_title, 'tv/movie'=>:tv})
						movieInfo.Become({'EpisodeAired'=>DateTime.parse(date_aired[0].chop.reverse.chop.reverse)}) unless date_aired.nil?
						season=nil
						episodeNumber=nil
						if !episode_id.nil?
							episode_id=episode_id[0]
							movieInfo.Become({'Season' => (season=episode_id.reverse.chop.chop.reverse.match(/\d+?\./)[0].chop),
													 'EpisodeNumber' => (episodeNumber=episode_id.chop.match(/\.\d+?$/)[0].reverse.chop.reverse),
						 								'EpisodeName' => episode_info[0].gsub(episode_id, '').gsub(/\([\d]{4}-[\d]{2}-[\d]{2}\)/, '').chop.reverse.chop.reverse.strip})
							movieInfo.Become({'EpisodeID' => "S#{season}E#{episodeNumber}"}) unless (season.empty? or episodeNumber.empty?)
						else
							movieInfo.Become({'Season'=>'', 'EpisodeNumber'=>'', 'EpisodeID'=>''})
							movieInfo.Become({'EpisodeName'=>episode_info[0].gsub(/\([\d]{4}-[\d]{2}-[\d]{2}\)/, '').chop.reverse.chop.reverse}) unless episode_info.nil?
						end

					end
					raise "Panic! This one has no year!" unless !clean_title.nil?
					
				end

				unless seriesHash[1].class==Array or !seriesHash[1].has_key?('EpisodeList') or seriesHash[1]['EpisodeList'].empty?   #This part will only be processed if source==:tvdb
					seriesHash[1]['EpisodeList'].each {|episode|
						episode.merge!({ 
							'Title' => seriesHash[1]['Title'][0],
							'tvdbSeriesID' => seriesHash[1]['thetvdb_id'][0] 
						})
						episode.merge!({ 'imdbID' => seriesHash[1]['imdbID'][0] }) if seriesHash[1].has_key?('imdbID')
						epName=episode['EpisodeName']     #For convenience
						epName='' if epName.class==FalseClass  #convert no episode name into an empty string from it's usual 'false' state for the sake of matching
						#If the episode name begins with 'the', strip it to ease matching.
						#Required to match files that were named without 'the' at the beginning of the name
						epName=epName.gsub(/^the[\s]+/i, '') if epName.index(/^the[\s]+/i)

						#Try and match episode to file
						matched=fuzzyMatch(name, epName, :yes)
						
						unless matched.class==FalseClass
							#match successfull
							matches << episode.merge!({ 'Matched' => matched })
							next
						end						

						#Next before here if already matched
						#
					}
				end #of unless seriesHash[1]['EpisodeList'].empty?

				#Now try to match imdb results
				if !movieInfo.nil? and !movieInfo.empty?
					#Remember to only work with the key that points TO series, not series['Title'] itself because it may not exist (*/me shakes fist at moveidb*)
	#				pp seriesHash unless source==:tvdb
#					pp movie_object unless source==:tvdb
	#				raise 'XL' unless source==:tvdb
#					puts "name: '#{name}',  is it this?    title: '#{movieInfo.Title}' is: '#{movieInfo['tv/movie']}'"
					pp movieInfo if movieInfo['Title'].downcase.include? 'raider'
					if MediaManager.name_match?(name, movieInfo['Title'])
#						puts "db_include?():  Matched name_match?()"
						matches << movieInfo.merge({ 'Matched'=>:name_match? })
						next
					end
					#This one matches the movie title to the name of the parent directory, to match if say the movie has the name sa.avi, the parent dir is Smokin' Aces, and the title is Smokin' Aces
					if MediaManager.name_match?(File.basename(File.dirname(fpath)).gsub($change_to_whitespace, ' '), movieInfo['Title'])
						puts "db_include?():  Matched name_match?() to parent directory"
						matches << movieInfo.merge({ 'Matched'=>:name_match? })
						next
					end
				end
			}

			return matches if matches.length==1

#			pp matches
#			puts "Path is : " ; printf movieData['Path']
			if matches.length < 1
				puts "db_include?():  No results using '#{source.to_s}'"
				return []
			end
			#From this point forward, by process of elimination, there can only be more >1 match remaining
			puts "db_include?(): More than one match found for this file.  Trying to get rid of extaneous matches..."
			scores={}
			_scores=[]
			matches.each_index {|ind|
				hash_of_match=hash_filename(matches[ind].to_s)
				matches[ind].merge!( { 'Hash' => hash_of_match })
				match=matches[ind]
				scores[hash_of_match]||=0
				#If the title is found in the filename, add the length of the title to the score
				if name_match?(name, match['Title'], :no )==TRUE
					scores[hash_of_match]=scores[hash_of_match]+1
					scores[hash_of_match]+= match['Title'].length

				elsif name_match?(File.basename(File.dirname(fpath)).gsub($change_to_whitespace, ' '),match['Title'], :no)==TRUE
					scores[hash_of_match]=scores[hash_of_match]+1
					scores[hash_of_match]+= match['Title'].length
				end

				#If the match has a year, and that year is found somewhere in the filepath, add a couple points to that match's score
				if !match['Year'].nil? and fpath.match(Regexp.new(match['Year']))
					puts "Match's year is found in filepath, incrementing score"
					pp imdb_results
					scores[hash_of_match]+=4
				end
			}

			matches.each_index {|ind|
				#If this is a case of an episodeID not matching an episodeName
				matches.each_index {|other_index|
					next if ind==other_index
					if (matches[ind]['Matched']==:epid and matches[other_index]['Matched']==:name_match? and matches[ind]['Title']==matches[other_index]['Title'] and name_match?(cleaned_path, matches[ind]['Title']) )
						puts "db_include?(): This file's episodeID and episodeName point to different episodes.\n"
						puts "This is the file"
						puts "#{movieData['Path']}"

						$NameIDConflictHint||=[0]
						if movieData['Path'].gsub(/\/[^\/]+?$/, '')==$NameIDConflictHint[0]
							if MediaManager::prompt( "db_include?(): Use the stored hint for this folder? ('#{movieData['Path'].gsub(/\/[^\/]+?$/, '')}', Hint: #{ $NameIDConflictHint[1]==:id ? 'EpisodeID' : 'EpisodeName' })")==:yes
								if $NameIDConflictHint[1]==:id
									scores[matches[ind]['Hash']]+=1000  #User said this is the right one
								elsif $NameIDConflictHint[1]==:name
									scores[matches[other_index]['Hash']]+=1000
								end
							end
						else		
							#Ask the user which is correct, and remember that for each additional file in this folder with this title
							question=""
							question<<"1 (fix)-> You can either play a little bit of the file to figure out which one it is\n"
							question<<"2 (ignore)-> Ignore the file to process later\n"
							question<<"3 (quit)\n"
							response=MediaManager::prompt( question, :ignore, [:fix, :ignore], [:yes, :no] )
							if response==:fix
								puts "\nThis one is matched by the episodeID:"
								puts "#{matches[ind]['Title']} - #{matches[ind]['EpisodeID']} - #{matches[ind]['EpisodeName']}"
								puts "Overview:    #{matches[ind]['Overview']}"
								puts "\nThis one is matched by the episodeName:"
								puts "#{matches[other_index]['Title']} - #{matches[other_index]['EpisodeID']} - #{matches[other_index]['EpisodeName']}"
								puts "Overview:    #{matches[other_index]['Overview']}"
								response=MediaManager::prompt( "Which is correct, the id or the name?", nil, [:id, :name, :neither], [:yes, :no] )
								$NameIDConflictHint[0]=movieData['Path'].gsub(/\/[^\/]+?$/, '')
								if response==:id
									$NameIDConflictHint[1]=:id
									scores[matches[ind]['Hash']]+=1000  #User said this is the right one
								elsif response==:name
									$NameIDConflictHint[1]=:name
									scores[matches[other_index]['Hash']]+=1000
								else #:neither
									raise "Really? Neither?  What the fuck just happened?"
								end
							else #:ignore
								return :ignore
							end
						end #of hint
					end
				}
			}
			
			_scores=scores.sort {|a,b| a[1]<=>b[1]}.delete_if {|hash, score| score == 0}
			duplicates=[]
			if _scores.length != 1
				#For each match, search through all other matches for an episode name that fits inside the first
				#match's episodename.  If there are matches, they should be removed.
				matches.each {|match|
					matches.each {|othermatch|
						next if match==othermatch
						unless match['EpisodeName'].nil? or othermatch['EpisodeName'].nil? or match['EpisodeName'].empty? or othermatch['EpisodeName'].empty? or match['Title']!=othermatch['Title'] 
#							puts "Comparing:  1(#{match['Title']}, #{match['EpisodeName']}, #{match['EpisodeNumber']}, #{match['Season']})   2(#{othermatch['Title']}, #{othermatch['EpisodeName']}, #{othermatch['EpisodeNumber']}, #{othermatch['Season']})"
							if match['EpisodeName'].index(othermatch['EpisodeName']) and match['EpisodeName']!=othermatch['EpisodeName']
								duplicates<<othermatch
#								scores[match['Hash']]+=1
								puts "One match fits inside one of the others, it has been removed."
							elsif othermatch['EpisodeName'].index(match['EpisodeName']) and othermatch['EpisodeName']!=match['EpisodeName']
								duplicates<<match
#								scores[othermatch['Hash']]+=1
								puts "One match fits inside one of the others, it has been removed."
							elsif match['EpisodeName'].downcase.index(othermatch['EpisodeName'].downcase) and match['EpisodeName'].downcase!=othermatch['EpisodeName'].downcase
								duplicates<<othermatch
#								scores[match['Hash']]+=1
								puts "One match fits inside one of the others after downcasing both, it has been removed."
							end
						end
					}
					
				}
				unless duplicates.empty?
					duplicates.each {|dupe|
						matches.delete dupe
					}
				end	 
			end	
			_scores=scores.sort {|a,b| a[1]<=>b[1]}.delete_if {|hash, score| score == 0}
			#Scores will either be of length 1, and you can return that, or
			#it will have a list of matches with the highest-rated sorted to the top, and return that one.
			#if _scores is > 1 and there is more than one match
			if _scores.length > 1 and matches.length != 1
				pp _scores.reverse
#				raise "false positive detected, sort matches and reduce!" 
				question= "db_include?():  Could not reduce false positives further.\n"
				question<<"User input required to select correct match for '#{fpath}'.\n"
				question<<"choose, ignore, skip, or quit?"
				response=MediaManager::prompt( question, :ignore, [:choose, :ignore, :skip], [:yes, :no] )
				return :ignore if response==:ignore or response==:skip
				#response should be :choose from here on
				raise "wtF?" if response!=:choose


				_scores.reverse.each {|hash_to_score|
					the_match=nil
					matches.each {|match|
						the_match=match if match['Hash']==hash_to_score[0]
					}
					raise 'wtf' if the_match.nil?
					pp the_match
					question="Is this the one?\n############\nFile is:'#{name}',\nTitle: '#{the_match['Title']}',\nTv/Movie: '#{the_match['tv/movie'].to_s.capitalize}'\nEpisode Name:  '#{the_match['EpisodeName']}',\nEpisode Number: '#{the_match['EpisodeNumber']}',\nSeason: '#{the_match['Season']}'\nEpisodeID: '#{the_match['EpisodeID']}',\nYear: '#{the_match['Year']}'\n"
					response=MediaManager.prompt( question, :no )
					next if response!=:yes
					return [the_match]
				}
				#Should only get here if the user selected 'no' to all of the above?
				puts "\n\n\nYou have selected no to every result that was returned for '#{fpath}'.\nThis file will be ignored this time around, maybe there will be different/more matches next time.\n"
				sleep 3
				return :ignore
			elsif _scores.length > 1
				#One match, remove all others and return this one match
				oneMatch=[]
				matches.each {|match|
					pp match
					if _scores[0][0] == hash_filename(match.to_s)
						pp match
						return [match]
					end
				}
			elsif _scores.length==1
				#r or response==:skipaise "HUH"
				still_exists=[]
				_scores.each {|popularity_score|
					still_exists << popularity_score[0]
				}
				matches=matches.delete_if {|match|
					!still_exists.include?(match['Hash'])
				}
			else
				#Multiple matches, none of which could accumulate a score, so return nothing
				return []
				pp matches
				pp scores
				pp _scores

				#what would cause the program to get here?
				#Will get here if _scores is empty, but there are matches and scores != empty?
				raise "WHATHUH??"
			end
			raise "Error, more than one match remains!" if matches.length > 1
			return matches
		end

	end
end
