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
  #Functions/methods that are common to all of the MediaManager app
  class MMCommon
    class << self
      #scans a target, returning the full path of every item found, in an array
      def scan_target target
        items=[]
        Find.find(File.expand_path(target)) do |it|
          items << it
        end unless target.nil? or !File.exist?(target)
        raise "\n You are supposed to pass me a valid dir or file.\n\n" unless !target.nil? or File.exist?(target)
        items
      end

      #returns true if str matches any of the exclusion matches
      #ar_of_excludes must be an array of regexes
      def excluded? str, ar_of_excludes
        ar_of_excludes.each {|exclude|
          return true if str.match(exclude)
        }
        false
      end

      def pprint str
        printf str.to_s.gsub('%', '%%')     #The Gsub is to escape '%'s, which if unescaped, cause errors because printf expects more than one argument in that scenario
      end

      def readConfig filename=nil
        filename||= $config_file
        return OpenStruct.new unless File.exists?(File.expand_path(filename))
        YAML.load readFile(filename).join
      end

      def saveConfig config, filename=nil
        filename||= $config_file
        writeFile( YAML.dump(config), filename)
      end

      def writeFile contents, filename, append=nil
        FileUtils.mkdir(File.expand_path(Storage.basedir)) unless File.exist?(File.expand_path(Storage.basedir))
        File.open( File.expand_path(filename), (append.nil? ? (File::WRONLY|File::TRUNC|File::CREAT) : ("a"))) {|f| f.write contents }
      end
      def readFile filename, maxlines=0
        i=0
        read_so_far=[]
        begin
          f=File.open(File.expand_path(filename), 'r')
          while (line=f.gets)
            break if maxlines!=0 and i >= maxlines
            read_so_far << line and i+=1
          end
        rescue Errno::ENOENT
        end
        read_so_far
      end

      def sha1 stuff, is_file=false
        digest=Digest::SHA1.new
        if is_file.class == TrueClass
          pprint "Hashing #{stuff}\n"
          exp_stuff=File.expand_path(stuff)
          so_far=0
          size=File.size(exp_stuff)
          current=size/50   #Reporting increment
          open(exp_stuff, 'r') do |io|
            while ( !io.eof )
              read_buffer=io.readpartial(1025)
              so_far+=1024
              if so_far > current
                pprint '.' unless size < 1024*50
                current+=size/50
              end
              digest.update(read_buffer)
            end
          end
          pprint "\n" unless size < 1024*50
        else #Hash the string
          digest.update(stuff)
        end
        digest.hexdigest
      end
      
      #This function taken from http://rubyquiz.com/quiz22.html
      #Credit to Jason Bailey
      $data = [
      ["M" , 1000],
      ["CM" , 900],
      ["D" , 500],
      ["CD" , 400],
      ["C" , 100],
      ["XC" , 90],
      ["L" , 50],
      ["XL" , 40],
      ["X" , 10],
      ["IX" , 9],
      ["V" , 5],
      ["IV" , 4],
      ["I" , 1]
      ]
      def toArabic(rom)
        reply = 0
        return '' if rom.nil?
        for key, value in $data
          while rom.index(key) == 0
            reply += value
            rom.slice!(key)
          end
        end
        reply
      end
      def ask question, default=nil
        print "\n#{question} "
        answer = STDIN.gets.strip.downcase
        throw :quit if 'q' == answer
        return default if symbolize(answer)==:empty
        answer
      end
      def ask_symbol question, default
        answer = symbolize ask(question)
        throw :quit if :quit == answer
        return default if :empty == answer
        answer
      end
      def prompt question, default = :yes, add_options = nil, delete_options = nil
        options = ([default] + [:yes,:no] + [add_options] + [:quit]).flatten.uniq
        if delete_options.class == Array
          delete_options.each {|del_option|
          options -= [del_option]
        }
        else
          options -= [delete_options]
        end
        option_string = options.collect {|x| x.to_s.capitalize}.join('/')
        answer = nil
        loop {
          answer = ask_symbol "#{question} (#{option_string.gsub('//', '/')}):", default
          (answer=default if answer==:nil) unless default.nil?
          break if options.member? MMCommon.expand_answers(answer)
        }
        answer
      end
      def symbolize text
        return :nil if text.nil?
        return :empty if text.empty?
        return :quit if text =~ /^(q|quit)$/i
        return :edit if text =~ /^(e|edit)$/i
        return :yes if text =~ /^(y|yes)$/i
        return :no if text =~ /^(n|no)$/i
        text.to_sym
      end 
      def expand_answers answer_
        answer=answer_.to_s.downcase

        case 
        when answer=='k'
          return :keep_both
        when answer=='m'
          return :multi_delete
        when answer=='d'
          return :delete_both
        end
        answer_
      end
      def add_videots path
        @thing||=[]
        @thing << path unless @thing.include? path
        @thing
      end
    end
  end
end
