#!/usr/bin/ruby
#Read configuration file

#For testing purposes, the home directory must be dynamically determined
#to allow for testing to be done on Apple computers who's users' home dirs
#are in /Users/
$mmconfig = "#{`cd ~;pwd`.chomp}/Documents/Projects/MediaManager/MediaManager.cfg"
raise "Cannot read config file!!!" unless load $mmconfig

#Initialize the cache and blacklist arrays
$TVDB_CACHE||={}
$IMDB_CACHE||={}
$IMDB_BLACKLIST=[]

#This is so that we can require files in the same directory without the .rb extention.
$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

load 'MM_TVDB.rb'
load 'MM_TVDB2.rb'
load 'MM_IMDB.rb'
load 'RetrieveMeta.rb'
load 'movieInfo_Specification.rb'
require 'ftools'

module MediaManager
  extend MMCommon
	#scan_dirs(source_dirs=nil, new_only=:no, scan_limit=0, commit_to_sql=:no)
	#source_dirs can be a string or an array to scan instead of $MEDIA_SOURCES_DIR,
	#new_only controls if scan_dirs() will include already-scanned items in it's results
	#scan_limit is zero by default which means unlimited.  Set this to the number of items you want to scan.
	#commit_to_sql is set to no by default, which if set to :yes, will insert the files into the mediaFiles database
	#  for later processing.
	def self.scan_dirs(source_dirs=nil, new_only=:no, scan_limit=0, commit_to_sql=:no)
		raise "scan_dirs(): Cannot use hashes" if source_dirs.class==Hash
		number_scanned=0
		media_files=[]

		source_dirs=$MEDIA_SOURCES_DIR if source_dirs.nil?
		source_dirs=[source_dirs] if source_dirs.class==String

		source_dirs.each {|dir_to_scan|
			Find.find(dir_to_scan) {|file_path|
				break if number_scanned >= scan_limit unless scan_limit==0
				if $MEDIA_RECOGNIZED_FORMATS.include?((extention=file_path.match(/\.[^\.]+$/)) ? extention[0] : '') #If the file extention is a recognized format
					media_files << file_path
					number_scanned+=1
				end
			}
		}

		if new_only!=:no
			media_files.delete_if {|path| !sqlSearch("SELECT id FROM mediaFiles WHERE Path='#{Mysql.escape_string path}'").empty? }
		end

		if commit_to_sql==:yes
			sql_string="INSERT INTO mediaFiles (Path, PathSHA, Size, DateAdded) VALUES "
			media_files.each {|path|
				data_set={}
				if sqlSearch("SELECT id FROM mediaFiles WHERE Path='#{Mysql.escape_string path}'").empty? or new_only!=:no
					sql_string << "('#{Mysql.escape_string path}', '#{hash_filename path}', '#{File.size path}', '#{DateTime.now.to_s}'),"
				end
			}
			
			puts "scan_dirs():  Sql'd #{sqlAddUpdate($it=sql_string.chop)} filepaths." unless 
				sql_string.gsub("INSERT INTO mediaFiles (Path, PathSHA, Size, DateAdded) VALUES ", '').empty?
		end
			
		return media_files
	end

	#same_file?() is meant to check if two files are identical, by first comparing the filesizes
	#and if those are the same, by progressively hashing the file until the hashes do not match.
	#It returns an array, whose first element is TRUE or FALSE indicating a match or not.
	#The second element of the array will be nil unless both files are the same and their full
	#hash was calculated, otherwise it will contain the hash of the full file.
	#What's different between this method and File.compare from ftools?
	#		This method will return the hash of the file if it the files match.  It calculates
	#		this value anyway, it may as well be returned to the user anyway.  Better than 
	#		re-hashing.
	def self.same_file?(file1, file2)
		puts "wtf? 1#{file1}   2#{file2}" if file1.nil? or file2.nil?
		
		raise "same_file?():  Pass me two files, I shall tell you if they are the same file by comparing a hash" unless File.exist?(file1) and File.exist?(file2)
		file1_hasher= Digest::SHA1.new
		file2_hasher= Digest::SHA1.new
	
		file1_size=File.size(file1)
		file2_size=File.size(file2)
		return [FALSE, nil] if File.size(file1)!=File.size(file2)
		open(file1, 'rb') do |file1_io|
		open(file2, 'rb') do |file2_io|
			while(!file1_io.eof and !file2_io.eof and file1_hasher.hexdigest==file2_hasher.hexdigest)
				file1_hasher.update(file1_io.readpartial(1024))
				file2_hasher.update(file2_io.readpartial(1024))
			end
		end end
		
		file1_hasher.hexdigest==file2_hasher.hexdigest ? [TRUE,file1_hasher.hexdigest] : [FALSE,nil]
	end

	def self.collect_duplicates(array_of_files, verbose=:no)
		raise "collect_duplicates():  Your supposed to pass me an array of files you silly christian." unless array_of_files.class==Array
		return {} if array_of_files.empty?
		size_of_array=array_of_files.length
		total=0
		puts "collect_duplicates():  Calculating total number of comparisons..." if verbose!=:no
		array_of_files.each_index {|index|
			total+=index
		}
		if verbose!=:no
			puts "collect_duplicates():  Processing #{total} comparisons (This is NOT the total number of files)...\n"
			puts    "0--------------------------------------------------100%"
			printf  ">"
		end
		so_far=0
		progress_update_due=total/50
		duplicates={}
		array_of_files.each_index {|first_index|
			second_index=first_index
			while (second_index<size_of_array)
				(second_index+=1 and next) if array_of_files[second_index] == array_of_files[first_index]
				so_far+=1
				if so_far > progress_update_due
					printf '-'
					progress_update_due+=total/50
				end
				pp second_index if array_of_files[second_index].nil?
				result=MediaManager.same_file?(array_of_files[first_index], array_of_files[second_index])
				if result[0].class==TrueClass
					if duplicates.has_key? result[1]
						duplicates[result[1]] << array_of_files[first_index] unless duplicates[result[1]].include?(array_of_files[first_index])
						duplicates[result[1]] << array_of_files[second_index] unless duplicates[result[1]].include?(array_of_files[second_index])
					else
						duplicates.merge!( {result[1]=>[array_of_files[first_index], array_of_files[second_index]]} )
					end
				end
				second_index+=1
			end
		}
		return duplicates
	end

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

			puts "Scanning source directories:"
			puts "This may take a moment..."
			files=[]
			files=MediaManager.scan_dirs( (scanDirectory.nil? ? nil : scanDirectory), :yes, scanItemLimit, :no) 
			
			files.each_index { |filesP|
				ignore=FALSE
				movieInfo=MediaManager::RetrieveMeta.filenameToInfo files[filesP]
				next if movieInfo==:ignore
				#pp_movieInfo movieInfo
				
				#If its a duplicate
				if movieInfo.has_key?('id')==true
					if movieInfo['Path']==files[filesP] and updateDuplicates == :yes
						puts "Silently skipping..."
						next
					end
					unless $MM_MAINT_FILE_INTEGRITY!=TRUE
						pp movieInfo['Path']
						pp files[filesP]
						s="Duplicate found and , OMG THINK OF SOME OPTIONS FOR HERE!"
						raise s
					#case MediaManager.prompt(s, :)
					#	when 
					end
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
	def self.createLibrary
		# categories = ['TVShows', 'Movies']
		entries=MediaManager.sqlSearch('SELECT * FROM mediaFiles')
		entries.each {|entry|
			if entry['Categorization'].empty?
				link_path="#{$MEDIA_LIBRARY_DIR}" << '/Library/Misc/' << File.basename(entry['Path'])
				File.makedirs link_path
				File.symlink( entry['Path'], link_path) unless File.exists? link_path
				next
				#raise "createLibrary():  Can't create link for file that has no category"
			end

			link_path="#{$MEDIA_LIBRARY_DIR}" << '/' << entry['Categorization'] << '/' << entry['Title'] << '/' << "Season #{entry['Season']}" << '/'
			
			File.makedirs link_path 
			#This part determins the symlink name's format
			link_path << entry['EpisodeID'].match(/\d+$/)[0] << ' - ' << entry['EpisodeName'] << entry['Path'].match(/\.[^\.]+?$/)[0]
			File.symlink(entry['Path'], link_path) unless File.exists? link_path
			
		}
		return TRUE
	end

	#This function recieves a search term from the user, a name, id number, or identifiable string
	#and if that term is ambiguous for the database, it asks the user for clarification
	# and if it is identifiable it begins playing that file to the requested host
	def play searchTerm, target=nil
		
	end

end

MediaManager.sanity_check

