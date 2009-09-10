load 'MMCommon.rb'
load 'Hasher.rb'
load 'romanNumerals.rb'

module MediaManager
	module RetrieveMeta
		extend MMCommon

		#getEpisodeID will search for all of the episodeIDs in random_string, and will return them.
		#If theres more than one, it will return them in an array, with the first episodeID as the first item.
		#If the reformat argument is set to anything that is not :no, it will reformat the episodeID into 
		#the standard 's2e22' format.
		def self.getEpisodeID random_string, reformat=:no
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
			id=MediaManager::RetrieveMeta.getEpisodeID(movieData['Path'], :reformat_to_standard)
			unless id.nil?
				id=id[0] if id.class==Array
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
			unless (imdb_results.empty? or imdb_results.nil?)
				pp imdb_results
				imdb_results=imdb_results[0] if imdb_results.class==Array and imdb_results.length==1
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
			clean_fpath=movieData['Path'].gsub($change_to_whitespace, ' ').squeeze(' ').strip
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
			episodeID=MediaManager::RetrieveMeta.getEpisodeID(name)
			episodeID=episodeID[0] if episodeID.class==Array
			name=name.gsub(episodeID, '').squeeze(' ') if MediaManager::RetrieveMeta.getEpisodeID(name)
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
=begin
						#Try and match the episode tag in the filename to an episode from the series we're searching
						#but only if the title of the series matches the filename or parent directory(ies)
						if name_match?(name, episode['Title']) and getEpisodeID(fpath)
							#episode's series title is found in the filename, if the episodeID found in the filename
							#is a valid one, match.
							filename_episodeID=getEpisodeID(clean_fpath)
							filename_episodeID=filename_episodeID[0] if filename_episodeID.class==Array
							pp episode
							pp filename_episodeID	
							if episode['EpisodeID'].downcase==filename_episodeID.downcase
								matches << episode.merge!({ 'Matched' => :epid })
								next
							end
						end
=end


						#Try and match episode name to filename
						matched=fuzzyMatch(clean_fpath, epName)
						unless matched.class==FalseClass
							#match successfull
							matches << episode.merge!({ 'Matched' => matched })
							next
						end

=begin
						#Try and match the episode tag in the filename to an episode from the series we're searching
						#but only if the title of the series matches the filename or parent directory(ies)
						if name_match?(name, episode['Title']) and getEpisodeID(fpath)
							#episode's series title is found in the filename, if the episodeID found in the filename
							#is a valid one, match.
							filename_episodeID=getEpisodeID(clean_fpath)
							filename_episodeID=filename_episodeID[0] if filename_episodeID.class==Array
							pp episode
							pp filename_episodeID	
							if episode['EpisodeID'].downcase==filename_episodeID.downcase
								matches << episode.merge!({ 'Matched' => :epid })
								next
							end
						end
=end

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
					if MediaManager.name_match?(name, movieInfo['Title'])
#						puts "db_include?():  Matched name_match?()"
						matches << movieInfo.merge({ 'Matched'=>:name_match? })
						next
					end
					#This one matches the movie title to the name of the parent directory, to match if say the movie has the name sa.avi, the parent dir is Smokin' Aces, and the title is Smokin' Aces
					if MediaManager.name_match?(clean_fpath, movieInfo['Title'])
#						puts "db_include?():  Matched name_match?() to parent directory"
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

			#create the scores
			matches.each_index {|ind|
				hash_of_match=hash_filename(matches[ind].to_s)
				matches[ind].merge!( { 'Hash' => hash_of_match })
				match=matches[ind]
				scores[hash_of_match]||=0

				#If the title is found in the filename, add the length of the title to the score
				if name_match?(name, match['Title'])==TRUE
					scores[hash_of_match]=scores[hash_of_match]+1
					scores[hash_of_match]+= match['Title'].length

				elsif name_match?(File.basename(File.dirname(fpath)).gsub($change_to_whitespace, ' '),match['Title'])==TRUE
					scores[hash_of_match]=scores[hash_of_match]+1
					scores[hash_of_match]+= match['Title'].length
				end

				#If the match has a year, and that year is found somewhere in the filepath, add a couple points to that match's score
				if !match['Year'].nil? and fpath.match(Regexp.new(match['Year']))
					puts "Match's year is found in filepath, incrementing score"
					pp imdb_results
					scores[hash_of_match]+=4
				end

				if name_match?(name, match['Title']) or name_match?(File.basename(File.dirname(fpath)).gsub($change_to_whitespace, ' '), match['Title'])
					#try to match any episodeIDs in the filename to the match
					already_matched=false
					unless getEpisodeID(clean_fpath, :ze_standard_format_they_must_be_in).nil?
					getEpisodeID(clean_fpath, :make_standard_format).each {|episodeID|
						if episodeID[/^(s)?[\d]+/i][/\d+/].to_i == match['Season'].to_i and episodeID[/[\d]+$/].to_i==match['EpisodeNumber'].to_i
							raise "wtf, TWO episodeIDs in the filename matched the episodeID in the match? CRAZIES!" if already_matched==true
							name_match?(name, match['Title']) ? scores[hash_of_match]+=(20+match['EpisodeName'].length) : scores[hash_of_match]+=(7+match['EpisodeName'].length)
							puts "db_include?():  Incremented scores because title matched, season and epnum matched."
							already_matched=true
						end
					} end
				end
			}



			matches.each_index {|ind|
				#If this is a case of an episodeID not matching an episodeName, prompt the user for help
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
				#Try and return the top scored match, if the difference in score is more than 10
				if (_scores.reverse[0][1] - _scores.reverse[1][1]) > 10
					puts "db_include?():  One match scored above the others, returning that."
					matches.each {|match|
						return match if match['Hash']==_scores.reverse[0][0]
					}
				end
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
					question="Is this the one?\n############\nFile is:'#{movieData['Path']}',\nTitle: '#{the_match['Title']}',\nTv/Movie: '#{the_match['tv/movie'].to_s.capitalize}'\nEpisode Name:  '#{the_match['EpisodeName']}',\nEpisode Number: '#{the_match['EpisodeNumber']}',\nSeason: '#{the_match['Season']}'\nEpisodeID: '#{the_match['EpisodeID']}',\nYear: '#{the_match['Year']}'\n"
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
