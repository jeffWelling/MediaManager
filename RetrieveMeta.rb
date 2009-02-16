load 'MMCommon.rb'
load 'Hasher.rb'
load 'romanNumerals.rb'

require 'rubygems'
require 'linguistics'

module MediaManager
	module RetrieveMeta
		extend MMCommon
		
		#Returns info in the form of a hash conforming to movieInfo_Specification.rb
		#isRar is :yes if the filename passed is a folder containing a rared file
	  def self.filenameToInfo(filename, isRar=:no)
	    puts "\nWorking on #{filename}"
			movieData=$movieInfoSpec.clone
			movieData['Path']=filename

			sqlresult=sqlSearch( "SELECT * FROM mediaFiles WHERE PathSHA = '#{hash_filename movieData['Path']}'" )
			movieData=sqlresult[0] unless sqlresult.empty?
			puts "Metainformation is available based on a hash of the filename." unless sqlresult.empty?
			puts "Checking that file has not changed..." unless sqlresult.empty?
			
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
			sqlresult2=''
			sqlresult2=sqlSearch( "SELECT * FROM mediaFiles WHERE FileSHA = '#{movieData['FileSHA']}'" )
			unless sqlresult2.empty?
				unless sqlresult.empty?
					if sqlresult[0]['id'] != sqlresult2[0]['id']
						raise "filenameToInfo(): Lookup Conflict! filename based lookup and file based lookup product conflicting results."
					end
				end
				movieData=sqlresult2[0]
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
	    if it != FALSE then movieData = it end

			#Save the size of the file for reference
			movieData['Size']=File.size?(movieData['Path'])

			return movieData
	   #FIXME  Continue from here 
	  end 

		#This function does its  best to extract information from the filename
		def self.extractData(movieData, isRar=:no)
			puts "Reaching blindly into /dev/null and pulling out some meta-data...."
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
			id=movieData['Path'].match(/[s]\d+[e]\d+/i)
			unless id.nil?
				id=id[0]
				puts "Found season tag #{id}, extracting Season and EpisodeID..."
				movieData['Season'] = id.match(/\d+/)[0].to_i
				movieData['EpisodeID'] = id.upcase
				answers[4]=TRUE
				#TODO Debug line, remove before publishing
				raise "Failed to set movieData fields with extracted data?" if movieData['Season'].nil? || movieData['EpisodeID'].nil?
			end

			#Is it in IMDB/TVDB?
			result=''
			result= db_include?( :tvdb, movieData)
			pp result
			answers[5]=TRUE unless result.empty?
			unless result.empty?
				movieData['Title']= result[0]['Title']
				movieData['EpisodeID']= result[0]['EpisodeID'].upcase
				movieData['Season']= result[0]['EpisodeID'].match(/s[\d]+/i)[0].reverse.chop.reverse.to_i
				movieData['EpisodeName']= result[0]['EpisodeName']
				movieData['tvdbSeriesID']= result[0]['tvdbSeriesID']
				movieData['imdbID']= result[0]['imdbID'] if result[0].has_key?('imdbID')
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
			fpath = movieData['Path'] #FIXME  Just use movieData['Path'] everywhere instead of fpath

			#remove any sourceDirs from fpath
			$MEDIA_SOURCES_DIR.each {|sourceDir|
				if fpath.downcase.index( sourceDir.downcase )
					fpath=fpath.slice( fpath.downcase.index(sourceDir.downcase), fpath.length)
				end
			}
			filename=pathToArray fpath


			#Extract 'words' from filename, one at a time, and search for them.
			queue=filename[1].gsub('.', ' ').gsub('_', ' ')
			done=FALSE;
			i=0
			searchTerm=[]
			loop do  #FIXME Can't this be optimized any further?
				searchTerm[i] ||= ''
				ignore=FALSE
				break if queue.empty?
				#break if searchTerm[i-1].nil?
				break if queue.match(/[\w']*\b/i).nil?
				searchTerm[i]=match= queue.match(/[\w']*\b/i); match=match[0]
				unless searchTerm[i][0].match(/s[\d]+e[\d]+/i)    #Dont add the episode tag to the search string
					searchTerm[i]=searchTerm[i][0] 
					searchTerm[i] = "#{searchTerm[i-1]} " << searchTerm[i] unless i==0
				end
				queue= queue.slice( queue.index(match)+match.length, queue.length ).strip 
				ignore=TRUE if searchTerm[i].length < 3 or searchTerm[i].downcase=='the' or searchTerm[i].downcase=='and'

				i=i+1 unless ignore
			end
			#searchTerm is now an array of search terms
			#search for each, and store the results.
			searchTerm=searchTerm.delete_if {|it| TRUE if it.empty? }
			results={}
			if source==:tvdb
				searchTerm.each_index {|i|
					temp=[]
					results[searchTerm[i]]||=[]
					temp= MediaManager::MM_TVDB.searchTVDB( searchTerm[i] )
					break if temp.length == 0
					results[searchTerm[i]]= temp
				}
			else
				searchTerm.each_index{|i|
					temp=[]
					results[searchTerm[i]]||=[]
					temp= MediaManager::MM_IMDB.searchIMDB( searchTerm[i] )
					break if temp.length == 0
					results[searchTerm[i]]= temp
				}
			end
			$results = results
			#pp results
			occurance={}
			#Try and pick a few top results
			#Present results to user, have user pick
			results.each_key {|searchWord|
				#For each result returned for each search, increase the popularity counter for that series
				results[searchWord].each {|result|
					occurance[result['tvdbSeriesID']] ||=0
					occurance[result['tvdbSeriesID']]=occurance[result['tvdbSeriesID']]+1
				}
			}
			series={}
			results.each {|listOfSeries|
				listOfSeries[1].each {|seriesHash|
					unless series.has_key? seriesHash['tvdbSeriesID']
						series.merge!({ seriesHash['tvdbSeriesID'] => seriesHash })
					end
				}
			}
			occurance=occurance.sort {|a,b| a[1]<=>b[1]}.reverse
			#No longer have to use results array, can use series.
			matches=[]
			if (epID=movieData['EpisodeID'].match(/s[\d]+/i)) and (epNum=movieData['EpisodeID'].match(/[\d]+$/))
				epID=epID[0].reverse.chop.reverse.to_i
				epNum=epNum[0]
			end
			name=filename[1].gsub('.', ' ').gsub('_', ' ').gsub(/s[\d]+e[\d]+/i, '').gsub(/\dx\d\d/i, '')
			series.each {|seriesHash|
				unless seriesHash[1]['EpisodeList'].empty?
					seriesHash[1]['EpisodeList'].each {|episode|
						episode.merge!({ 
							'Title' => seriesHash[1]['Title'][0],
							'tvdbSeriesID' => seriesHash[1]['tvdbSeriesID'][0] 
						})
						episode.merge!({ 'imdbID' => seriesHash[1]['imdbID'][0] }) if seriesHash[1].has_key?('imdbID')
						epName=episode['EpisodeName']     #For convenience
						#If the episode name begins with 'the', strip it to ease matching.
						#Required to match files that were named without 'the' at the beginning of the name
						epName=epName.gsub(/^the[\s]+/i, '') if epName.index(/^the[\s]+/i)
						
=begin
#FIXME Need to also match EpisodeID tags in the form of 1x08, and hopefully, 108
#TODO Moving me to the bottom of this nested loop will assure that I'm only run if there are no other matches!
#TODO This section should match even if the name does not match the filename, but it should issue a warning that the only thing that indicates this name is the EpisodeID tag
#TODO Remember to use the variable we have stored the EpisodeID tag in, because it is stripped from name
						#If we already have the EpisodeID tag then we can look for that instead of trying to match the name.
						#Note, cannot account for filename giving inaccurate EpisodeID tag, simply will not match
						#This match still in development, not useful yet due to the high chance of being given a false positive EpisodeID tag
						if epID and epNum and occurance[0][0][0]==seriesHash[0][0] 
							_epID=episode['EpisodeID'].match(/s[\d]+/i)[0].reverse.chop.reverse.to_i
							_epNum=episode['EpisodeID'].match(/[\d]+$/)[0]
							#printf "epID: #{epID}  _epID: #{_epID}  epNum: #{epNum}  _epNum: #{_epNum}      "
							if epID==_epID and epNum==_epNum
								puts "Match based on epID and epNum extracted from filename!"
								matches << episode
								next
							end
						end
=end
						if name.match(Regexp.new(epName, TRUE))   #Basic name match
							matches << episode
							next
						elsif name.include?("'")    #If the name includes as "'' then strip it out, it only makes trouble
							if name.gsub("'", '').match(Regexp.new( epName, TRUE))
								matches << episode
								next
							end
						elsif epName.include?("'")
							if name.match(Regexp.new(epName.gsub("'", ''), TRUE))
								matches << episode
								next
							end
						elsif epName.include?(",")
							if name.match(Regexp.new(epName.gsub(",",''), TRUE))
								matches << episode
								next
							end
						elsif epName.include?('.')
							if name.match(Regexp.new(epName.gsub('.', ''), TRUE))
								matches << episode
								next
							end
						elsif name.include?('.')
							if name.gsub('.', '').match(Regexp.new(epName, TRUE))
								matches << episode
								next
							end
						end

						#Some episodes have apostrophies in the episode name which aren't in the filename, causing a non-match
						#If the first basic match didn't work, strip apostrophies and try again.

						if epName.index(/\([\d]+\)/)
							next unless name.match(/\(.*[\d]+.*\)/)    #No need to process this if the filename has no ([\d]+.*) in it
							epName=episode['EpisodeName'].gsub(/[:;]/, '')
#							puts epName.slice( 0,epName.index(/\([\d]+\)/) )
#							puts epName.slice( (epName.index(/\([\d]+\)/) + epName.match(/\([\d]+\)/)[0].length),epName.length )
							part2= epName.slice( epName.index(/\([\d]+\)/)+epName.match(/\([\d]+\)/)[0].length,epName.length ).downcase
							regex1= Regexp.new( epName.slice( 0,epName.index(/\([\d]+\)/) ).downcase)
							regex2= Regexp.new( part2 )
							unless part2.empty?   #If there are strings on both side of the digit, use that.  Otherwise, attempt to use the [\d] provided
								if name.downcase.match(regex1) and name.downcase.match(regex2)
									matches << episode
									next
								end
							end
							#Should only get here if the string following ([\d]) is empty						
							#Use the first digit in the ( ) as the part number if it matches.
							regex2= Regexp.new( epName.match(/\([\d]+\)/)[0].chop.reverse.chop.reverse )
							if part=name.match(/\(.*[\d]+.*\)/)    #If the filename has ([\d]) in it
								part=part[0].match(/[\d]+/)[0]
								if part.match(regex2)  #Match
									matches << episode
									next
								end
							end
						end
						
						#Attempt to deal with Roman Numerals
						#The following regex was adapted from Example 7.8 of http://thehazeltree.org/diveintopython/7.html
						numeralMatch=/\s[M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})]+\s/
						romMatch= (((name.reverse) + ' ').reverse) + ' ' # This allows us to use whitespace as delimiters for either side of a RN (Roman Numeral)
						epName= ((epName + ' ').reverse + ' ').reverse
						if epName.match(numeralMatch) or romMatch.match(numeralMatch)
							#NOTE To the reader
							#This is my attempt at identifying a roman numeral in the filename
							#and converting it to an integer for comparison with the digit
							#in the episode name.  I whole heartedly believe there ^is^ a 
							#better way to do this that I haven't found yet.
							#NOTE We do not anticipate more than one Roman Numeral in the filename.
							#printf "Episode name: "; puts epName
							#printf "Filename: "; puts romMatch
							if romMatch.match( numeralMatch )
								#puts "Roman numeral found in filename, it is printed on the following line."
								#pp romMatch.match(numeralMatch)[0].strip
								romMatch=romMatch.gsub(Regexp.new(romMatch.match(numeralMatch)[0]), 
									"#{toArabic( romMatch.match(numeralMatch)[0].strip ).to_s} " ) unless toArabic(romMatch.match(numeralMatch)[0].strip)==0
								if epName.match(Regexp.new(romMatch, TRUE))
									matches << episode
									next
								end
							elsif epName.match(numeralMatch)
								#puts "Roman numeral found in episode name, it is printed on the following line."
								#printf "Matching: "; pp epName.match(numeralMatch)[0].strip
								#printf "Replacing with: "; pp toArabic(epName.match(numeralMatch)[0].strip).to_s
								epName=epName.gsub(Regexp.new(epName.match(numeralMatch)[0]), 
									" #{toArabic(epName.match(numeralMatch)[0].strip).to_s} " ) unless toArabic(epName.match(numeralMatch)[0].strip)==0
								#puts romMatch
								if romMatch.match(Regexp.new(epName, TRUE))
									#puts "Yay, matched."
									matches << episode
									next
								end
							end
						end


						if epName.index(':') #May be split into parts, try and match each side of the :
							epName=episode['EpisodeName'].gsub(/\([\d]+\)/, '')   #Strip out any () parts
							regex1= Regexp.new( epName.slice(0,epName.index(':')).downcase )
							regex2= Regexp.new( epName.slice(epName.index(':')+1,epName.length).downcase )

							if name.downcase.match(regex1) and name.downcase.match(regex2)
								matches << episode
								puts "Dis one has : in it!"; pp episode
								next
							end
						end
						
						#If an epName has 'a.k.a.' in it, check either side.  Just like any other delimiter
						if epName.index('a.k.a.')
							#For the purposes of matching the 'a.k.a.' it appears necessary to strip out parenthesis
							#from the epName, Regexp throws an error if it encounters unmatched parenthesis
							epName=epName.gsub('(', '').gsub(')', '')
							firstPart= epName.slice( 0,epName.index('a.k.a.')-1 )
							lastPart= epName.slice( epName.index('a.k.a.')+ 'a.k.a.'.length, epName.length)
							if name.match(Regexp.new(firstPart, TRUE))
								puts "Matched the first part of the name, up to 'a.k.a.'."
								matches << episode
								next
							elsif name.match(Regexp.new(lastPart, TRUE))
								puts "Matched the last part of the name, after the 'a.k.a.'."
								matches << episode
								next
							end
						end

						#Here I am trying to look for the epName in name the same way that I would as a human
						#I think the way to do this is to break the string into words, and look for a single 
						#character from the beginning and end of each respective word in epName and try
						#match those beginnings and ends of words to beginnings and ends of words in name.
						#This can be further refined by looking for characters that stand out, like 't' or 'g'
						#as opposed to ones that don't like 'a' or 'c'.  Looking for characters that stand out 
						#in name that aren't in epName can accomplish this.  This may be further refined without 
						#updating this little blurb.i
						#Note: Admittedly, this cannot catch spelling mistakes at the beginning or end of a word.
						if name.gsub('-', ' ').gsub('_', ' ').gsub('.', ' ').split(' ').length > 2
							epName=epName.strip
							distance=3
							epNameResult=[]

							epNameAr=[]
							nameAr=[]
							epName.split(' ').each {|word|
								epNameAr << word unless word.length <= 2
							}
							
							name.gsub('-', ' ').gsub('_', ' ').gsub('.', ' ').split(' ').each {|word|
								nameAr << word unless word.length <= 2
							}
							epNameAr.each_index {|epNameI|
								nameAr.each_index { |nameI|
									if epNameAr[epNameI].slice(0,1)==nameAr[nameI].slice(0,1) and
											epNameAr[epNameI].slice(epNameAr[epNameI].length-1, 1)==nameAr[nameI].slice(nameAr[nameI].length-1, 1)

										epNameResult[epNameI]=TRUE
									else
										epNameResult[epNameI]=FALSE
									end
								}
							}
							#matched
							epNameResult= epNameResult.delete_if {|wordMatched| wordMatched == FALSE}
							if epNameResult.length == nameAr.length
								puts "Matched based on blind comparison of characters at word boundaries, accurate?"
								matches << episode
								next
							end
						end

						#Convert integer to word and try to match
						if name.match(/\d+/)
							longName=name.gsub(name.match(/\d+/)[0], Linguistics::EN.numwords(name.match(/\d+/)[0]))
							if longName.match(Regexp.new(epName, TRUE))
								puts "Matched after converting the number to a word, no space."
								matches << episode
								next
							end

							longName=name.gsub(name.match(/\d+/)[0], " #{Linguistics::EN.numwords(name.match(/\d+/)[0])} ")
							if longName.match(Regexp.new(epName, TRUE))
								puts "Matched after converting the number to a word, with space."
								matches << episode
								next
							end
						end
						
						#Next before here if already matched
						#
					}
				end
			}

			return matches if matches.length==1

#			pp matches
#			puts "Path is : " ; printf movieData['Path']

			puts "No Results...?"  if matches.length < 1
			raise "FAIL! Did not get " if matches.length < 1

			pp matches if matches.length > 1
			puts "Oh wow!  More than one match!  Guess theres a first for everything.  Better code a contingency for this..." if matches.length > 1

			return matches
		end

		

	end
end
