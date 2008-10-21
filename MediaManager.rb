#!/usr/bin/ruby
#Read configuration file
$mmconfig = "#{`cd ~;pwd`.chomp}/Documents/Projects/MediaManager/MediaManager.cfg"
class Configuration

  def initialize
    self.read
  end

  def Configuration.read
    if File.exist? $mmconfig

      $configuration = {                #Configuration options must be 'declared' here before
        "MYSQL_SERVER" => "",           # this script will 'read them in' from the config file
        "MYSQL_USERNAME" => "",
        "MEDIA_LIBRARY_DIR" => "",      #=begin Ex. /var/media/Library end=
        "MEDIA_SOURCES_DIR" => ""       #=begin Ex.  /foo/bar;/bar/foo; end=
      }


      counter = 0
      file = []
      File.open($mmconfig, "r") do |infile|
        while (line = infile.gets)
          #todo
          #handle comments to end of line
          # parse file
          file[counter] = line.chomp

          if line.index("#")         #Handle in-line comments to end of line
            length = line.index("#")
          else
            length = line.length
          end

          if line.index("=")
            if $configuration["#{line.slice( 0,line.index('=') )}"] != nil
              $configuration.merge!( { "#{line.slice( 0,line.index('=') )}" => "#{line.index('#') ? line.slice( line.index('=')+1,line.index('#')-line.index('=')-1 ).strip : line.slice( line.index('=')+1,line.length ).strip}" })
              puts line.slice( 0,line.index('=') ) + " = " + $configuration[ line.slice( 0,line.index('=') ) ]
            else
              puts "Warning: non-commented line in configuration file does not match available option. (#{line.to_s.chomp})"
            end
          else
            puts "Warning - Comment: no '=' delimiter found on line. (#{line.to_s.chomp}) "
          end
          counter = counter +1
        end
      end
    else
      print "ERROR: File doesn't exist - #{$mmconfig}"
    end
  end
end

class MediaManager
  def initialize
    self.sanity_check
  end

  def sanity_check
    sanity="sane"
		require "find"
		require "fileutils"

		#Config file exists?
    if(File.exist? $mmconfig)
      #if debug - print debug info
    else
      puts "Warning! Critical Sanity Check Failed: #{$mmconfig} does not exist?  Is the file readable?"
      sanity=FALSE
    end

		#PHP is installed and useable
		sanity=`php -r "print('sane');"`

    if sanity== "sane"  # return "sane" if sanity check passed, else FALSE
      sanity
    else
      FALSE
    end
  end

  def import
    if self.sanity_check == "sane"
      load $mmconfig
     	puts "Indexing files in #{$MEDIA_SOURCES_DIR},\n"
      puts "This may take some time.\n"
 			biglist = []
			$MEDIA_SOURCES_DIR.each do |source_dir|
        Find.find(source_dir) do |mediafile|
          ignore=FALSE
          puts '.'
          $MEDIA_CONF_IGNORES.each_key do |ignore_pattern|
            if mediafile.index(ignore_pattern)!=nil
              ignore=TRUE
            end
          end
          if(ignore==FALSE)
            #get info about file
            #self.filename_to_info
            begin
              FileUtils.cd(mediafile)
              #Is directory, should not process
            rescue Errno::ENOTDIR => err
              #File is not a directory, continue
              filename_to_info(mediafile)
						rescue Errno::ENOENT => err
							if File.symlink?(mediafile)
								puts "Broken symlink? #{mediafile}"
							else
								raise $!
							end
            rescue  #Could not cd
              raise $!
            end
          end # Ignore the file
        end 
			end #end $MEDIA_SOURCES_DIR.each

      puts "Done.\n"

    else  # Failed sanity_check
      puts "Critical error: Failed sanity check!"
    end
  end

  def filename_to_info(filename)
    if filename.index('//') || filename.index('\/')
		  raise "Not yet able to process files with '//' or escaped slashes such as '\/'.\n"
		end

		#$MEDIA_SOURCES_DIR.each do |source_path|
    #	if filename.index(source_path)!=nil
		#		filename=filename.slice( source_path.length,filename.length )
		#	end
		#end
		
		#filename=filename.split('/')
		#counter=0
		#filename.each do |level|
		#	if level.index('.')!=nil && level.index('.') < level.length-4
		#		filename[counter] = level.split('.')
		#		level=filename[counter]
		#	end
			
			
		#	counter=counter+1
		#end
		
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
		#What size is it? (in bytes)
		answers[2]= File.size?(fp)
		if answers[2]==nil
			raise "Warning: File doesn't exist, or has zero size? #{fp}"		
		end

		


		puts answers
	end

end

def gsearch(query)
	bigstring=`php -f google_api_php.php "#{query}"`

	bigstring=bigstring.split('<level1>')

	counter=0
	bigstring.each do |str|
		counter1=0
		hsh={}
		bigstring[counter]=str.split('<level2>')
		bigstring[counter].each do |str2|
			tmp= bigstring[counter][counter1].split('<:>')
			bigstring[counter][counter1]= {tmp[0]=>temp[1]}
			counter1=counter1+1
		end
		counter=counter+1
	end

end
