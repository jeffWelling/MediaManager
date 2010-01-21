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
			require 'fileutils'
			require 'ftools'
			require 'pp'
			require 'xmlsimple'
			require 'erb'
			require 'open-uri'
			require 'linguistics'
		rescue LoadError => e
			case
				when e.to_s.match(/mysql/i)
					puts "Check that you have libmysql-ruby installed."
				when e.to_s.match(/rubygems/i)
					puts "Check that you have rubygems installed."
				when e.to_s.match(/mechanize/i)
					puts "Check that you have libwww-mechanize-ruby installed."
				when e.to_s.match(/dbi/i)
					puts "Check that you have libdbi-ruby installed."
				when e.to_s.match(/xmlsimple/i)
					puts "Check that you have the xml-simple rubygem or the libxml-simple-ruby package installed."
				when e.to_s.match(/linguistics/i)
					puts "Check that you have the Linguistics rubygem installed."
				else
					puts "#{e.to_s.capitalize}.\nDo you have the appropriate ruby module installed?"
			end
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
		def agent(timeout=300)
			a = WWW::Mechanize.new
			a.read_timeout = timeout if timeout
			a.user_agent_alias= 'Mac Safari'
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
			 	(answer=default if answer==:nil) unless default.nil?
				break if options.member? answer
			}
			answer
		end
		#/credits ct 

		def self.hashToArray(hash)
			raise "hashToArray(): You fucking idiot" unless hash.class==Hash
			array=[]
			hash.each {|key,value|
				array << [key.to_s,value.to_s]
			}
			return array
		end
		def self.arrayToHash(array)
			raise "arrayToHash(): You fucking idiot" unless array.class==Array
			hash={}
			array.each {|hash_element|
				p1=hash_element[0]
				p2=hash_element[1]
				raise "arrayToHash(): If I could, I would reach out of this monitor and beat you with your keyboard.  RTFM" unless hash_element.class==Array and hash_element.length==2
				raise "arrayToHash(): Your just hopeless.  Go pitch a tent in your backyard. Go on, go." unless hash_element[0].class==String
				if hash_element[0].match(/^\d+$/)
					p1=hash_element[0].to_i
				end

				if hash_element[1].match(/^\d+$/)
					p2=hash_element[1].to_i
				elsif hash_element[1].match(/^false$/i)
					p2=false
				end

				hash.merge!(p1=>p2)
			}
			return hash
		end

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

			#Instantiate MySQL Connection
			begin
				$dbh =  DBI.connect("DBI:Mysql:#{$MMCONF_MYSQL_DBASE}:#{$MMCONF_MYSQL_HOST}", $MMCONF_MYSQL_USER, $MMCONF_MYSQL_PASS)
			rescue Mysql::Error => e
				puts "Mysql sanity check: FAILED"
				puts "Error code: #{e.errno}"
				puts "Error message: #{e.error}"
				puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
				sanity=:InSaNe!
			rescue DBI::InterfaceError => e
				if e.to_s.match(/could not load driver/i)
					puts "sanity_check(): Check that you have libdbd-mysql-ruby installed."
					puts "Error if fatal, terminating."
					exit
				end
			rescue DBI::DatabaseError => e
				if e.to_s.match(/can't connect to mysql/i)
					pp e
					puts "sanity_check(): Cannot connect to mysql, check configurations. (Install ruby1.8-dev and )\n#{e.to_s}"
					raise "fail"
				end
				puts e.to_s
				sanity=nil
			ensure
				($dbh.disconnect if $dbh.connected?) unless $dbh.nil?
			end

      #PHP is installed and useable
      #FIXME  Check for curl
      php=`php -r "print('sane');"`
			if php.empty?
				puts "sanity_check(): Omg, you need to install php4-cli or equivilent package."
				raise
			end
      sanity=php.to_sym if sanity==:sane

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
			return( [ fPath.match(/\..{3,4}$/)[0] , fPath.gsub(/\..{3,4}$/, '') ] ) unless fPath.include?('/')
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
				sqlString << key << ', ' unless (key=='DateAdded' or key=='PathSHA')
				if key=='DateAdded' or key=='PathSHA'
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
		def name_match?(str1, str2, verbose=:no)
			str1=str1.downcase.strip
			str2=str2.downcase.strip
			if str2.nil? or str2.length==0
				puts "name_match?(): arg2 is empty??" unless verbose==:no
				return FALSE
			elsif str1.nil? or str1.length==0
				puts "name_match?(): arg1 is empty??" unless verbose==:no
				return FALSE
			end

			#Extra verbose option
			puts "name_match?():  (Extra Verbose)   str1: '#{str1}'\tstr2: '#{str2}'\n" if verbose.to_s.downcase.to_sym==:extra

			if str1==str2
				puts "name_match?():  Matched one-to-one" unless verbose==:no
				return TRUE
			end
			
			if str1.match(Regexp.new(Regexp.escape(str2), TRUE))   #Basic match
				puts "name_match?():  Regexp matched str2 to str1" unless verbose==:no
				return TRUE
			end
			if str2.match(Regexp.new(Regexp.escape(str1), TRUE))   #Basic match
				puts "name_match?():  Regexp matched str1 to str2" unless verbose==:no
				return TRUE
			end

			if str1.include?("'")    #If the str1 includes as "'" then strip it out, it only makes trouble
				if str1.gsub("'", '').match(Regexp.new( Regexp.escape(str2), TRUE))
					puts "name_match?():  Regexp matched str2 to str1 sans \"'\"." unless verbose==:no
					return TRUE
				end
			end
			if str2.include?("'")
				if str1.match(Regexp.new(Regexp.escape(str2.gsub("'", '')), TRUE))
					puts "name_match?():  Regexp matched str1 to str2 sans \"'\"." unless verbose==:no
					return TRUE
				end
			end

			if str2.include?(',')
				if str1.match(Regexp.new(Regexp.escape(str2.gsub(",",'')), TRUE))
					puts "name_match?():  Regexp matched str2 to str1 sans \",\"." unless verbose==:no
					return TRUE
				end
			end
			if str1.include?(',')
				if str1.gsub(',', '').match(Regexp.new(Regexp.escape(str2), TRUE))
					puts "name_match?():  Regexp matched str1 to str2 sans \",\"." unless verbose==:no
					return TRUE
				end
			end

			if str2.include?('.')
				if str1.match(Regexp.new(Regexp.escape(str2.gsub('.', '')), TRUE))
					puts "name_match?():  Regexp matched str2 to str1 sans \".\"" unless verbose==:no
					return TRUE
				end
			end
			if str1.include?('.')
				if str2.match(Regexp.new(Regexp.escape(str1.gsub('.', '')), TRUE))
					puts "name_match?():  Regexp matched str1 to str2 sans \".\"." unless verbose==:no
					return TRUE
				end
			end
			
			#no match
			return FALSE
		end
		def clearFileHashCache
			puts "Clearing FileHashCache"
			sqlAddUpdate( "TRUNCATE TABLE FileHashCache" )
		end
		def	clearMediaFiles
			puts "Clearing mediaFiles"
			sqlAddUpdate( "TRUNCATE TABLE mediaFiles" )
		end
		def clearTvdb_Series
			puts "Clearing tvdb_Series"
			sqlAddUpdate( "TRUNCATE TABLE Tvdb_Series" )
		end
		def clearTvdb_Episodes
			puts "Clearing Tvdb_Episodes"
			sqlAddUpdate( "TRUNCATE TABLE Tvdb_Episodes" )
		end
		def	clearTvdb_lastupdated
			puts "Clearing Tvdb_lastupdated"
			sqlAddUpdate( "TRUNCATE TABLE Tvdb_lastupdated" )
		end
		def clearTvdbSeriesEpisodeCache
			puts "Clearing TvdbSeriesEpisodeCache"
			sqlAddUpdate( "TRUNCATE TABLE TvdbSeriesEpisodeCache" )
		end
		def clearEpisodeCache
			puts "Clearing EpisodeCache"
			sqlAddUpdate( "TRUNCATE TABLE EpisodeCache" )
		end
		def clearTvdbSearchCache
			puts "Clearing Tvdb_Search_Cache"
			sqlAddUpdate( "DELETE FROM Tvdb_Search_Cache" )
		end
		def clearAll
			puts "Your a fucking retard.  If you used this function, you ^have^ done something wrong.  Go read the documentation before doing this again you R-Tard."
			clearFileHashCache
			clearMediaFiles
			clearTvdb_Series
			clearTvdb_Episodes
			clearTvdb_lastupdated
			clearTvdbSeriesEpisodeCache
			clearEpisodeCache
		end
		def clearTvdbCache
			clearTvdb_Series
			clearTvdb_Episodes
			clearTvdb_lastupdated
		end
		#extract search terms from string.  excludes must be an array of strings that you do not want to appear in the searchTerms, they must be lowercase
		def getSearchTerms string, excludes=nil
			raise "getSearchTerms():  Only takes strings" unless string.class==String
			raise "getSearchTerms():  second argument must be nil or an array of strings to exclude from the search terms" unless excludes.nil? or excludes.class==Array
			return [] if string.strip.empty?

			i=0
			searchTerms=[]
			filename=string.split('/')
			file_extention=string.match(/\..{3,4}$/)[0]
			filename.each_index {|filename_index|

				#This implements the sliding window
				window=filename[filename_index].gsub(/(\.|_)/, ' ')
				until window.strip.empty?

					queue=window
					ignore=FALSE
					loop do
						searchTerms[i]||=''
						ignore=FALSE
						break if queue.empty? or queue.match(/[\w']*\b/i).nil?
						
						searchTerms[i]=match=queue.match(/[\w']*\b/i)
						match=match[0]
						if MediaManager::RetrieveMeta.getEpisodeID(searchTerms[i][0]).nil? and !excludes.include?(match) and !excludes.include?(match.downcase)
							searchTerms[i]=searchTerms[i][0]
							searchTerms[i]= "#{searchTerms[i-1]} " << searchTerms[i] unless i==0
						else
							searchTerms[i]=''
						end
						queue=queue.slice( queue.index(match)+match.length, queue.length ).strip
						i+=1 #unless searchTerms[i].strip.empty?
					end
					i+=1 #unless searchTerms[i].strip.empty?
					break if window.match(/^[\w']*\b/i).nil?
					window=window.gsub(/^[\w']*\b/i, '').strip
				end
			}

			searchTerms=searchTerms.delete_if {|search_term| TRUE if (search_term.nil? or name_match?( search_term,file_extention,:no ) or search_term.strip.length <= 3)}.each_index {|line_number| searchTerms[line_number]=searchTerms[line_number].strip}

			unless excludes.nil?
				searchTerms=searchTerms.delete_if {|search_term| TRUE if excludes.include?(search_term)}
			end
			searchTerms
		end
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
					part2= str2_sans_stuff.slice( str2_sans_stuff.index(/\([\d]+\)/)+str2_sans_stuff.match(/\([\d]+\)/)[0].length,str2_sans_stuff.length ).downcase.strip
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

		
	end #MMCommon
end
