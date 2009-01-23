module MediaManager
	module MMCommon
		load 'Hasher.rb'
		begin
			require 'mysql'
			require 'digest/sha1'
			require 'rubygems'
			require 'mechanize'
			require 'dbi'
			#With credits to ct / kelora.org	
	 		require 'find'
		rescue LoadError => e
			puts "#{e.to_s.capitalize}.\nDo you have the appropriate ruby module installed?"
			puts "Error is fatal, terminating."
			exit
		end
		

		def symbolize text
      raise "symbolize nil" if text.nil?
      return :empty if text.empty?
      return :quit if text =~ /^(q|quit)$/i
      return :edit if text =~ /^(e|edit)$/i
      return :yes  if text =~ /^(y|yes)$/i
      return :no   if text =~ /^(n|no)$/i
      text.to_sym
    end 
		
		#customized, added 'default'
		#had to add 'STDIN.gets', without 'STDIN' was producing errors.
    def ask question, default=nil
      print "\n#{question} "
      answer = STDIN.gets.chomp
      throw :quit if 'q' == answer
			return default if symbolize(answer)==:empty
      answer
    end 
    def ask_symbol question, default
      answer = symbolize ask(question)
      throw :quit if :quit == answer
      return default if :empty == answer
      answer
    end
    def agent
      a = WWW::Mechanize.new
#      a.read_timeout = 5 
      a   
    end 
		#/credits ct 
	

    def reloadConfig askOnFail = :yes
      begin
				load $MEDIA_CONFIG_FILE
			rescue LoadError => e
				puts "Could not find config file...? Cannot continue without it!\n #{e.inspect}"
				if askOnFail? == :yes
					if ask_symbol("Retry loading config file? (Have you corrected the problem?)",:no) == :yes
						return reloadConfig(:no)
					else #Dont want to retry reading config
						exit
					end
				else
					exit #Cannot continue if cannot read config (and not asking for alternate location)
				end
			rescue SyntaxError => e
				puts "Your config file has syntax errors.\nGo read Why's Poignant Guide to Ruby, get a clue, and try again."
				puts e.inspect
				exit
			end
			return TRUE
    end

    def resetDir
      FileUtils.cd($MEDIA_CONFIG_DIR.chomp)
    end

		#This is to be run during sanity_check to populate the blacklist
		#It is required by the MM_IMDB file to operate properly
		def loadBlacklist
			if File.exist?($MMCONF_MOVIEDB_BLACKLIST)
				$IMDB_BLACKLIST = File.readlines($MMCONF_MOVIEDB_BLACKLIST).map {|l| l.rstrip }
			else
				FALSE
			end
		end

    def sanity_check
      MediaManager::reloadConfig :yes			#reloadConfig will exit unless successful
			sanity=:sane
      require "find"
      require "fileutils"
      require 'pp'
			

			#seperately installed component
			begin
				require 'dbi'
			rescue LoadError
				puts "Cannot load DBI database interconnect. Need to install 'libdbi-ruby'?"
				sanity=:iNsAnE!
			end

			#Instantiate MySQL Connection
			unless $dbh
				begin
					$dbh =  DBI.connect("DBI:Mysql:#{$MMCONF_MYSQL_DBASE}:#{$MMCONF_MYSQL_HOST}", $MMCONF_MYSQL_USER, $MMCONF_MYSQL_PASS)
				rescue Mysql::Error => e
					puts "Mysql sanity check: FAILED"
					puts "Error code: #{e.errno}"
					puts "Error message: #{e.error}"
					puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
					sanity=:InSaNe!
					$dbh.disconnect if $dbh.connected?
				end
			end

      #PHP is installed and useable
      #FIXME  Check for curl
      sanity=`php -r "print('sane');"`.to_sym if sanity==:sane

			#load the blacklist
			loadBlacklist

      return sanity if sanity==:sane
    end

		def gsearch query=:nil
			if query == :nil
				puts "Must call with a query string.\n"
				return
			end
		  bigstring=`php -f #{$MEDIA_CONFIG_DIR}google_api_php.php "#{query}"`

		  bigstring=bigstring.split('<level1>')

		  counter=0
		  bigstring.each do |str|
		    counter1=0
		    hsh={}
		    bigstring[counter]=str.split('<level2>')
		    bigstring[counter].each do |str2|
		      tmp= bigstring[counter][counter1].split('<:>')
		      bigstring[counter][counter1]= {tmp[0]=>tmp[1]}
		      counter1=counter1+1
		    end 
		    counter=counter+1
		  end 
		  # newstring = bigstring.split().collect {|line| line.split().collect {|word| x,y = word.split('<:>' ; { x => y } } }
		  return bigstring
		end

		#Returns info in the form of a hash conforming to movieInfo_Specification.rb
		#isRar is :yes if the filename passed is a folder containing a rared file
	  def filenameToInfo(filename, isRar=:no)
	    puts "\nWorking on #{filename}"
			movieData=$movieInfoSpec.clone
			movieData['Path']=filename

			sqlresult=sqlSearch( "SELECT * FROM mediaFiles WHERE PathSHA = '#{hash_filename movieData['Path']}'" )
			movieData=sqlresult[0] unless sqlresult.empty?
			puts "Metainformation is available based on a hash of the filename." unless sqlresult.empty?
			
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
		def extractData(movieData, isRar=:no)
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


		#This function is run on a directory to determine if it contains a split rar'ed archive
		#return true if fPath contains a rar archive, false otherwise
		def isRAR? fPath
			path=[]

			#Do not return true if the 'rar' files are more than one level deep
			#aka dont return true if there are no 'rar' files in the immediate directory

			#Find all files in that path to check them
			Dir.open(fPath).each {|file|
				path.push file unless file=='.'||file='..'
			}
			path.each_index {|arrIndx|
				path[arrIndx] = pathToArray path[arrIndx]
			}

			#one of the files should have the 'rar' extention.        One but no more than, more than one indicated devilish trickery!
			rar=nil
			path.each_index {|i|
				if path[i][0]=='.rar' && rar != nil
					raise "Directory has more than one '.rar' master file! Aborting!"
					return FALSE
				end
				unless rar then
					rar=path[i] if path[i][0]=='.rar'
				end
			}

			#Look for multiple files beginning with .r00 to .r01 and ascending
			#get a list of these files for reference
			rarParts=[]
			path.each_index {|i|
				rarParts << path[i] if path[i][0] =~ /^\.r[0-9][0-9]/ 
			}
			rarParts=rarParts.reverse

			if rar && rarParts.length > 0 
				return TRUE
			else
				return FALSE
			end
		
		end

		#take a full file path and turn it into an array, including turning the extention into the first element.
		def pathToArray fPath
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
		
		#This function returns true if the capitalization in the string argument is irregular.
		#False otherwise.
		def strangeCaps string
			string.slice( 1,string.length ).downcase == string.slice( 1,string.length)
		end

		#takes movieInfoSpec hash to be filled in by user
		def userCorrect movieInfo
			movieInfo.each_key {|key|
				movieInfo[key] = ask("#{key}?[#{movieInfo[key]}]", movieInfo[key])
			}
			return movieInfo unless ask("\n#{movieInfo.inspect}\n\nSubmit?[yes]")=='no'
			userCorrect movieInfo
		end

		def sqlAddInfo movieInfo
			values=''
			sqlString="INSERT INTO mediaFiles ("
			movieInfo.each_key {|key|
				sqlString << key << ', '
				if key=='DateAdded'
					values << "NOW(),"
					next
				end
				values << "'" << "#{Mysql.escape_string(movieInfo[key].to_s)}" << "', "
			}
			sqlString << 'PathSHA, DateAdded '
			values << "'#{hash_filename movieInfo['Path']}', NOW()  "
			
			sqlString = (sqlString.chomp(', ')) << ") VALUES (" << (values.chomp(', ')) << ');'
			sqlAddUpdate(sqlString)
			puts "SQL Info Submitted."
		end

		def sqlUpdateInfo movieInfo
			values=''
			sqlString='UPDATE mediaFiles SET '

			movieInfo.each_key {|key|
				if key=='PathSHA'
					sqlString << key << '=' << "'#{hash_filename movieInfo['Path']}', " 
					next
				elsif key=='DateModified'   #FIXME  Check MySQL database to see if it actually changed, and only then update DataModified
					sqlString << key << '=' << "NOW(),"
					next
				elsif key=='DateAdded'
					sqlString << key << '=' << "'#{movieInfo[key].to_s}',"
					next
				end
				(sqlString << key << '=' << ( movieInfo[key].nil? ? "''" : "'" << "#{Mysql.escape_string(movieInfo[key].to_s)}" << "'" )) << ', ' unless key=='id'
			}
			sqlString.chomp!(', ')

			sqlString << " WHERE FileSHA='#{movieInfo['FileSHA']}'"
			sqlAddUpdate(sqlString)
			puts "SQL Info Updated."
		end

		def sqlSearch(query)
			$dbh  =  DBI.connect("DBI:Mysql:#{$MMCONF_MYSQL_DBASE}:#{$MMCONF_MYSQL_HOST}", $MMCONF_MYSQL_USER, $MMCONF_MYSQL_PASS)
			rez = $dbh.execute query
			arry=[]
			columns=rez.column_names
			rowNum=0
			while row=rez.fetch
				count=0
				row.each {|item|
					arry[rowNum]||={}
					arry[rowNum].merge!( columns[count] => item )
					count=count+1
				}
				rowNum=rowNum+1
			end
			$dbh.disconnect if $dbh.connected?
			return arry
		end

		def sqlAddUpdate( sqlString )
			$dbh  =  DBI.connect("DBI:Mysql:#{$MMCONF_MYSQL_DBASE}:#{$MMCONF_MYSQL_HOST}", $MMCONF_MYSQL_USER, $MMCONF_MYSQL_PASS)
			r = $dbh.do sqlString
			$dbh.disconnect if $dbh.connected?
			return r
		end

		#This function requires a single ID and a host to play that file to
		def playID id, host
			
		end

		#This function sets the categorization for the file.
		#Its segregated into a function to keep it simple to update
		def categorize movieInfo
			answer=ask("Categorization?:")
			movieInfo['Categorization']=answer
			return movieInfo
		end

		#Make a symlink to the file in the Library
 		def makeSymLink movieInfo
			return if movieInfo['Categorization'].empty?
			symlink=''
			dir=''
			symlink = $MEDIA_LIBRARY_DIR.clone 
			symlink << '/' << movieInfo['Categorization'].slice( 8, movieInfo['Categorization'].length )  #up to TVShows or Movies
			symlink << '/' unless symlink.strip.reverse.index('/')==0  #Assure there is a trailing '/' at the end of Categorization 
			if movieInfo['Categorization'].split('/')[1]=='TVShows'
				symlink << movieInfo['Title'] << '/' << 'Season ' + movieInfo['Season'].to_s << '/' << movieInfo['EpisodeID'] << ' - ' << movieInfo['EpisodeName'] << movieInfo['Path'].strip.reverse.slice(0,4).reverse
			else
				symlink << movieInfo['Title'] << '/' << movieInfo['Title'] << movieInfo['Path'].reverse.slice(0,4).reverse
			end

			dir=symlink.reverse.slice( symlink.reverse.index('/'), symlink.length ).reverse 
			puts dir
			FileUtils.makedirs( dir ) unless File.exist?(dir)
			if File.exist? symlink
				File.unlink(symlink) && File.symlink( movieInfo['Path'],symlink ) unless File.readlink(symlink)==movieInfo['Path']
			else
				File.symlink( movieInfo['Path'], symlink)
			end	
		end

		#This function takes a source, either :tvdb or :imdb, and a filePath to search for within that DB
		def db_include?( source, movieData )
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
				ignore=TRUE if searchTerm[i].length < 4

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
			name=filename[1].gsub('.', ' ').gsub('_', ' ').gsub(/s[\d]+e[\d]+/i, '')
			series.each {|seriesHash|
				unless seriesHash[1]['EpisodeList'].empty?
					seriesHash[1]['EpisodeList'].each {|episode|
						episode.merge!({ 
							'Title' => seriesHash[1]['Title'][0],
							'tvdbSeriesID' => seriesHash[1]['tvdbSeriesID'][0] 
						})
						episode.merge!({ 'imdbID' => seriesHash[1]['imdbID'][0] }) if seriesHash[1].has_key?('imdbID')
						epName=episode['EpisodeName']
						if name.match(Regexp.new(epName))
							matches << episode
							break
						end						

						if epName.index(/\([\d]+\)/)
							epName=episode['EpisodeName'].gsub(/[:;]/, '')
							regex1= Regexp.new( epName.slice( 0,epName.index(/\([\d]+\)/) ))
							regex2= Regexp.new( epName.slice( epName.index(/\([\d]+\)/)+epName.match(/\([\d]+\)/)[0].length,epName.length ))
							if name.match(regex1) and name.match(regex2)
								matches << episode
								puts "Dis one has ( [\d] ) in the name!"; pp episode
								break
							end
						end

						if epName.index(':') #May be split into parts, try and match each side of the :
							epName=episode['EpisodeName'].gsub(/\([\d]+\)/, '')   #Strip out any () parts
							regex1= Regexp.new( epName.slice(0,epName.index(':')) )
							regex2= Regexp.new( epName.slice(epName.index(':')+1,epName.length) )

							if name.match(regex1) and name.match(regex2)
								matches << episode.merge
								puts "Dis one has : in it!"; pp episode
								break
							end
						end

						

						#Break before here if already matched
						#
					}
				end
			}
			raise "Oh wow!  More than one match!  Guess theres a first for everything.  Better code a contingency for this..." if matches.length != 1
			return matches
		end

	end #MMCommon
end
