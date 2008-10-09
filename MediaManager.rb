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
  def sanity_check
    sanity="sane"

    if(File.exist? $mmconfig)
      #if debug - print debug info
    else
      puts "Warning! Critical Sanity Check Failed: #{$mmconfig} does not exist?  Is the file readable?"
      sanity=FALSE
    end

    if sanity= "sane"  # return "sane" if sanity check passed, else FALSE
      sanity
    else
      FALSE
    end
  end
  def import
    if self.sanity_check == "sane"
      
    else  # Failed sanity_check
      puts "Critical error: Failed sanity check!"
    end
  end
end   #      HON
