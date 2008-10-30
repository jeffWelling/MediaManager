module MediaManager
	module MMCommon
		#With credits to ct / kelora.org	
	  def symbolize text
      raise "symbolize nil" if text.nil?
      return :empty if text.empty?
      return :quit if text =~ /^(q|quit)$/i
      return :edit if text =~ /^(e|edit)$/i
      return :yes  if text =~ /^(y|yes)$/i
      return :no   if text =~ /^(n|no)$/i
      text.to_sym
    end 
    def ask question
      print "\n#{question} "
      answer = gets.chomp
      throw :quit if 'q' == answer
      answer
    end 
    def ask_symbol question, default
      answer = symbolize ask(question)
      throw :quit if :quit == answer
      return default if :empty == answer
      answer
    end
		#/credits 
	

    def self.reloadConfig askOnFail = :yes
      begin
				load $MEDIA_CONFIG_FILE
			rescue LoadError => e
				puts "Could not find config file...? Cannot continue without it!\n #{e.inspect}"
				if askOnFail? == :yes
					if ask_symbol("Retry loading config file? (Have you corrected the problem?)",:no) == :yes
						return reloadConfig(:no)
					else #Dont want to retry reading config
						exit
					end
				end
				exit #Cannot continue if cannot read config (and not asking)
			rescue SyntaxError => e
				puts "Your config file has syntax errors.\nGo read Why's Poignant Guide to Ruby, get a clue, and try again."
				puts e.inspect
				exit
			end
			return TRUE
    end

    def resetDir
      FileUtils.cd($MEDIA_CONFIG_DIR)
    end

    def sanity_check
      MediaManager::reloadConfig :yes			#reloadConfig will exit unless successful
			sanity=:sane
      require "find"
      require "fileutils"
      require 'pp'

      #PHP is installed and useable
      #FIXME  Check for curl
      sanity=`php -r "print('sane');"`.to_sym

      return sanity if sanity==:sane
    end

		def gsearch query=:nil
			if query == :nil
				puts "Must call with a query string.\n"
				return
			end
		  bigstring=`php -f #{$MEDIA_CONFIG_DIR}google_api_php.php "#{query}"`

		  bigstring=bigstring.split('<level1>')

		  counter=0
		  bigstring.each do |str|
		    counter1=0
		    hsh={}
		    bigstring[counter]=str.split('<level2>')
		    bigstring[counter].each do |str2|
		      tmp= bigstring[counter][counter1].split('<:>')
		      bigstring[counter][counter1]= {tmp[0]=>tmp[1]}
		      counter1=counter1+1
		    end 
		    counter=counter+1
		  end 
		  # newstring = bigstring.split().collect {|line| line.split().collect {|word| x,y = word.split('<:>' ; { x => y } } }
		  return bigstring
		end


	end #MMCommon
end
