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

#load 'MM_TVDB.rb'
load 'MMCommon.rb'
load 'MM_TVDB2.rb'
load 'MM_IMDB.rb'
load 'RetrieveMeta.rb'
load 'movieInfo_Specification.rb'

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
			
			puts "scan_dirs():  Sql'd #{sqlAddUpdate(sql_string.chop)} filepaths." unless 
				sql_string.gsub("INSERT INTO mediaFiles (Path, PathSHA, Size, DateAdded) VALUES ", '').empty?
		end
			
		return media_files
	end

	#same_file?() is meant to check if two files are identical, by first comparing the filesizes
	#and if those are the same, by progressively hashing the file until the hashes do not match.
	#It returns an array, whose first element is TRUE or FALSE indicating a match or not.
	#The second element of the array will be nil unless both files are the same and their full
	#hash was calculated, otherwise it will contain the hash of the full file.
	#Its extremely important to note that if you change the bytes_to_hash argument to something
	#other than zero, the hash returned when a match is found will NOT be of the whole file,
	#but instead will only be up to the number of bytes you told it to hash.
	#What's different between this method and File.compare from ftools?
	#		This method will return the hash of the file if the files match.  This is useful in finding
	#		duplicate files, and is more efficient than comparing files and then calculating the hash.
	#		Also, its extremely important to take note that if you change the bytes_to_hash argument
	#		away from 0, the hash will NOT be of the whole file, but only of the bytes you instructed
	#		it to hash, and no more.
	def self.same_file?(file1, file2, bytes_to_hash=0)
		puts "wtf? 1#{file1}   2#{file2}" if file1.nil? or file2.nil?
		
		raise "same_file?():  Pass me two files, I shall tell you if they are the same file by comparing a hash" unless File.exist?(file1) and File.exist?(file2)
		file1_hasher= Digest::SHA1.new
		file2_hasher= Digest::SHA1.new
	
		file1_size=File.size(file1)
		file2_size=File.size(file2)
		return [FALSE, nil] if File.size(file1)!=File.size(file2)
		read_so_far=0
		open(file1, 'rb') do |file1_io|
		open(file2, 'rb') do |file2_io|
			while(!file1_io.eof and !file2_io.eof and file1_hasher.hexdigest==file2_hasher.hexdigest and bytes_to_hash!=0 and read_so_far<=bytes_to_hash)
				file1_hasher.update(file1_io.readpartial(1024))
				file2_hasher.update(file2_io.readpartial(1024))
				read_so_far+=1024
			end
		end end
		
		file1_hasher.hexdigest==file2_hasher.hexdigest ? [TRUE,file1_hasher.hexdigest] : [FALSE,nil]
	end

	def self.collect_duplicates(array_of_files, verbose=:no, bytes_to_hash=0)
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
					printf '-' if verbose!=:no
					progress_update_due+=total/50
				end
				pp second_index if array_of_files[second_index].nil?
				result=MediaManager.same_file?(array_of_files[first_index], array_of_files[second_index], bytes_to_hash)
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
		puts "100%\ncollect_duplicates():  Done."
		return duplicates
	end
	
	def self.duplicate_prompt(sha1, array_of_duplicates)
		puts "\n\nduplicate_prompt():  These files have the identical hash of #{sha1}: "
		added_options=[]
		array_of_duplicates.each_index {|array_index|
			puts "#{array_index})  #{array_of_duplicates[array_index]}"
			added_options << :"#{array_index}"
		}
		answer=prompt( "Which would you like to keep?" , nil, added_options + [:multi_delete, :keep_both, :delete_both], [:yes, :no])
		added_options.each_index {|i|
			added_options[i]=added_options[i].to_s
		}
		if answer.to_s.match(/^!/)
			#Delete everything except the selection, return an inverted match
			answer=answer.to_s.reverse.chop.reverse
			added_options.each_index {|i|
				added_options[i]=added_options[i].to_s
			}
			return added_options.delete_if {|option| option.to_s.to_i==answer.to_i }
		elsif answer==:multi_delete
			#Ask which ones to delete
			deletion_candidates=ask_symbol( "Enter the ones you want to delete, comma and/or space seperated:  ", nil)
			return MediaManager.duplicate_prompt(sha1, array_of_duplicates) if deletion_candidates.nil? #Recurse if the user is an idiot
			return deletion_candidates.to_s.gsub(',', ' ').split(' ') #return the match
		elsif answer==:keep_both
			return []
		elsif answer==:delete_both
			return added_options
		else
			return [answer.to_s]
			#return the selection
		end
	end
	
	def self.duplicates_by_hash(directory, duplicates, special_thing=:no)
		raise "duplicates_by_hash(): second argument must be formatted like the hash returned from collect_duplicates()" unless duplicates.class==Hash
		File.makedirs(directory) unless File.exist?(directory)
		directory= directory.match(/\/$/) ? directory.strip : directory.strip + '/'
		duplicates.each {|sha1, array_of_dupes|
			File.makedirs(directory + sha1) unless File.exist?(directory + sha1)
			array_of_dupes.each {|path_of_dupe|
				File.symlink(path_of_dupe, directory + sha1 + '/' + File.basename(path_of_dupe)) unless File.exist?(directory + sha1 + '/' + File.basename(path_of_dupe))
				File.symlink(path_of_dupe, directory.gsub(/\/[^\/]+\/[^\/]+$/,'') + File.basename(path_of_dupe)) if special_thing!=:no unless File.exist?(directory.gsub(/\/[^\/]+\/[^\/]+$/,'') + File.basename(path_of_dupe))
			}
		}
	end

	def self.trash_duplicates(trash_directory, dupes)
		duplicates=dupes.clone
		bad_args="trash_duplicates(): Second argument must be formatted such as the hash returned by collect_duplicates()."
		raise bad_args if duplicates.class!=Hash
		File.makedirs(trash_directory )unless File.exist?(trash_directory)
		trash_directory= trash_directory.strip.match(/\/$/) ? trash_directory.strip : (trash_directory.strip + '/')
#		by_sha1="#{trash_directory.match(/\/^/) ? trash_directory : trash_directory << '/'}.by_sha1/"
#		File.makedirs( by_sha1 ) unless File.exist?( by_sha1 )
		
		puts "trash_duplicates():  For each set presented, please enter the single digit that represents the file,\n      or you can invert the sense of the match using '!'.  So '!1' would mean delete everything except 1."
		duplicates.each {|sha1, array_of_duplicates|
			to_delete=duplicate_prompt(sha1, array_of_duplicates)
			file_indexes_to_keep=[]

			array_of_duplicates.each_index {|array_index|
				if to_delete.include? array_index
#					File.move(array_of_duplicates[array_index], trash_directory + File.basename(array_of_duplicates[array_index]))
					array_of_duplicates[array_index]=trash_directory + File.basename(array_of_duplicates[array_index])
				else
					file_indexes_to_keep << array_index
				end
			}
			
			file_indexes_to_keep.each {|index|
				array_of_duplicates.delete_at index
			}
		}
		$it=duplicates
		duplicates_by_hash(trash_directory + '.by_hash', duplicates, :yes)
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

