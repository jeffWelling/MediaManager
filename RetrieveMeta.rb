load 'MMCommon.rb'
load 'Hasher.rb'
load 'romanNumerals.rb'

require 'rubygems'
require 'linguistics'

module MediaManager
	module RetrieveMeta
		extend MMCommon
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
		#is_rar is :yes if the filename passed is a folder containing a rared file
	  def self.filenameToInfo(filename, is_rar=:no)
	    puts "\nWorking on #{filename}"
			movieData=$movieInfoSpec.clone
			movieData['Path']=filename

			sql_result=sqlSearch( "SELECT * FROM mediaFiles WHERE PathSHA = '#{hash_filename movieData['Path']}'" )
			unless sql_result.empty?
				movieData=sql_result[0]
				puts "Metainformation is available based on a hash of the filename."
				puts "Checking that file has not changed..."
			end			

			if movieData['FileSHA'].empty?
				movieData['FileSHA']=hash_file filename
			end
			
			#Check the consistency of the file
			filehash=hash_file filename
			unless filehash==movieData['FileSHA']
				raise "filenameToInfo: File hash has changed!" \
					<< "\nIf you have not changed the file, it may have become corrupt."
			end

			#Don't need to update if they're the same...
			#Get data from MySQL if possible
			sql_result2=''
			sql_result2=sqlSearch( "SELECT * FROM mediaFiles WHERE FileSHA = '#{movieData['FileSHA']}'" )
			unless sql_result2.empty?
				unless sql_result.empty?
					if sql_result[0]['id'] != sql_result2[0]['id']
						raise "filenameToInfo(): Lookup Conflict! filename based lookup and file based lookup product conflicting results."
					end
				end

				#Because this sql_result is produced based on the file's hash, the filename may not match
				#FIXME When comparing paths, some filesystems are case senesetive and others are not.  
				if movieData['Path'] != sql_result2[0]['Path']
					puts "Looking up the file's hash produces a different path!"
					if File.exist?(sql_result2[0]['Path'])
						if File.exist?(movieData['Path'])
							#By not doing anything here, the movieData is overwritten with the 'old' path which
							#is still valid.  This MUST be detected after filenameToInfo() returns to properly
							#handle duplicates!
							puts "WARNING!!: this file is a duplicate!"					
						end
					else #The sql_result2 path leads to a file that doesn't exist.
						puts "NOTICE: The file's hash brings up database results whos path points to a non-existant file."
						puts "NOTICE: Old path: #{sql_result2[0]['Path']}"
						puts "NOTICE: Because the old file is not accessible, continuing using new path for file."
						sql_result2[0]['PathSHA']= hash_filename(movieData['Path'])     #Just for posterities sake, don't want to show the old hash for the new path ><
						sql_result2[0]['Path']= movieData['Path']
					end
				end
				movieData=sql_result2[0]
			end
			puts "File already in database, using info..." unless movieData['id'].nil?
			return movieData unless movieData['id'].nil?


			#Can't process escaped slashes yet, attempting to may cause inexplicable behaviour.
			if filename.index('//') || filename.index('\/')
	      raise "Not yet able to process files with '//' or escaped slashes such as '\/'.\n"    #what if OMGKERNELPANIC...  ?
				return FALSE
	    end 

			#seperated into two lines so that extractData() is run once not twice
			it= extractData(movieData, is_rar)
			return it if it==:ignore
	    if it != FALSE then movieData = it end

			#Save the size of the file for reference
			movieData['Size']=File.size?(movieData['Path'])

			return movieData
	   #FIXME  Continue from here 
	  end 

		#This function does its  best to extract information from the filename
		def self.extractData(movieData, is_rar=:no)
			puts "Reaching up my /dev/null and pulling out some meta-data...."
			raise "OMG CANT HANDLE RARS YET!!FIXMEYOUIDIOT!!" if is_rar!=:no
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
			return result if result==:ignore
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
			#db_include?( :imdb, movieData)
			
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
			full_path = movieData['Path'] #FIXME  Just use movieData['Path'] everywhere instead of full_path

			#remove any sourceDirs from full_path
			$MEDIA_SOURCES_DIR.each {|sourceDir|
				if full_path.match(Regexp.new(sourceDir))
					full_path=full_path.gsub(sourceDir, '')
				end
			}
			filename=pathToArray full_path

			#Extract 'words' from filename, one at a time, and search for them.
			queue=filename[1].gsub('.', ' ').gsub('_', ' ')
			done=FALSE;
			i=0
			search_terms=[]
			filename.each_index {|filename_index|
				queue=filename[filename_index].gsub('.', ' ').gsub('_', ' ')
				ignore=FALSE
				loop do  #FIXME Can't this be optimized any further?
					search_terms[i] ||= ''
					ignore=FALSE
					break if queue.empty?
					#break if search_terms[i-1].nil?
					break if queue.match(/[\w']*\b/i).nil?
					search_terms[i]=match= queue.match(/[\w']*\b/i)
					match=match[0]
					if MediaManager::RetrieveMeta.get_episode_id(search_terms[i][0]).nil?    #If it's NOT an episodeID tag
						search_terms[i]=search_terms[i][0]
						search_terms[i] = "#{search_terms[i-1]} " << search_terms[i] unless i==0
					else
						#search_terms[i] is a MatchData type of match
						search_terms[i]=''
					end
					queue= queue.slice( queue.index(match)+match.length, queue.length ).strip 
#Using 'ignore's in this area is less effective and more problematic than just running a delete_if loop later.
#					ignore=TRUE if search_terms[i].length < 3 or search_terms[i].strip.downcase=='the' or search_terms[i].strip.downcase=='and'

					i=i+1# unless ignore
				end
				i=i+1# unless ignore
			}
			#search_terms is now an array of search terms
			#search for each, and store the results.
			search_terms=search_terms.delete_if {|it| TRUE if it.nil? or it.empty? or name_match?(it, filename[0].reverse.chop.reverse, :no)}.each_index {|lineN| search_terms[lineN]=search_terms[lineN].strip }
			search_terms=search_terms.delete_if {|word| TRUE if ['the','and'].include?(word) or word.length <= 3 }
			results={}
			search_results=[]
			if source==:tvdb
				search_terms.each_index {|i|
					temp=[]
					results[search_terms[i]]||=[]
					temp= MediaManager::MM_TVDB2.searchTVDB( search_terms[i] )
					next if temp.length == 0
					search_results << temp
				}
				search_results.each_index {|i|
					temp=search_results[i]
					temp=MediaManager::MM_TVDB2.populate_results(temp)

					#reformat it to what was expected from MM_TVDB
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
					results[search_terms[i]]= temp
				}
			else
				search_terms.each_index{|i|
					temp=[]
					results[search_terms[i]]||=[]
					temp= MediaManager::MM_IMDB.searchIMDB( search_terms[i] )
					break if temp.length == 0
					results[search_terms[i]]= temp
				}
			end
			$results = results
			#pp results
			occurance={}
			#Try and pick a few top results
			#Present results to user, have user pick
			results.each_key {|search_word|
				#For each result returned for each search, increase the popularity counter for that series
				results[search_word].each {|result|
					occurance[result['thetvdb_id']] ||=0
					occurance[result['thetvdb_id']]=occurance[result['thetvdb_id']]+1
				}
			}
			series={}
			results.each {|list_of_series|
				list_of_series[1].each {|series|
					unless series.has_key? series['thetvdb_id']
						series.merge!({ series['thetvdb_id'] => series })
					end
				}
			}
			occurance=occurance.sort {|a,b| a[1]<=>b[1]}.reverse
			#No longer have to use results array, can use series.
			matches=[]
			if (season_number=movieData['EpisodeID'].match(/s[\d]+/i)) and (ep_number=movieData['EpisodeID'].match(/[\d]+$/))
				season_number=season_number[0].reverse.chop.reverse.to_i
				ep_number=ep_number[0]
			end
			name=filename[1].gsub('.', ' ').gsub('_', ' ').gsub('-', ' ').squeeze(' ')
			name=name.gsub(MediaManager::RetrieveMeta.get_episode_id(name)[0], '').squeeze(' ') if MediaManager::RetrieveMeta.get_episode_id(name)
			cleaned_path=movieData['Path'].gsub('.', ' ').gsub('_', ' ').gsub('-', ' ').squeeze(' ')
			series.each {|series|
				unless series[1]['EpisodeList'].empty?
					series[1]['EpisodeList'].each {|episode|
						episode.merge!({ 
							'Title' => series[1]['Title'][0],
							'tvdbSeriesID' => series[1]['thetvdb_id'][0] 
						})
						episode.merge!({ 'imdbID' => series[1]['imdbID'][0] }) if series[1].has_key?('imdbID')
						current_episode_name=episode['EpisodeName']     #For convenience
						current_episode_name='' if current_episode_name.class==FalseClass  #convert no episode name into an empty string from it's usual 'false' state for the sake of matching
						#If the episode name begins with 'the', strip it to ease matching.
						#Required to match files that were named without 'the' at the beginning of the name
	
						current_episode_name=current_episode_name.gsub(/^the[\s]+/i, '') if current_episode_name.index(/^the[\s]+/i)

						if name==current_episode_name
							puts "db_include?(): Matched one to one"
							matches << episode.merge('Matched'=>:oneToOne)
							next
						end

						##Begin attempting to match	
						if (current_episode_name.length > 1 and MediaManager.name_match?(name, current_episode_name))
							puts "db_include?(): Matched name_match?()"
							matches << episode.merge('Matched'=>:name_match?)
							next
						end
						
						if current_episode_name.index(/\([\d]+\)/)
							next unless name.match(/\(.*[\d]+.*\)/)    #No need to process this if the filename has no ([\d]+.*) in it
							current_episode_name=episode['EpisodeName'].gsub(/[:;]/, '')
#							puts current_episode_name.slice( 0,current_episode_name.index(/\([\d]+\)/) )
#							puts current_episode_name.slice( (current_episode_name.index(/\([\d]+\)/) + current_episode_name.match(/\([\d]+\)/)[0].length),current_episode_name.length )
							part2= current_episode_name.slice( current_episode_name.index(/\([\d]+\)/)+current_episode_name.match(/\([\d]+\)/)[0].length,current_episode_name.length ).downcase
							regex1= Regexp.new( Regexp.escape(current_episode_name.slice( 0,current_episode_name.index(/\([\d]+\)/) ).downcase))
							regex2= Regexp.new( Regexp.escape(part2) )
							unless part2.empty?   #If there are strings on both side of the digit, use that.  Otherwise, attempt to use the [\d] provided
								if name.downcase.match(regex1) and name.downcase.match(regex2)
									puts "db_include?(): Matched based on both sides of a digit thingy"
									matches << episode.merge('Matched'=>:digits)
									next
								end
							end
							#Should only get here if the string following ([\d]) is empty or the match above wasn't successful
							#Use the first digit in the ( ) as the part number if it matches.
							regex2= Regexp.new( Regexp.escape(current_episode_name.match(/\([\d]+\)/)[0].chop.reverse.chop.reverse) )
							if part=name.match(/\(.*[\d]+.*\)/)    #If the filename has ([\d]) in it
								part=part[0].match(/[\d]+/)[0]
								if part.match(regex2)  #Match
									puts "db_include()?: Matched based on part number  (alternative digit thingy match)"
									matches << episode.merge('Matched'=>:digits)
									next
								end
							end
						end
						
						#Attempt to deal with Roman Numerals
						#The following regex was adapted from Example 7.8 of http://thehazeltree.org/diveintopython/7.html
						roman_numeral_regex=/\s[M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})]+\s/
						padded_name= (((name.reverse) + ' ').reverse) + ' ' # This allows us to use whitespace as delimiters for either side of a RN (Roman Numeral)
						current_episode_name= ((current_episode_name + ' ').reverse + ' ').reverse
						if current_episode_name.match(roman_numeral_regex) or padded_name.match(roman_numeral_regex)
							#NOTE To the reader
							#This is my attempt at identifying a roman numeral in the filename
							#and converting it to an integer for comparison with the digit
							#in the episode name.  I whole heartedly believe there ^is^ a 
							#better way to do this that I haven't found yet.
							#NOTE We do not anticipate more than one Roman Numeral in the filename.
							#printf "Episode name: "; puts current_episode_name
							#printf "Filename: "; puts padded_name
							if padded_name.match( roman_numeral_regex )
								#puts "Roman numeral found in filename, it is printed on the following line."
								#pp padded_name.match(roman_numeral_regex)[0].strip
								padded_name=padded_name.gsub(Regexp.new(Regexp.escape(padded_name.match(roman_numeral_regex)[0])), 
									"#{toArabic( padded_name.match(roman_numeral_regex)[0].strip ).to_s} " ) unless toArabic(padded_name.match(roman_numeral_regex)[0].strip)==0
								if current_episode_name.match(Regexp.new(Regexp.escape(padded_name), TRUE))
									puts "db_include()?:  Matched based on roman numeral in filename and converted"
									matches << episode.merge('Matched'=>:romanNumerals)
									next
								end
							elsif current_episode_name.match(roman_numeral_regex)
								#puts "Roman numeral found in episode name, it is printed on the following line."
								#printf "Matching: "; pp current_episode_name.match(roman_numeral_regex)[0].strip
								#printf "Replacing with: "; pp toArabic(current_episode_name.match(roman_numeral_regex)[0].strip).to_s
								current_episode_name=current_episode_name.gsub(Regexp.new(Regexp.escape(current_episode_name.match(roman_numeral_regex)[0])), 
									" #{toArabic(current_episode_name.match(roman_numeral_regex)[0].strip).to_s} " ) unless toArabic(current_episode_name.match(roman_numeral_regex)[0].strip)==0
								#puts padded_name
								if padded_name.match(Regexp.new(Regexp.escape(current_episode_name), TRUE))
									puts "db_include()?: Matched based on roman numeral found in episodename and converted"
									matches << episode.merge('Matched'=>:romanNumerals)
									next
								end
							end
						end


						if current_episode_name.index(':') #May be split into parts, try and match each side of the :
							current_episode_name=episode['EpisodeName'].gsub(/\([\d]+\)/, '')   #Strip out any () parts
							regex1= Regexp.new( Regexp.escape(current_episode_name.slice(0,current_episode_name.index(':')).downcase) )
							regex2= Regexp.new( Regexp.escape(current_episode_name.slice(current_episode_name.index(':')+1,current_episode_name.length).downcase) )

							if name.downcase.match(regex1) and name.downcase.match(regex2)
								matches << episode.merge('Matched'=>:parts)
								puts "Dis one has : in it!"; pp episode
								puts "db_include?(): Matched based on both sides of a ':'"
								next
							end
						end
						
						#If an current_episode_name has 'a.k.a.' in it, check either side.  Just like any other delimiter
						if current_episode_name.index('a.k.a.')
							#For the purposes of matching the 'a.k.a.' it appears necessary to strip out parenthesis
							#from the current_episode_name, Regexp throws an error if it encounters unmatched parenthesis
							current_episode_name=current_episode_name.gsub('(', '').gsub(')', '')
							first_part= current_episode_name.slice( 0,current_episode_name.index('a.k.a.')-1 )
							last_part= current_episode_name.slice( current_episode_name.index('a.k.a.')+ 'a.k.a.'.length, current_episode_name.length)
							if name.match(Regexp.new(first_part, TRUE))
								puts "db_include?(): Matched the first part of the name, up to 'a.k.a.'."
								matches << episode.merge('Matched'=>:aka)
								next
							elsif name.match(Regexp.new(last_part, TRUE))
								puts "db_include?(): Matched the last part of the name, after the 'a.k.a.'."
								matches << episode.merge('Matched'=>:aka)
								next
							end
						end

						#Here I am trying to look for the current_episode_name in name the same way that I would as a human
						#I think the way to do this is to break the string into words, and look for a single 
						#character from the beginning and end of each respective word in current_episode_name and try
						#match those beginnings and ends of words to beginnings and ends of words in name.
						#This can be further refined by looking for characters that stand out, like 't' or 'g'
						#as opposed to ones that don't like 'a' or 'c'.  Looking for characters that stand out 
						#in name that aren't in current_episode_name can accomplish this.  This may be further refined without 
						#updating this little blurb.i
						#Note: Admittedly, this cannot catch spelling mistakes at the beginning or end of a word.
						if name.gsub('-', ' ').gsub('_', ' ').gsub('.', ' ').split(' ').length > 2
							current_episode_name=current_episode_name.strip
							distance=3
							ep_name_result=[]

							ep_name_array=[]
							name_array=[]
							current_episode_name.split(' ').each {|word|
								ep_name_array << word unless word.length <= 2
							}
							
							name.gsub('-', ' ').gsub('_', ' ').gsub('.', ' ').split(' ').each {|word|
								name_array << word unless word.length <= 2
							}
							ep_name_array.each_index {|ep_name_index|
								name_array.each_index { |name_index|
									if ep_name_array[ep_name_index].slice(0,1)==name_array[name_index].slice(0,1) and
											ep_name_array[ep_name_index].slice(ep_name_array[ep_name_index].length-1, 1)==name_array[name_index].slice(name_array[name_index].length-1, 1)

										ep_name_result[ep_name_index]=TRUE
									else
										ep_name_result[ep_name_index]=FALSE
									end
								}
							}
							#matched
							ep_name_result= ep_name_result.delete_if {|wordMatched| wordMatched == FALSE}
							if ep_name_result.length == name_array.length
								puts "db_include?(): Matched based on blind comparison of characters at word boundaries, accurate?"
								matches << episode.merge('Matched'=>:wordBoundaries)
								next
							end
						end

						#Convert integer to word and try to match
						if name.match(/\d+/)
							long_name=name.gsub(name.match(/\d+/)[0], Linguistics::EN.numwords(name.match(/\d+/)[0]))
							if long_name.match(Regexp.new(Regexp.escape(current_episode_name), TRUE))
								unless current_episode_name.empty?    #To prevent matching an empty episode name
									puts "db_include?(): Matched after converting the number to a word, no space."
									matches << episode.merge('Matched'=>:intWord)
									next
								end
							end

							long_name=name.gsub(name.match(/\d+/)[0], " #{Linguistics::EN.numwords(name.match(/\d+/)[0])} ")
							if long_name.match(Regexp.new(Regexp.escape(current_episode_name), TRUE))
								unless current_episode_name.empty?
									puts "db_include?():  Matched after converting the number to a word, with space."
									matches << episode.merge('Matched'=>:intWord)
									next
								end
							end
						end

						#FIXME Need to also match EpisodeID tags in the form of 1x08, and hopefully, 108
						#TODO This section should match even if the name does not match the filename, but it should issue a warning that the only thing that indicates this name is the EpisodeID tag and the series title
						#TODO Remember to use the variable we have stored the EpisodeID tag in, because it is stripped from name
						#If we already have the EpisodeID tag then we can look for that instead of trying to match the name.
						#Note, cannot account for filename giving inaccurate EpisodeID tag, simply will not match
						#This match still in development, not useful yet due to the high chance of being given a false positive EpisodeID tag
						# if... the tvdb seriesID of the top ranking series in occurance[] matches the current seriesID in series OR name_match?
						if season_number and ep_number and (occurance[0][0][0]==series[0][0] or name_match?( name,series[1]['Title'][0], :no))
							episodes_season_number=episode['EpisodeID'].match(/s[\d]+/i)[0].reverse.chop.reverse.to_i
							episodes_ep_number=episode['EpisodeID'].match(/[\d]+$/)[0]
							#printf "season_number: #{season_number}  episodes_season_number: #{episodes_season_number}  ep_number: #{ep_number}  episodes_ep_number: #{episodes_ep_number}      \n"
							if season_number.to_i==episodes_season_number.to_i and ep_number.to_i==episodes_ep_number.to_i
								puts "db_include?(): Match based on title found in filename, and season and episode number match from filename."
								matches << episode.merge('Matched'=>:epid)
								next
							end
						end
						
						#Try joining words together to see if that helps matching


						#Next before here if already matched
						#
					}
				end
			}

			return matches if matches.length==1

#			pp matches
#			puts "Path is : " ; printf movieData['Path']

			if matches.length < 1
				puts "No Results...?"
				puts "CRITICAL ERROR, No Matches!"
				pp matches
				return []
			end
			#From this point forward, by process of elimination, there can only be more >1 match remaining
			puts "db_include?(): More than one match found for this file.  Trying to get rid of extaneous matches..."
			scores={}
			_scores=[]
			matches.each_index {|ind|
				name=hash_filename(matches[ind].to_s)
				matches[ind].merge!( { 'Hash' => hash_filename(matches[ind].to_s) })
				match=matches[ind]
				scores[name]||=0
				#If the title is found in the filename, add the length of the title to the score
				if name_match?(pathToArray(movieData['Path'])[1], match['Title'], :no )==TRUE
					scores[name]=scores[name]+1
					scores[name]+= match['Title'].length
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

						$name_id_conflict_hint||=[0]
						if movieData['Path'].gsub(/\/[^\/]+?$/, '')==$name_id_conflict_hint[0]
							if MediaManager::prompt( "db_include?(): Use the stored hint for this folder? ('#{movieData['Path'].gsub(/\/[^\/]+?$/, '')}', Hint: #{ $name_id_conflict_hint[1]==:id ? 'EpisodeID' : 'EpisodeName' })")==:yes
								if $name_id_conflict_hint[1]==:id
									scores[matches[ind]['Hash']]+=1000  #User said this is the right one
								elsif $name_id_conflict_hint[1]==:name
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
								$name_id_conflict_hint[0]=movieData['Path'].gsub(/\/[^\/]+?$/, '')
								if response==:id
									$name_id_conflict_hint[1]=:id
									scores[matches[ind]['Hash']]+=1000  #User said this is the right one
								elsif response==:name
									$name_id_conflict_hint[1]=:name
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
					matches.each {|other_match|
						next if match==other_match
						if match['EpisodeName'].index(other_match['EpisodeName']) and match['EpisodeName']!=other_match['EpisodeName']
							duplicates<<other_match
							scores[match['Hash']]+=1
							puts "One match fits inside one of the others, it has been removed."
						elsif other_match['EpisodeName'].index(match['EpisodeName']) and other_match['EpisodeName']!=match['EpisodeName']
							duplicates<<match
							scores[other_match['Hash']]+=1
							puts "One match fits inside one of the others, it has been removed."
						elsif match['EpisodeName'].downcase.index(other_match['EpisodeName'].downcase) and match['EpisodeName'].downcase!=other_match['EpisodeName'].downcase
							duplicates<<other_match
							scores[match['Hash']]+=1
							puts "One match fits inside one of the others after downcasing both, it has been removed."
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
			if _scores.length > 1 and matches.length != 1
				pp _scores
				raise "false positive detected, sort matches and reduce!" 
			elsif _scores.length > 1
				#One match, remove all others and return this one match
				matches.each {|match|
					pp match
					if _scores[0][0] == hash_filename(match.to_s)
						pp match
						return [match]
					end
				}
			elsif _scores.length==1
				#raise "HUH"
				still_exists=[]
				_scores.each {|popularity_score|
					still_exists << popularity_score[0]
				}
				matches=matches.delete_if {|match|
					!still_exists.include?(match['Hash'])
				}
			else
			pp matches
			pp scores
			pp _scores

				#what would cause the program to get here?
				raise "WHATHUH??"
			end
			raise "Error, more than one match remains!" if matches.length > 1
			return matches
		end

		

	end
end
