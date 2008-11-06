module MediaManager
	module MMCommon
		#With credits to ct / kelora.org	
		require 'rubygems'
	 	require 'find'
		def symbolize text
      raise "symbolize nil" if text.nil?
      return :empty if text.empty?
      return :quit if text =~ /^(q|quit)$/i
      return :edit if text =~ /^(e|edit)$/i
      return :yes  if text =~ /^(y|yes)$/i
      return :no   if text =~ /^(n|no)$/i
      text.to_sym
    end 
    def ask question
      print "\n#{question} "
      answer = gets.chomp
      throw :quit if 'q' == answer
      answer
    end 
    def ask_symbol question, default
      answer = symbolize ask(question)
      throw :quit if :quit == answer
      return default if :empty == answer
      answer
    end

		require 'mechanize'
    def agent
      a = WWW::Mechanize.new
      a.read_timeout = 5 
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
				end
				exit #Cannot continue if cannot read config (and not asking)
			rescue SyntaxError => e
				puts "Your config file has syntax errors.\nGo read Why's Poignant Guide to Ruby, get a clue, and try again."
				puts e.inspect
				exit
			end
			return TRUE
    end

    def resetDir
      FileUtils.cd($MEDIA_CONFIG_DIR)
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

      #PHP is installed and useable
      #FIXME  Check for curl
      sanity=`php -r "print('sane');"`.to_sym

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

	  def filenameToInfo(filename, seperated=nil)   #FIXME  Handle seperated
	    movieData={}
			#Can't process escaped slashes yet, attempting to may cause inexplicable behaviour.
			if filename.index('//') || filename.index('\/')
	      raise "Not yet able to process files with '//' or escaped slashes such as '\/'.\n"
				return :fail
	    end 

			#seperated into two lines so that is_movie? is run once not twice
			it=is_movie?(filename, seperated)
	    if it != FALSE then movieData = it end
	
	   #FIXME  Continue from here 
	  end 

		#This function does its  best to decide if the file passed to it is a movie or not
		def is_movie?(fp, seperated=nil)
			#Return False unless is movie, then
			# return array of movie data
	
		  #Store the results from each assesment attempt
		  #for reference and recalculation at end of function
		  answers =[]
	
			#split the path to make it searchable, but retain full path
			#file_path is array of the seperated names of each parent folder
			file_path=fp.split('/')
			counter=0
	
			#0.
			#Does the path contain 'movie' in it?
			file_path.each do |filepath_segment|
				if filepath_segment.downcase.index("movie")
					answers[0]= "TRUE"
				else
					answers[0] ||= nil
				end
			end
	
			#1.
			#Does the path also contain 'tv' or 'television' in it?
			file_path.each do |filepath_segment|
				if filepath_segment.downcase.index("tv")
					answers[1]= "tv"
				elsif filepath_segment.downcase.index("television")
					answers[1]= "television"
				else
					answers[1] ||= nil
				end
			end
	
			#2.
			#What size is it? (in bytes)    >= 650 = movie
			answers[2]= File.size?(fp)
			if answers[2]==nil
				print "Warning: File doesn't exist, or has zero size? #{fp}"
			end
	
			#3.
			#Is it in VIDEO_TS format?
			fp.index("VIDEO_TS") != nil ? answers[3]=TRUE : answers[3]=FALSE
	
			#4.Is it in the IMDB database? 
			#
			

			puts fp
			answers

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

	end #MMCommon
end
