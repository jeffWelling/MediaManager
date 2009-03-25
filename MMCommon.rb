module MediaManager
	module MMCommon
		begin
			require 'mysql'
			require 'digest/sha1'
			require 'rubygems'
			require 'mechanize'
			require 'dbi'
#			require 'amatch'    #For checking for spelling errors
	 		require 'find'
		rescue LoadError => e
			puts "#{e.to_s.capitalize}.\nDo you have the appropriate ruby module installed?"
			puts "Error is fatal, terminating."
			exit
		end
		
		#With credits to ct / kelora.org	
		def symbolize text
      return :nil if text.nil?
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
      answer = STDIN.gets.strip.downcase
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
		def prompt question, default = :yes, add_options = nil, delete_options = nil
			options = ([default] + [:yes,:no] + [add_options] + [:quit]).flatten.uniq
			if delete_options.class == Array
				delete_options.each {|del_option|
				options -= [del_option]
				}
			else
				options -= [delete_options]
			end
			option_string = options.collect {|x| x.to_s.capitalize}.join('/')
			answer = nil
			loop {
				answer = MediaManager.ask_symbol "#{question} (#{option_string.gsub('//', '/')}):", default
			 	answer=default if answer==:nil
				break if options.member? answer
			}
			answer
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
			begin
				$dbh =  DBI.connect("DBI:Mysql:#{$MMCONF_MYSQL_DBASE}:#{$MMCONF_MYSQL_HOST}", $MMCONF_MYSQL_USER, $MMCONF_MYSQL_PASS)
			rescue Mysql::Error => e
				puts "Mysql sanity check: FAILED"
				puts "Error code: #{e.errno}"
				puts "Error message: #{e.error}"
				puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
				sanity=:InSaNe!
			rescue DBI::DatabaseError => e
				puts e.to_s
				sanity=nil
			ensure
				$dbh.disconnect if $dbh.connected?
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
		#FIXME Is this even used anywhere??
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
				sqlString << key << ', ' unless key=='DateAdded'
				if key=='DateAdded'
					#values << "NOW(),"
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
		#FIXME Is this even used anywhere???
		def categorize movieInfo
			answer=ask("Categorization?:")
			movieInfo['Categorization']=answer
			return movieInfo
		end

		#Make a symlink to the file in the Library
 		def makeSymLink movieInfo
			return if movieInfo['Categorization'].empty?
			puts "Making link in Library!"
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

		def pp_movieInfo movieInfo
			peopleFriendly=movieInfo
			peopleFriendly['DateAdded']=movieInfo['DateAdded'].to_s
			peopleFriendly['DateModified']=movieInfo['DateModified'].to_s
			pp peopleFriendly
		end

		#name_match?(name, epName) searches for epName in name and returns true if found
		#Return true if they match, return false if they do not
		#If they do not match as is, try stripping various special characters
		#such as "'", ",", and ".". 
		def name_match?(name, epName)
			if epName.nil? or epName.length==0 
				puts "name_match?(): blank episode name?"
				return FALSE
			end 
			epName=Regexp.escape(epName)
			if name.match(Regexp.new(Regexp.escape(epName), TRUE))   #Basic name match
				return TRUE
			elsif name.include?("'")    #If the name includes as "'' then strip it out, it only makes trouble
				if name.gsub("'", '').match(Regexp.new( Regexp.escape(epName), TRUE))
					return TRUE
				end
			elsif epName.include?("'")
				if name.match(Regexp.new(Regexp.escape(epName.gsub("'", '')), TRUE))
					return TRUE
				end
			elsif epName.include?(",")
				if name.match(Regexp.new(Regexp.escape(epName.gsub(",",'')), TRUE))
					return TRUE
				end
			elsif name.include?(',')
				if name.gsub(',', '').match(Regexp.new(Regexp.escape(epName), TRUE))
					return TRUE
				end
			elsif epName.include?('.')
				if name.match(Regexp.new(Regexp.escape(epName.gsub('.', '')), TRUE))
					return TRUE
				end
			elsif name.include?('.')
				if name.gsub('.', '').match(Regexp.new(Regexp.escape(epName), TRUE))
					return TRUE
				end
			end
			return FALSE
		end

	end #MMCommon
end
