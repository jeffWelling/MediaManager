#!/usr/bin/ruby
#Read configuration file

#For testing purposes, the home directory must be dynamically determined
#to allow for testing to be done on Apple computers who's users' home dirs
#are in /Users/
$mmconfig = "#{`cd ~;pwd`.chomp}/Documents/Projects/MediaManager/MediaManager.cfg"
raise "Cannot read config file!!!" unless load $mmconfig

#This is so that we can require files without the .rb extention.
$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

load 'MMCommon'

module MediaManager
  extend MMCommon
  def self.import numFiles=nil
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
					then numFiles = numFiles+1
				end
      end # End of finding all files in source_dir
    end #end $MEDIA_SOURCES_DIR.each

    puts "Done.\n"
  end

  def filename_to_info(filename)
    if filename.index('//') || filename.index('\/')
		  raise "Not yet able to process files with '//' or escaped slashes such as '\/'.\n"
		end

		is_movie?(filename)

		puts filename.to_s
	end

	def is_movie?(fp)
		#Return True or False

	  #Store the results from each assesment attempt
	  #for reference and recalculation at end of function
	  answers = []

		#split the path to make it searchable, but retain full path
		#file_path is array of the seperated names of each parent folder
		file_path=fp.split('/')
		counter=0

		#split on '.'
		#file_path.each do |level|
		#	if level.index('.')!=nil && level.index('.') < level.length-4
		#		filename[counter] = level.split('.')
		#		level=filename[counter]
		#	end

		#0.
		#Does the path contain 'movie' in it?
		file_path.each do |filepath_segment|
			if filepath_segment.downcase.index("movie")
				answers[0]= "TRUE"
			else
				answers[0]= "FALSE"
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
				answers[1]= "FALSE"
			end
		end

		#2.
		#What size is it? (in bytes)    >= 650 = movie
		answers[2]= File.size?(fp)
		if answers[2]==nil
			print "Warning: File doesn't exist, or has zero size? #{fp}"
			#raise "Warning: File doesn't exist, or has zero size? #{fp}"
		end

		#3.
		#Is it in VIDEO_TS format?
		fp.index("VIDEO_TS") != nil ? answers[3]=TRUE : answers[3]=FALSE

		#4.
		#

		pp answers
	end

end

