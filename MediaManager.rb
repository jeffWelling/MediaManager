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
load 'RetrieveMeta.rb'
load 'movieInfo_Specification.rb'

module MediaManager
  extend MMCommon

	#scan_media scans for recognizable formats, attempts get metadata for each result, and stores the results in mediaFiles SQL Table
	#verbose speaks for itself
	#scanDirectory is an optional argument, if a directory is given that dir will be scanned instead of the directory[ies]
	#	specified in the config file.
	#scanItemLimit is the maximum number of files to scan, this number only includes files with recognized extentions.  
	#	The default of zero indicates no limit.
	#updateDuplicates? is used to specify wether you wish to update the metainfo for duplicate files, or simply ignore them.
	#	When a recognized file is found, the file is hashed and the database is searched for the hash.  If a match is found, this
	#	indicates that the file has been processed before and may be a duplicate.  If this happens, the program looks at the location
	#	the file was thought to be in previously, if it is not there for any reason the database is silently updated.  If it does exist
	#	then this option specifies what to do, update the database with the new location or use the old location.
	def self.scan_media( verbose=FALSE, scanDirectory=nil, scanItemLimit=0, updateDuplicates= :yes )
		catch :quit do
			raise "Sanity check failed!" unless sanity_check==:sane

			sourcesArray=$MEDIA_SOURCES_DIR
			sourcesArray=[scanDirectory] if scanDirectory

			puts "Scanning source directories:"
			puts "This may take a moment..."
			puts "{ skipped = '.', mediafile = '+' }\n" if verbose
			files=[]
			scannedItems=0
			sourcesArray.each { |sourceDir|
				Find.find(sourceDir) { |filePath|
					break if scannedItems >= scanItemLimit unless scanItemLimit==0
					acceptable=FALSE
					$MEDIA_RECOGNIZED_FORMATS.each { |goodExtention|
						#If the last 4 chars from filePath are a recognized good extention,,,
						if filePath.reverse.slice(0,4).reverse.match(Regexp.new(goodExtention))
							acceptable=TRUE
						end
					}
					if acceptable
						files << filePath
						printf('+') if verbose
						scannedItems=scannedItems+1
					else
						printf('.') if verbose
					end
				}
			} 
			
			files.each_index { |filesP|
				ignore=FALSE
				movieInfo=MediaManager::RetrieveMeta.filenameToInfo files[filesP]
				#pp_movieInfo movieInfo
				
				#If its a duplicate
				if movieInfo.has_key?('id')==true
					if movieInfo['Path']==files[filesP] and updateDuplicates != :yes
						puts "Silently skipping..."
						next
					end
					s="Duplicate found, OMG THINK OF SOME OPTIONS FOR HERE!"
					raise s
					#case MediaManager.prompt(s, :)
					#	when 
				end
			
				pp_movieInfo movieInfo	
				answer= MediaManager.prompt("Is this correct?", :yes, [:edit, :skip, :drop] )
				if answer==:no||answer==:edit
					movieInfo=userCorrect movieInfo
				elsif answer==:skip||answer==:drop
					(answer==:skip) ? (puts "Skipping file...") : (puts "Dropped.  Continuing...")
					ignore=TRUE
				end

				next if ignore
				
				#Add to Mysql
				sqlAddInfo(movieInfo) unless movieInfo.include? 'id'
				sqlUpdateInfo(movieInfo) unless movieInfo.include?('id')!=TRUE

			}
			
			
		end #catch :quit
	end

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

MediaManager.sanity_check

