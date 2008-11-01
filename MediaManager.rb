#!/usr/bin/ruby
#Read configuration file

#For testing purposes, the home directory must be dynamically determined
#to allow for testing to be done on Apple computers who's users' home dirs
#are in /Users/
$mmconfig = "#{`cd ~;pwd`.chomp}/Documents/Projects/MediaManager/MediaManager.cfg"
raise "Cannot read config file!!!" unless load $mmconfig

#Initialize the cache arrays
$TVDB_CACHE={}

#This is so that we can require files without the .rb extention.
$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

require 'MM_TVDB'

module MediaManager
  extend MMCommon
  def self.import numFiles=:nil
    raise "Sanity check fail!" unless sanity_check
    puts "Indexing files in #{$MEDIA_SOURCES_DIR},\n"
    puts "This may take some time.\n"
    biglist = []
    $MEDIA_SOURCES_DIR.each do |source_dir| #For each source directory
      Find.find(source_dir) do |fullFileName| #For each file in this source directory
        return if numFiles==0
				ignore=FALSE
        puts '.'
        $MEDIA_CONF_IGNORES.each_key do |ignore_pattern|
					ignore=TRUE if fullFileName.index(ignore_pattern)
        end

				#Is directory?
				begin
					FileUtils.cd(fullFileName)
					ignore=TRUE
				rescue Errno::ENOENT
					unless File.symlink?(fullFilename) then
						raise $!
					else
						puts "Broken symlink found at #{fullFileName}"
					end
				rescue Errno::ENOTDIR #Isn't a dir.  Continue.
				end

        unless ignore then
					filename_to_info(fullFileName)  #TODO    Contiue here




        end # Ignore the file
				unless numFiles==:nil
					then numFiles = numFiles-1
				end
      end # End of finding all files in source_dir
    end #end $MEDIA_SOURCES_DIR.each

    puts "Done.\n"
  end

end

