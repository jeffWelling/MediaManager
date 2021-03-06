module MediaManager
	module FindDuplicates
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
				if bytes_to_hash!=0
					while(!file1_io.eof and !file2_io.eof and file1_hasher.hexdigest==file2_hasher.hexdigest and read_so_far<=bytes_to_hash)
						file1_hasher.update(file1_io.readpartial(1024))
						file2_hasher.update(file2_io.readpartial(1024))
						read_so_far+=1024
					end
				else
					while(!file1_io.eof and !file2_io.eof and file1_hasher.hexdigest==file2_hasher.hexdigest)
						file1_hasher.update(file1_io.readpartial(1024))
						file2_hasher.update(file2_io.readpartial(1024))
						read_so_far+=1024
					end
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
					if array_of_files[second_index].nil?
						puts "wtf"
						pp second_index
					end
					result=MediaManager::FindDuplicates.same_file?(array_of_files[first_index], array_of_files[second_index], bytes_to_hash)
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
			array_of_duplicates=array_of_duplicates.sort {|a, b| a.length <=> b.length }
			array_of_duplicates.each_index {|array_index|
				puts "#{array_index})  #{array_of_duplicates[array_index]}"
				added_options << :"#{array_index}"
			}
			answer=prompt( "Which would you like to keep?" , nil, added_options + [:multi_delete, :keep_both, :delete_both], [:yes, :no])
			added_options.each_index {|i|
				added_options[i]=added_options[i].to_s
			}
			if answer==:multi_delete
				#Ask which ones to delete
				deletion_candidates=ask_symbol( "Enter the ones you want to delete, comma and/or space seperated:  ", nil)
				return MediaManager.duplicate_prompt(sha1, array_of_duplicates) if deletion_candidates.nil? #Recurse if the user is an idiot
				return deletion_candidates.to_s.gsub(',', ' ').split(' ') #return the match
			elsif answer==:keep_both
				return []
			elsif answer==:delete_both
				return added_options
			else
				#Invert the answer
				to_delete=[]
				added_options.each {|index_ofa_dupe| to_delete << index_ofa_dupe unless index_ofa_dupe==answer.to_s }
				return to_delete
				#return the selection
			end
		end
		
		def self.duplicates_by_hash(directory, duplicates)
			raise "duplicates_by_hash(): second argument must be formatted like the hash returned from collect_duplicates()" unless duplicates.class==Hash
			File.makedirs(directory) unless File.exist?(directory)
			directory= directory.match(/\/$/) ? directory.strip : directory.strip + '/'
			duplicates.each {|sha1, array_of_dupes|
				File.makedirs(directory + sha1) unless File.exist?(directory + sha1)
				symlink_path=''
				array_of_dupes.each {|path_of_dupe|
					trashdir_with_sha=directory + sha1 + '/' + File.basename(path_of_dupe)
					trashdir_sans_toplevel=directory.gsub(/\/[^\/]+\/?$/,'/') + File.basename(path_of_dupe)
					File.symlink(path_of_dupe, trashdir_with_sha) unless (File.exist?(trashdir_with_sha) or File.symlink?(trashdir_with_sha))
				}
			}
		end

		def self.trash_duplicates(trash_directory, dupes, move_to_trash=:no)
			duplicates=dupes.clone
			bad_args="trash_duplicates(): Second argument must be formatted such as the hash returned by collect_duplicates()."
			raise bad_args if duplicates.class!=Hash
			File.makedirs(trash_directory )unless File.exist?(trash_directory)
			trash_directory= trash_directory.strip.match(/\/$/) ? trash_directory.strip : (trash_directory.strip + '/')
			
			puts "\n\n\n\ntrash_duplicates():  For each set presented, please enter the single digit that represents the file."
			duplicates.each {|sha1, array_of_duplicates|
				to_delete=duplicate_prompt(sha1, array_of_duplicates)
				file_indexes_to_keep=[]

				#Move the duplicates that were selected to our desired trash directory
				array_of_duplicates.each_index {|array_index|
					if to_delete.include? array_index.to_s
						if move_to_trash==:yes
							File.move(array_of_duplicates[array_index], trash_directory + File.basename(array_of_duplicates[array_index]))
							array_of_duplicates[array_index]=trash_directory + File.basename(array_of_duplicates[array_index])
						else
							File.symlink(array_of_duplicates[array_index], trash_directory + File.basename(array_of_duplicates[array_index])) unless (File.exist?(trash_directory + File.basename(array_of_duplicates[array_index])) or File.symlink?(trash_directory + File.basename(array_of_duplicates[array_index])))
						end
					else
						file_indexes_to_keep << array_index
					end
				}
				#Remove the 'good' dupe, the one we want to keep, so that we can pass the whole array to duplicates_by_hash()
				file_indexes_to_keep.each {|index|
					array_of_duplicates.delete_at index
				}
			}
			#This function only creates a directory called .by_hash, under which directories are created with the hashes of the duplicates (or however much of the file was processed)
			#and in those directories symlinks are created which point to the original file.
			duplicates_by_hash(trash_directory + '.by_hash', duplicates)
		end

	end
end
