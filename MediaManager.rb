#!/usr/bin/ruby
#Read configuration file

#For testing purposes, the home directory must be dynamically determined
#to allow for testing to be done on Apple computers who's users' home dirs
#are in /Users/
$mmconfig = "#{`cd ~;pwd`.chomp}/Documents/Projects/MediaManager/MediaManager.cfg"
raise "Cannot read config file!!!" unless load $mmconfig

#Initialize the cache and blacklist arrays
$TVDB_CACHE={}
$IMDB_CACHE={}
$IMDB_BLACKLIST=[]

#This is so that we can require files in the same directory without the .rb extention.
$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

load 'MM_TVDB.rb'
load 'MM_IMDB.rb'
load 'movieInfo_Specification.rb'

module MediaManager
  extend MMCommon
  def self.import numFiles=:nil
	  begin
			raise "Sanity check fail!" unless sanity_check==:sane
			puts "Indexing files in #{$MEDIA_SOURCES_DIR},\n"
			puts "This may take some time.\n"
			biglist = []
			$MEDIA_SOURCES_DIR.each do |source_dir| #For each source directory
			Find.find(source_dir) do |fullFileName| #For each file in this source directory
				return if numFiles==0
				ignore=FALSE
				seperated=nil
				mediaInfo={}

				print '.'
				$MEDIA_CONF_IGNORES.each_key do |ignore_pattern|
					ignore=TRUE if fullFileName.downcase.index(ignore_pattern.downcase)
				end

				#Is directory?
				begin
					FileUtils.cd(fullFileName)
					if isRAR? fullFileName
						isRar=:yes
					else
						ignore=TRUE
					end
				rescue Errno::ENOENT
					unless File.symlink?(fullFilename) then
						raise $!
					else
						puts "Broken symlink found at #{fullFileName}"
					end
				rescue Errno::ENOTDIR #Isn't a dir.  Continue.
				end

				if ignore==TRUE
					#Don't count files not processed towards the total count
					#unless numFiles==:nil then
					#	unless ignore==TRUE  then numFiles=numFiles-1 end
					#end
					next
				end

				movieInfo=$movieInfoSpec.clone
				movieInfo= filenameToInfo fullFileName

				#See if this file has already had metadata stored
				sqlresult=[]
				sqlresult=sqlSearch( "SELECT * FROM mediaFiles WHERE PathSHA = '#{hash_filename movieInfo['Path']}'" )
				movieInfo=sqlresult[0] unless sqlresult.empty?

				if (answr=ask( "#{movieInfo.inspect}\nSubmit?[Yes]" ))=='no'||answr=='n'||answr=='e'||answr=='edit'
					movieInfo=userCorrect movieInfo
				elsif answr=='skip'||answr=='drop'||answr=='d'||answr=='s' 
					#User says drop the file
					ignore=TRUE
				elsif answr=='quit' || answr=='exit' || answr=='bye'
					throw :quit
				end

				if ignore==TRUE
					#Don't count files not processed towards the total count
					#unless numFiles==:nil then
					#	unless ignore==TRUE  then numFiles=numFiles-1 end
					#end
					next
				end

				#Add to Mysql
				sqlAddInfo(movieInfo) unless movieInfo.include? 'id'
				sqlUpdateInfo(movieInfo) unless movieInfo.include?('id')!=TRUE

				
					
				#Create symlink in Library for consolidation
				makeSymLink movieInfo

				numFiles=numFiles-1 unless !numFiles.respond_to? '-'
				
			end # End of finding all files in source_dir
			end #end $MEDIA_SOURCES_DIR.each

			puts "Done.\n"
		ensure #Always disconnect from database
		#$dbh.disconnect if $dbh
    end
  end #import

	#This function is called by the user to create the Library tree of symlinks to all of the movies
	def createLibrary
		#files=
	end

	#This function recieves a search term from the user, a name, id number, or identifiable string
	#and if that term is ambiguous for the database, it asks the user for clarification
	# and if it is identifiable it begins playing that file to the requested host
	def play searchTerm, target=nil
		
		


	end

end

