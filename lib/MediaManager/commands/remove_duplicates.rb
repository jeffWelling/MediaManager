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
      end
      def duplicate_prompt hash, array_of_filenames
        added_options=[]
        array_of_filenames.each_index {|array_index|
          MMCommon.pprint "#{array_index}) #{array_of_filenames[array_index][0]}\n"
          added_options << :"#{array_index}"
        }
        answer=MMCommon.prompt( "Which would you like to keep?" , nil, added_options + [:multi_delete, :keep_both, :delete_both], [:yes, :no])
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

      def trash_duplicates(trash_directory, dupes, move_to_trash=:no)
        duplicates=dupes.clone
        bad_args="trash_duplicates(): Second argument must be formatted such as the hash returned by collect_duplicates()."
        raise bad_args if duplicates.class!=Array
        File.makedirs(trash_directory )unless File.exist?(trash_directory)
        trash_directory= trash_directory.strip.match(/\/$/) ? trash_directory.strip : (trash_directory.strip + '/')
        
        puts "\n\n\n\ntrash_duplicates():  For each set presented, please enter the single digit that represents the file."
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
        #This function only creates a directory called .by_hash, under which directories are created with the hashes of the duplicates (or however much of the file was processed)
        #and in those directories symlinks are created which point to the original file.
        duplicates_by_hash(trash_directory + '.by_hash', duplicates)
      end
    end
  end
end
