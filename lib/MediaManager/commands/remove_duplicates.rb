=begin
  Copyright 2009, Jeff Welling

    This file is part of MediaManager.

    MediaManager is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    MediaManager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MediaManager.  If not, see <http://www.gnu.org/licenses/>.
  
=end
module MediaManager
  module Command
    module Remove_duplicates
      def parser(o)
        o.banner= "Usage: mmanager remove_duplicates"
      end
      def execute
        hashes=Storage.readHashes
        index=Storage.createIndexByHash hashes
        sorted_index= index.sort {|a,b| a[1].length <=> b[1].length }
        sorted_index= sorted_index.delete_if {|it| it[1].length == 1 }
        trash_duplicates( "~/.mmanager/trash", sorted_index)

        hashes=Storage.readPaths
        hashes.each {|path|
          #path[0] = id
          #path[1] = path

        }
      end
      def duplicate_prompt hash, array_of_filenames
        added_options=[]
        array_of_filenames=array_of_filenames.sort {|a, b| a[0].length <=> b[0].length }
        array_of_filenames.each_index {|array_index|
          MMCommon.pprint "#{array_index}) #{array_of_filenames[array_index][0]}\n"
          added_options << :"#{array_index}"
        }
        answer=MMCommon.prompt( "Which would you like to keep?" , nil, added_options + [:multi_delete, :keep_both, :delete_both], [:yes, :no] )
        answer=MMCommon.expand_answers answer
        added_options.each_index {|i|
          added_options[i]=added_options[i].to_s
        }
        if answer==:multi_delete
          #Ask which ones to delete
          deletion_candidates=ask_symbol( "Enter the ones you want to delete, comma and/or space seperated: ", nil)
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
        end
      end

      def collect_duplicates(array_of_files, verbose=:no, bytes_to_hash=0)
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

      def trash_duplicates(trash_directory, dupes, move_to_trash=:no)
        duplicates=dupes.clone
        bad_args="trash_duplicates(): Second argument must be formatted such as the hash returned by collect_duplicates()."
        raise bad_args if duplicates.class!=Array
        File.makedirs(trash_directory )unless File.exist?(trash_directory)
        trash_directory= trash_directory.strip.match(/\/$/) ? trash_directory.strip : (trash_directory.strip + '/')
        
        puts "\n\n\n\ntrash_duplicates():  For each set presented, please enter the single digit that represents the file."
        begin
        duplicates.each {|d|
          sha1=d[0]
          array_of_duplicates=d[1]
          to_delete=duplicate_prompt(sha1, array_of_duplicates)
          file_indexes_to_keep=[]

          #Move the duplicates that were selected to our desired trash directory
          array_of_duplicates.each_index {|array_index|
            if to_delete.include? array_index.to_s
              if move_to_trash==:yes
                File.move(array_of_duplicates[array_index][0], trash_directory + File.basename(array_of_duplicates[array_index][0]))
                array_of_duplicates[array_index][0]=trash_directory + File.basename(array_of_duplicates[array_index][0])
              else
                File.symlink(array_of_duplicates[array_index][0], trash_directory + File.basename(array_of_duplicates[array_index][0])) unless (File.exist?(trash_directory + File.basename(array_of_duplicates[array_index][0])) or File.symlink?(trash_directory + File.basename(array_of_duplicates[array_index][0])))
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
        ensure
        require 'pp'
        #This function only creates a directory called .by_hash, under which directories are created with the hashes of the duplicates (or however much of the file was processed)
        #and in those directories symlinks are created which point to the original file.
        duplicates_by_hash(trash_directory + '.by_hash', duplicates)
        end
      end

      def duplicates_by_hash(directory, duplicates)
        require 'pp'
        pp duplicates
        raise "duplicates_by_hash(): second argument must be formatted like the hash returned from collect_duplicates()" unless duplicates.class==Array
        File.makedirs(directory) unless File.exist?(directory)

        directory= directory.match(/\/$/) ? directory.strip : directory.strip + '/'
        
        duplicates.each {|dup|
          sha1= dup[0]
          array_of_dupes= dup[1]
          File.makedirs(directory + sha1) unless File.exist?(directory + sha1)
          symlink_path=''
          array_of_dupes.each {|path_of_dupe|
            trashdir_with_sha=directory + sha1 + '/' + File.basename(path_of_dupe[0])
            trashdir_sans_toplevel=directory.gsub(/\/[^\/]+\/?$/,'/') + File.basename(path_of_dupe[0])
            File.symlink(path_of_dupe[0], trashdir_with_sha) unless (File.exist?(trashdir_with_sha) or File.symlink?(trashdir_with_sha))
          }
        }
      end
    end
  end
end
