require 'rubygems'
require 'mechanize'
require 'dbi'
require 'mysql'
require 'timeout'

#Configuration variables
$Database_name='TvDotComScraperCache'
$Database_host='mysql.osnetwork'
$Database_user='TvDotCom'
$Database_password='omgrandom'
$anti_flood=2
$Use_Mysql=TRUE
$Sql_Check=FALSE
$Populate_Bios=TRUE

#Credit for origional generate_hash function goes to 
#http://blog.arctus.co.uk/articles/2007/09/17/compatible-md5-sha-1-file-hashes-in-ruby-java-and-net-c/
#Adapted to be slightly verbose, and to use a cache, with the option of bypassing the cache.
require 'digest/sha1'	
def hash_file(file_path_and_name, bypassCache=nil) #Was generate_hash
	cache=''

	#Only delete files that are being processed so that the database may be consulted manually for information if thetvdb ever has problems or goes down	
	n=sqlAddUpdate("DELETE FROM FileHashCache WHERE PathSHA = '#{hash_filename file_path_and_name}' AND DateAdded < '#{DateTime.now.-(3).strftime("%Y-%m-%d %H:%M:%S")}'")
	puts "Deleted expired cache record of file's hash." if n==1
	cache=sqlSearch("SELECT * FROM FileHashCache WHERE PathSHA = '#{hash_filename file_path_and_name}'")
	unless cache.empty? or bypassCache
		puts "This file was hashed less than 3 days ago, using cached hash."
		return cache[0]['FileSHA']
	end

  hash_func = Digest::SHA1.new # SHA1 or MD5
	print "\nHashing a file "
	sofar=0	
	size=File.size(file_path_and_name)
	current=size/50
  open(file_path_and_name, "rb") do |io|
    while (!io.eof)
            readBuf = io.readpartial(1024)
						sofar=sofar+1024
						print '.' if sofar > current
						current=current+size/50 if sofar > current
            hash_func.update(readBuf)
    end
  end
	
  digest=hash_func.hexdigest
	puts "100%  =>  #{digest}"
	sqlAddUpdate("INSERT INTO FileHashCache (PathSHA, FileSHA, DateAdded) VALUES ('#{hash_filename file_path_and_name}', '#{digest}', NOW())") if cache.empty?
	return digest
end
#Generate a hash of the path to a file for the purpose of MySQL lookup
def hash_filename path
	hash_func = Digest::SHA1.new # SHA1 or MD5
	hash_func.update(path)
	return hash_func.hexdigest
end



module TvDotComScraper
	#Custom added self. to every function because it wouldnt freaking work without it, and I dont feel like relearning methods and scopes this very second, if it bothers you then suggest a fix.
	#With credits to ct / kelora.org	
	def self.symbolize text
		return :nil if text.nil?
		return :empty if text.empty?
		return :quit if text =~ /^(q|quit)$/i
		return :edit if text =~ /^(e|edit)$/i
		return :yes  if text =~ /^(y|yes)$/i
		return :no   if text =~ /^(n|no)$/i
		text.to_sym
	end 
	
	#customized, added 'default'
	#had to add 'STDIN.gets', without 'STDIN' was producing errors.
	def self.ask question, default=nil
		print "\n#{question} "
		answer = STDIN.gets.strip.downcase
		throw :quit if 'q' == answer
		return default if symbolize(answer)==:empty
		answer
	end
	def self.ask_symbol question, default
		answer = symbolize ask(question)
		throw :quit if :quit == answer
		return default if :empty == answer
		answer
	end
	def self.prompt question, default = :yes, add_options = nil, delete_options = nil
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
			answer=default if answer==:nil
			break if options.member? answer
		}
		answer
	end
	def self.agent(timeout=300)
		a = WWW::Mechanize.new
    a.read_timeout = timeout if timeout
		a.user_agent_alias= 'Mac Safari'
		a   
	end
	def self.get_page(url)
		printf "\n"		
		pp url
		printf '=>'
		begin
			return TvDotComScraper.agent.get(url).body
		rescue Timeout::Error => e
			retry if TvDotComScraper.deal_with_timeout(e)==TRUE
		rescue Errno::ETIMEDOUT => e
			retry if TvDotComScraper.deal_with_timeout(e)==TRUE
		ensure
		printf "<= "

		printf "(anti-flood) "
		sleep $anti_flood
		end
	end
	#/credits ct 
	
	#This method is to be used for sql statements that do not return results, except for the number of records processed
	#THE SQL MUST ALREADY BE ESCAPEID
	#It returns the number of records
	def self.sql_do(sql_String)
		if $Sql_Check
			printf "\n"
			pp sql_String
			prompt('Continue?')
		end
		r=FALSE
		begin
			$dbh =  DBI.connect("DBI:Mysql:#{$Database_name}:#{$Database_host}", $Database_user, $Database_password)
			r= $dbh.do sql_String
		rescue Mysql::Error => e
			puts "Mysql sanity check: FAILED"
			puts "Error code: #{e.errno}"
			puts "Error message: #{e.error}"
			puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
			#raise "omg database error"
		rescue DBI::DatabaseError => e
			puts e.to_s
			#raise "omg DBI database error"
		ensure	
			#End of method, disconnect from database
			$dbh.disconnect if $dbh.connected? unless $dbh.nil?
		end
		return r
	end

	#Run from populate_results()
	#This is run with the value
	#FIXME This method makes my eyes bleed, it needs to be fixed
	def self.get_value_of(key, page_as_string)
		raise "get_value_of(): Both arguments must be strings you idiot." unless key.class==String and page_as_string.class==String
		#key=key+':' unless key.match(/:$/)||key.match(/show score/i)
		#key=Regexp.escape(key)
		case key.downcase
			when 'show categories'
				begin 
					return page_as_string.match(/\<!--\/my_rating--\>.+?\<!--\/COLUMN_A1--\>/im)[0].
						match(/\<h\d\>genre(s)?\<\/h\d\>\s+?(\s+?\<a href.+?\<\/a\>(\s+)?(,)?){1,}/i)[0].
						gsub(/^\<.+?\>.+?\<.+?\>/, '').gsub(/\<.+?\>/, '').strip.gsub(/\s+/, ' ')
				rescue NoMethodError => e
					unless e.to_s.match("undefined\\ method\\ `\\[\\]'\\ for\\ nil:NilClass")
						raise e
					end
					return FALSE
				end
			when 'summary'
				if page_as_string.match(/\<!--\/my_rating--\>.+?\<!--\/COLUMN_A1--\>/im) and page_as_string.match(/\<!--\/my_rating--\>.+?\<!--\/COLUMN_A1--\>/im)[0].match(/\<h\d\>show summary\<\/h\d\>/i)
					summary=page_as_string.match(/\<!--\/my_rating--\>.+?\<!--\/COLUMN_A1--\>/im)[0].
						match(/\<h\d class="panel_title"\>\s+?show summary.+?\<\/h\d\>\s+?\<div class="text"\>.+?\<\/div\>/im)[0].
						gsub(/^\<h\d.+?\<div class="text"\>/im, '').gsub(/\<\/div\>$/, '').strip
					puts "get_value_of(): WARNING!!! Summary longer than database will allow!\n Summary will be truncated!" if summary.length > 32999
					return summary
				else
					return FALSE
				end
			when 'show score'
				return page_as_string.match(/\<h\d\>Show Score\<\/h\d\>\s+?\<div.+?\<\/div\>\s+?<div class="global_score"\>.+?\<\/div\>/im)[0].
					gsub(/\<.+?\>/, '').match(/(\d){1,}\.(\d){1,}/)[0]
			when 'title'
				return page_as_string.match(/\<!--\/header_area--\>\s+?(\<div.+?\>\s+?){1,4}?(\s+?\<span.+?\<\/span\>\s+?){1}?\<h\d( class="show_title")?\>.+?\<\/h\d\>/im)[0].
					match(/\<h\d( class="show_title")?\>.+?\<\/h\d\>$/i)[0].gsub(/\<.+?\>/, '')
			when 'originally on'
				bit=page_as_string.match(/\<span class="tagline"\>.+?\<\/span\>/im)[0].split("\n")
				if bit[2].strip.empty?
					return bit[1].gsub(/\<.+?\>/, '').gsub(/\(.+?\)\s+$/, '').strip
				elsif bit[2].gsub(/\<.+?\>/, '').strip.empty?
					return FALSE
				else
					return bit[2].strip
				end
			when 'status'
				begin
					return page_as_string.match(/\<!--\/my_rating--\>.+?\<!--\/COLUMN_A1--\>/im)[0].
						match(/\<h\d\>status\<\/h\d\>.+?\<.+?\>/im)[0].
						gsub(/^\<h\d\>.+?<\/h\d\>/, '').gsub(/\<.+?\>/, '').strip
				rescue NoMethodError => e
					#Silently ignore if premiered doesn't exist
					unless e.to_s.match("undefined\\ method\\ `\\[\\]'\\ for\\ nil:NilClass")
						raise e
					end
					return FALSE
				end
			when 'premiered'
				begin
					date=''
					rawdate=page_as_string.match(/\<!--\/my_rating--\>.+?\<!--\/COLUMN_A1--\>/im)[0].
						match(/\<h\d\>premiered\<\/h\d\>.+?\<.+?\>/im)[0].
						gsub(/^\<h\d\>.+?<\/h\d\>/, '').gsub(/\<.+?\>$/, '').strip
					date=DateTime.parse(rawdate)
					return date
				rescue NoMethodError => e
					#Silently ignore if premiered doesn't exist
					unless e.to_s.match("undefined\\ method\\ `\\[\\]'\\ for\\ nil:NilClass") or date.length==4
						pp rawdate
						raise e
					end
					return FALSE
				rescue ArgumentError => e
					unless date.empty?
						puts "WARNING!!!: Could not parse 'Premiered' date"
						puts e
						raise e
					else
						return FALSE
					end
				end
			when 'last aired'
				#Used to be called 'last aired', tvcom now calls it 'ended'
				begin
					return DateTime.parse(date=page_as_string.match(/\<!--\/my_rating--\>.+?\<!--\/COLUMN_A1--\>/im)[0].
						match(/\<h\d\>ended\<\/h\d\>.+?\<.+?\>/im)[0].
						gsub(/^\<h\d\>.+?<\/h\d\>/, '').gsub(/\<.+?\>$/, '').strip)
				rescue NoMethodError => e
					#Silently ignore if 'ended' doesn't exist
					unless e.to_s.match("undefined\\ method\\ `\\[\\]'\\ for\\ nil:NilClass")
						raise e
					end
					return FALSE
				end				
		end
		raise key
		return page_as_string.match(/#{key}\<.*?\>.*?\</i)[0].
			match(/\>.*?\<$/)[0].
			chop.reverse.chop.reverse.strip
	end

	#This function searches tv.com for the query string, and returns an array of all of the results (Url and TvComSeriesID).
	#returns empty array if no results
	#It only gets the results as (Url and TV.com SeriesID) pairs, other functions get that info
=begin
The search_results array is in this format
[{"series_details_url"=>
   "http://www.tv.com/star/show/22039/summary.html?q=star&amp;tag=search_results;title;1",
  "tvcomID"=>"22039"},
 {"series_details_url"=>
   "http://www.tv.com/instant-star/show/28203/summary.html?q=star&amp;tag=search_results;title;2",
  "tvcomID"=>"28203"},
 {"series_details_url"=>
   "http://www.tv.com/star-trek/show/633/summary.html?q=star&amp;tag=search_results;title;3",
  "tvcomID"=>"633"}]
=end
	def self.search_tvcom (query)
		raise "search(): takes a non-empty string only." unless query.class==String and !query.empty?

		pagecount_regex=/\<div class="pag_wrap"\>.*\<ul class="search_results_list"\>/im
		pagecount_lockon_regex=/[\d]+\<\/a\>\<\/li\>\<\/ul\>$/im
		if query.include?(' ')
			safe_query=query.gsub(' ', '+')
		else
			safe_query=query
		end
		search_url="http://www.tv.com/search.php?type=Search&stype=ajax_search&qs=#{safe_query}&search_type=program&pg_results=0&sort="
		printf "search_tvcom(): Searching for #{query}...   "
		begin
			page_as_string=agent.get(search_url)    #Dont check for timeout here because it could indicate other things, like malicious attempt to stop us!
		rescue Timeout::Error => e
			retry if TvDotComScraper.deal_with_timeout(e)==TRUE
		rescue Errno::ETIMEDOUT => e
			retry if TvDotComScraper.deal_with_timeout(e)==TRUE

		end
		printf "Done.\n"


		page_as_string=page_as_string.body
		search_results=[]

		pagecount_area=page_as_string.match(pagecount_regex)[0].split("\n")
		if pagecount_area[2].index('page: 1') 
			#If there is only one page to process
			#Check for no-results
			return [] if page_as_string.match(/\<span class="empty"\>There are currently no results.\<\/span\>/im)

			search_results += TvDotComScraper.scrape_results(page_as_string)
		else
			#Multiple pages of results to process
			current_page=1
			num_of_pages= pagecount_area[3]. 
				match(pagecount_lockon_regex)[0].
				match(/[\d]+/)[0]

			printf "search_tvcom(): Processing #{num_of_pages} pages ."
			#get results from first page,
			search_results += TvDotComScraper.scrape_results(page_as_string)			

			#then loop through remaining pages
			#dont forget, url is zero-based.  Work based on that where possible.
			#current_page is zero-based, num_of_pages is one-based, using until to match them shores this up because
			#it does not match the last case
			until (current_page==num_of_pages.to_i)
				sleep $anti_flood unless current_page==1
				looped_url=search_url.gsub(/pg_results=[\d]+/, "pg_results=#{current_page}")
				begin
					page_as_string=agent(30).get(looped_url).body
				rescue Timeout::Error => e
					retry if TvDotComScraper.deal_with_timeout(e)==TRUE
				rescue Errno::ETIMEDOUT => e
					retry if TvDotComScraper.deal_with_timeout(e)==TRUE
				end
				search_results += TvDotComScraper.scrape_results(page_as_string)
				current_page+=1
				printf('.')
			end
			printf("\n")
			
		end

		puts "search_tvcom(): Done."
		return search_results
	end

	#This function takes a string, which is the html of a website.  It is used by the search_tvcom() function, and doesn't need to be used directly
	#It returns an array of info about the results if there are any
	#It is NOT meant to detect empty result sets, you are meant to work that out first   (It will return an empty array)
	def self.scrape_results(body)
	raise "scrape_results(): Only takes a non-empty string as argument" unless body.class==String and !body.empty?

	#body=Regexp.escape(body)
	top_result_regex=/\<li class="result search_spotlight"\>(.+?)?\<\/li>/im
	results_regex=/="result"\>.+\<\/div\>[\s\n]*\<\/li\>/im
	series_details_url_regex=/\<a href="http:.*title;[\d]+"/i
	seriesid_regex=/\/show\/[\d]+\/summary/i
	results=[]
	
	#The first result on the page is unique because its displayed differently, following results are uniform
	r={}
	return [] unless body.match(top_result_regex)     #This line takes care of 'no-results' situations.
	r['series_details_url']= body.match(top_result_regex)[0].
		match(series_details_url_regex)[0].
		match(/href=".*$/i)[0].
		chop.reverse.chop.chop.chop.chop.chop.chop.reverse
	r['tvcomID']=r['series_details_url'].match(seriesid_regex)[0].match(/[\d]+/)[0]
	results<<r

	#This should return if there aren't any results except for the first one
	return results unless body.match(results_regex)

	#non_top_results is an array, with each element being a result.
	non_top_results=body.match(results_regex)[0].split('</li')

	non_top_results.each {|result_blob|
		r={}
		next unless result_blob.match(series_details_url_regex)
		r['series_details_url']= result_blob.match(series_details_url_regex)[0].
			match(/href=".*$/i)[0].
			chop.reverse.chop.chop.chop.chop.chop.chop.reverse
		r['tvcomID']=r['series_details_url'].match(seriesid_regex)[0].match(/[\d]+/)[0]
		results<<r
	}
	
	return results
	end

	def self.deal_with_timeout(e)
		puts e
		printf "deal_with_timeout(): 4 Seconds to respond, default=Retry"
		r=:Retry
		begin
			Timeout::timeout(5) {
				r= prompt( "#{DateTime.now.to_s}  Timeout occured, Retry or Quit?", :Retry, nil, [:yes, :no])
			}
		rescue Timeout::Error
			printf "   --- No response, retrying...\n"
		end
		raise :quit if r==:quit
		return TRUE			

	end

	#This function runs on the search results returned from search_tvcom()
	def self.populate_results(search_results)
		#Sanity check that search_reults is expected format
		printf "populate_results(): checking sanity of argument...  "
		bad_args=FALSE
		if search_results.class==Array
			search_results.each {|result|
				if result.class==Hash
					bad_args=TRUE unless result.has_key?('series_details_url') and result.has_key?('tvcomID')
				else
					bad_args=TRUE
				end
			}
		else
			bad_args=TRUE
		end
		raise "populate_results(): was passed bad arguments" if bad_args
		printf "Done.\npopulate_results(): Populating #{search_results.length} items...  \n"
	
		search_results.each_index {|results_i|
			search_results[results_i]['Episodes']=[]
#			search_results[results_i]['Credits']=[]
			info=0
			info=db_has_series?(search_results[results_i]['tvcomID'].to_i)
			unless info.empty?
				search_results[results_i].merge!({ 'Details' => info['Details'] })
				search_results[results_i].merge!({ 'Credits' => info['Credits'] })
				unless search_results[results_i]['Credits'].empty?
					search_results[results_i]['Credits'].each_index {|credits_i|
						search_results[results_i]['Credits'][credits_i].merge!(TvDotComScraper.db_has_bio?(search_results[results_i]['Credits'][credits_i]['Name']))
					}
				end
			end
			
			search_results[results_i]['Episodes']=db_has_episodes?(search_results[results_i]['tvcomID']) unless info.empty?
	
			next unless info.empty?
			page_as_string=TvDotComScraper.get_page(search_results[results_i]['series_details_url'])
			episode_page_as_string=TvDotComScraper.get_page(page_as_string.match(/http:\/\/www\.tv\.com\/.+?\/show\/\d+?\/episode.html/i)[0])
			stars_page_as_string=TvDotComScraper.get_page(cast=page_as_string.match(/http:\/\/www\.tv\.com\/.+?\/show\/\d+?\/cast\.html/i)[0])
			recurring_page_as_string=TvDotComScraper.get_page(cast+'?flag=2')
			crew_page_as_string=TvDotComScraper.get_page(cast+'?flag=3')

			#Fill in the 'Details' part
			search_results[results_i]['Details']={}
			values=['Originally on', 'Status', 'Premiered', 'Last Aired', 'Show Categories', 'Summary', 'Show score', 'Title']
			values.each {|attribute|
				search_results[results_i]['Details'][attribute]= TvDotComScraper.get_value_of(attribute, page_as_string) #unless $Populate_Bios.class==FalseClass
			}

			puts "\npopulate_results(): populating biographies, need to pull additional pages...\n" if $Populate_Bios
			#FIXME Handle multiple pages for stars, and for recurring roles, etc
			#populate stars, recurring roles, and writers and directors
			#propriety maps out to ['Stars', 'Recurring Roles', and 'Writers and Directors'] respectively
			search_results[results_i]['Credits']=[]
			[1,2,3].each {|propriety|
				case propriety
					when 1
						stars_raw=stars_page_as_string.match(/\<h\d class="module_title"\>stars\<\/h\d\>.+?\<div class="module sponsored_links"\>/im)[0].split('<li')
					when 2
						stars_raw=recurring_page_as_string.match(/\<h\d class="module_title"\>recurring roles\<\/h\d\>.+?\<div class="module sponsored_links"\>/im)[0].split('<li')
					when 3
						stars_raw=crew_page_as_string.match(/\<h\d class="module_title"\>writers\<\/h\d\>.+?\<h\d class="module_title"\>directors/im)[0].split('<li')
				end
				next_page=''
				writers_done=FALSE
				directors_done=FALSE
				crew_done=FALSE
				directors_area=''
				crew_area=''
				while TRUE
					if !next_page.empty?
						#Get next_page, put its info in stars_raw for repreocessing
						stars_raw=(current_page_as_string=TvDotComScraper.get_page(next_page).match(/\<h\d class="module_title"\>stars\<\/h\d\>.+?\<div class="module sponsored_links"\>/im)[0]).split('<li')
						next_page=''
					end

					current_page_as_string||=stars_page_as_string

					if propriety==3
						if writers_done.class==TrueClass and directors_done.class==FalseClass
							stars_raw=directors_area
							directors_done=TRUE
						end

						if directors_done.class==TrueClass
							stars_raw=crew_area
							crew_done=TRUE
						end
					end

					unless stars_raw[1].match(/there are currently no cast members./i)
						stars_raw.each_index {|stars_raw_i|
#							next if stars_raw_i==0  #Skip first array element, junk entry containing html tags that we matched above
							next unless stars_raw[stars_raw_i].match(/\<h\d\ class="name"\>.+?\<\/h\d\>/im)
							actor={}
							name=stars_raw[stars_raw_i].match(/\<h3 class="name"\>(\<.+?\>)?.+?(\<.+?\>)?\<\/h3\>/i)[0].gsub(/\<.+?\>/,'')
							role=stars_raw[stars_raw_i].match(/\<div class="role"\>.+?\<\/div\>/i)[0].gsub(/\<.+?\>/, '')
							actor_bio_url=stars_raw[stars_raw_i].match(/\<h3 class="name"\>.+?\<\/h3\>/i)[0].
								match(/<a.+?\>/)[0].gsub(/^.+?"/, '').chop.chop
							actor={ 'Name' => name, 'Role' => role, 'Propriety' => propriety}
							if $Populate_Bios.class==TrueClass
								actor['birthplace']=FALSE
								actor['birthday']=FALSE
								actor['aka']=FALSE
								actor['recent_role']=FALSE
								actor['recent_role_series']=FALSE
								actor['summary']=FALSE
								actor['gender']=FALSE
								bio=TvDotComScraper.db_has_bio?(actor['Name'])
								unless bio.empty?
									#TODO
									#MERGE BIO INFO
								else
									#db_has_bio returned nothing, get bio
									actor_bio_page_string=TvDotComScraper.get_page(actor_bio_url)
									good_parts=actor_bio_page_string.match(/\<h\d class="module_title"\>\<a href=".+?"\>biography(\<.+?\>){2}.+?\<script type=".+?"\>/im)[0]
									
									actor['birthplace']=good_parts.match(/\<dt\>birthplace:\<\/dt\>\s+?\<dd\>.+?\<\/dd\>/im)[0].
										gsub(/^.+?\n/, '').gsub(/\s+\<.+?\>/, '').gsub(/\<.+?\>$/, '') if good_parts.match(/birthplace:/i)

									begin
										date=(good_parts.match(/\<dt\>birthday:\<\/dt\>\s+\<dd\>.+?\<\/dd\>/im)[0].
											gsub(/^.+?\n/m, '').gsub(/^\s+?\<.+?\>/, '').gsub(/\<.+?\>$/, ''))
										formatted_date= date.match(/-\d+-/)[0].chop.reverse.chop.reverse + '-' + date.match(/\d+/)[0] + '-' + date.match(/\d+$/)[0]
										actor['birthday']=DateTime.parse(formatted_date)
									rescue ArgumentError => e
										raise e unless e.to_s.match(/invalid date/i)
										puts "\n\nBio for #{actor['Name']} has an invalid date in it? '#{formatted_date}'"
										puts "page is at =>    #{actor_bio_url}\n\n"
										actor['birthday']=FALSE
									rescue NoMethodError => e
										$it=e
										raise e unless e.to_s.match(/undefined method `\[\]' for nil:nilclass/i)
										actor['birthday']=FALSE
									end

									actor['aka']=good_parts.match(/\<dt\>aka:\<\/dt\>\s+?\<dd\>.+?\<\/dd\>/im)[0].gsub(/^.+?\n\s+?\<.+?\>/, '').gsub(/\<.+?\>$/, '') if good_parts.match(/aka:/i)

									if good_parts.match(/recent role:/i)
										actor['recent_role']=good_parts.match(/\<dt\>recent role:\<\/dt\>\s+\<dd\>\<strong\>.+?\<\/strong\>\<\/dd\>/im)[0].
											gsub(/^.+?\<strong\>/im, '').gsub(/\<\/strong\>\<\/dd\>$/, '').gsub(/\<a .+?\>/,"'").gsub(/\<\/a\>/, "'")
										actor['recent_role_series']=good_parts.match(/\<dt\>recent role:\<\/dt\>\s+\<dd\>\<strong\>.+?\<\/strong\>\<\/dd\>/im)[0].gsub(/^.+?href=".+?\/show\//im, '').gsub(/\/summary.+?$/, '')
									end

									actor['summary']=good_parts.match(/\<span class="long"\>.+?\<\/span\>/im)[0].gsub(/^\<.+?\>/, '').gsub(/\<.+?\>$/, '') unless good_parts.match(/Add\<\/a\> biographical information for/i)

									actor['gender']=good_parts.match(/\<dt\>gender:\<\/dt\>\s+?\<dd\>.+?\<\/dd\>/im)[0].gsub(/^.+?\n\s+\<dd\>/, '').gsub(/\<\/dd\>$/, '') if good_parts.match(/gender:/i)

								end
							end
							search_results[results_i]['Credits'] << actor
						}
					end

					#Process multiple pages
					if stars_raw[0].match(/pagination/i)
						#There are multiple pages, get the next page URL, and restart loop
						pagination_raw=current_page_as_string.match(/\<h\d class="module_title"\>stars\<\/h\d\>.+?\<div class="module sponsored_links"\>/im)[0].
							match(/^.+?\<div class="body"\>/im)[0]
						unless pagination_raw.match(/\<a href=".+?"\>next/im)
							next_page=''
							#end of pages?
							break
						else
							next_page=pagination_raw.match(/\<a href=".+?"\>next/im)[0].
								match(/".+?"/)[0].chop.reverse.chop.reverse
						end
					elsif propriety==3
						#Writers and Directors page is broken into multiple table sections which can be processed, but must be done
						#seperately.  Process each one in turn, already having done writers
						writers_done=TRUE
						unless directors_done.class==TrueClass
							directors_area=crew_page_as_string.match(/\<h\d class="module_title"\>directors\<\/h\d\>.+?\<h\d class="module_title"\>crew/im)[0].split('<li')
						end
						unless  !crew_done.class==TrueClass
							crew_area=crew_page_as_string.match(/\<h\d class="module_title"\>crew\<\/h\d\>.+?\<div class="module sponsored_links"\>/im)[0].split('<li')
						end
						if writers_done and directors_done and crew_done
							#finished all three
							break
						end
						
							
					else
						#Break unless there are multiple pages to process
						break
					end
				end #End of while loop
				next_page=''
			} 

			#Fill in the episodes
			printf '=>>>'
			begin
				allepisode_page_as_string=TvDotComScraper.agent(300).get(episode_page_as_string.match(/\<ul class="tab_links"\>.+?\<\/ul\>/im)[0].
					match(/\<a\s+href=".+?"\>all\<\/a\>/i)[0].
					match(/".+?"/)[0].chop.reverse.chop.reverse).body
			rescue Timeout::Error => e
				retry if TvDotComScraper.deal_with_timeout(e)==TRUE
			rescue Errno::ETIMEDOUT => e
				retry if TvDotComScraper.deal_with_timeout(e)==TRUE
			end
			printf "<=   "

			episodes_raw=""
			episodes_raw=allepisode_page_as_string.match(/\<div\sid="episode_guide_list"\>.+?\<div\sclass="paginator"\>/im)[0].
				split("</li>\n\n\n")
			no_season=FALSE
			if episodes_raw[0].match(/No episodes have been added/i) and episode_page_as_string.match(/No episodes have been added for this season of/i)
				printf "[no-episodes] "
				episodes_raw=[]
			elsif episodes_raw[0].match(/no episodes have been added/i)
				printf "[Episodes external of any season found, using Season '0'] "
				episodes_raw=episode_page_as_string.match(/\<div\sid="episode_guide_list"\>.+?\<div\sclass="paginator"\>/im)[0].
					split("</li>\n\n\n")
				no_season=TRUE
			end

			unless episodes_raw.empty?
				episodes_raw.each {|episode_as_string|
					#So that we can spit out the episode to the user for examination
					#if we panic trying to get information from it
					begin
						episode={}
						next if episode_as_string.gsub(/\<.*?\>/, '').strip.empty?
						#Season, Ep Number, and Ep Name
						first_bit=episode_as_string.match(/\<div class="meta"\>.+?\<\/div\>/im)[0]

						#Season
						if first_bit.match(/season \d+/i)
							episode['Season']=first_bit.match(/season \d+/i)[0].
								match(/\d+/)[0]
						elsif first_bit.match(/pilot/i)
							printf "   WARNING: episode with no season, but could be pilot.  defaulting to season 1  --- "
							episode['Season']='1'
						elsif no_season
							episode['Season']='0'
						else
							raise "populate_results(): Did not catch 'Season'?"
						end
						
						#Episode Number
						if first_bit.match(/Episode \d+/i)
							episode['EpNum']=first_bit.match(/Episode \d+/i)[0].
								match(/\d+/)[0]
						elsif first_bit.match(/pilot/i)
							if first_bit.gsub(/\<.+?\>/, '').match(/pilot/i)
								episode['EpNum']=first_bit.gsub(/\<.+?\>/, '').match(/pilot/i)[0]
							else 
								#'pilot' is in the html tags but not in text
								episode['EpNum']='Pilot'
							end
						elsif first_bit.match(/special/i)
							episode['EpNum']=first_bit.gsub(/\<.+?\>/, '').match(/special/i)[0]
						else
							puts "populate_results(): Did not catch 'Episode Num'?\nAssuming episode is a 'Special'"
							episode['EpNum']='Special'
						end

						#Episode Name
						episode['EpName']=episode_as_string.match(/\<h\d\>\s+?\<a.+?\>.+?\<\/a\>\s+?\<\/h\d\>/im)[0].
							gsub(/^(\<.+?\>(\s+)?){2}/, '').gsub(/(\<.+?\>(\s+)?){2}$/,'')

						#EpRating
						raw_score=episode_as_string.match(/\<div class="global_score"\>.+?<\/div\>/im)[0].
							match(/\<span class="number"\>.+?\<\/span\>/im)[0]
						if raw_score.match(/n\/a/i)
							episode['EpRating']=FALSE
						else
							episode['EpRating']=raw_score.gsub(/\<.+?\>/, '')
						end

						#Aired
						if first_bit.match(/aired/i)
							begin
								episode['Aired']=DateTime.parse(first_bit.match(/aired:\s.+?\s/i)[0].
									gsub(/^.+?\s/, '').gsub(/\s$/, ''))
							rescue ArgumentError => e
								printf "   WARNING: Invalid date detected.  Purged.   ---"
								episode['Aired']=FALSE
							end
						else
							episode['Aired']=''
						end

						#Summary
						episode['Summary']=''
						summary=episode_as_string.match(/\<h\d\>.+?\<\/h\d\>\s+?\<p.+?\>.+?\<ul/im)[0].
							gsub(/\s+?\<\/p\>\s+?\<ul$/, '').gsub(/^.+?\<p.+?\>\s+/im, '')
						summary.strip.empty? ? episode['Summary']=FALSE : episode['Summary']=summary
						puts "populate_results(): Empty episode summary?" if episode['Summary'].class==FalseClass
						pp search_results[results_i]['series_details_url'] if episode['Summary'].class==FalseClass

						next if episode['EpName'].match(/to be deleted/i)
						search_results[results_i]['Episodes'] << episode
					rescue
						puts "ERROR!!  DEBUG - Printing episode that caused the problem..."
						pp episode_as_string
						raise $!
					end
				}
			end

			printf "#{search_results[results_i]['Episodes'].length} \n"
			TvDotComScraper.store_series_in_db search_results[results_i]
			puts "\n"
		} #end of search_results.each_index 

		puts "populate_results(): Done."
		return search_results
	end

	#Look in MySQL for this seriesID
	#If it exists, AND has not expired, return info
	#If expired and show_expired==TRUE, return info
	#If expired and show_expired==FALSE, or does not exist, return []
	#results are a hash, {['Details']=> X, ['Episodes']=> []}
	def self.db_has_series?(seriesID, show_expired=FALSE)
		raise "db_has_series?(): seriesID must be an integer" unless seriesID.class==Fixnum and seriesID!=0
		return {} unless $Use_Mysql
		printf "db_has_series?(): Checking database for tvcomID:'#{seriesID}'.     "
		result={}
		#Setup mysql connection
		begin
			$dbh =  DBI.connect("DBI:Mysql:#{$Database_name}:#{$Database_host}", $Database_user, $Database_password)


			rez = $dbh.execute "SELECT * FROM Series_Details WHERE tvcomID='#{seriesID}'"
			rez1 = $dbh.execute "SELECT * FROM Cast_and_Crew WHERE tvcomID='#{seriesID}"
			arry=[]
			arry1=[]
			columns=rez.column_names
			rowNum=0
			while row=rez.fetch
				count=0
				row.each {|item|
					arry[rowNum]||={}
					arry[rowNum].merge!( columns[count] => item )
					count=count+1
				}
				rowNum=rowNum+1
			end

			columns=rez1.column_names
			rowNum=0
			while row1=rez1.fetch
				count=0
				row1.each {|item|
					arry1[rowNum]||={}
					arry1[rowNum].merge!( columns[count] => item )
					count=count+1
				}
				rowNum=rowNum+1
			end

			formatted_result={'Details'=> {}, 'Episodes'=>[], 'Credits'=>[]}
			attrs=['Status', 'Originally on', 'Show score', 'Premiered', 'Title', 'Summary', 'Show Categories', 'Last Aired']
			unless arry.empty? 
				attrs.each {|attribute|
					attribute1='Originally_On'	if attribute.match(/originally on/i)
					attribute1='Show_Score' if attribute.match(/show score/i)
					attribute1='Show_Categories' if attribute.match(/show categories/i)
					attribute1=attribute if !attribute.match(/\s/)

					formatted_result['Details'][attribute]=FALSE
					next if arry[0][attribute1].nil?
					if arry[0][attribute1].class==DBI::Timestamp
						formatted_result['Details'][attribute]=DateTime.parse(arry[0][attribute1].to_s)
					else
						formatted_result['Details'][attribute]=arry[0][attribute1]
					end
				}
				#Just for posterity
				formatted_result['tvcomID']=seriesID
				printf "found!\n"
			else 
				formatted_result={}
				printf "not found :(\n"
			end

			attrs1=['Role', 'Name', 'Propriety']
			unless arry1.empty?
				arry1.each {|person|
					crew_person={}
					attrs1.each {|attribute|
						crew_person[attribute]=person[attribute] if attribute.match(/role/i) or attribute.match(/name/i) or attribute.match(/propriety/i)
					}
				formatted_result['Credits'] << crew_person
				}
			else
				formatted_result={}
				printf "not found! :(\n"
			end
				

			#do stuff here
			#format results
		rescue Mysql::Error => e
			puts "Mysql sanity check: FAILED"
			puts "Error code: #{e.errno}"
			puts "Error message: #{e.error}"
			puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
			#raise "omg database error"
		rescue DBI::DatabaseError => e
			puts e.to_s
			#raise "omg DBI database error"
		ensure
			#End of method, disconnect from database
			$dbh.disconnect if $dbh.connected? unless $dbh.nil?
		end
		#format results
		return formatted_result
	end

	#Search the database for episodes for this tvcomID
	#Return array of episodes to fit in series_results[result_i]['Episodes'], or empty array
	#Show expired indicates wether to show episodes that have 'expired', it is intended for use for
	#pulling episodes from the database when tv.com isn't available for updating.
	def self.db_has_episodes?(tvcomID, show_expired=nil)
		raise "db_has_episodes?(): tvcomID must be an integer." if !tvcomID.class==Fixnum
		episodes=[]
		return {} unless $Use_Mysql
		printf "db_has_episodes?(): Getting episodes for tvcomID:'#{tvcomID}' \n"
		result={}
		begin
			$dbh= DBI.connect("DBI:Mysql:#{$Database_name}:#{$Database_host}", $Database_user, $Database_password)

			rez= $dbh.execute "SELECT * FROM Episodes WHERE tvcomID='#{tvcomID}'"
			arry=[]
			columns=rez.column_names
			rowNum=0
			while row=rez.fetch
				count=0
				row.each {|item|
					arry[rowNum]||={}
					arry[rowNum].merge!( columns[count] => item )
					count=count+1
				}
				rowNum=rowNum+1
			end
			
			unless arry.empty?
				arry.each {|ep|
					episode={}
					ep.each_key {|attr_name|
						episode[attr_name]=FALSE unless attr_name.match(/dateadded/i) or attr_name.match(/uid/i) or attr_name.match(/tvcomID/i)
						next if ep[attr_name].nil? or attr_name.match(/dateadded/i) or attr_name.match(/uid/i) or attr_name.match(/tvcomID/i)
 
						case attr_name
							when 'EpName'
								episode[attr_name]=ep[attr_name]
							when 'EpRating'
								episode[attr_name]=ep[attr_name]
							when 'Aired'
								#Convert to DateTime from DBI:Timestamp
								begin
									episode[attr_name]=DateTime.parse(ep[attr_name].to_s)
								rescue ArgumentError => e
									raise $! unless e.to_s.match(/invalid date/i)
									puts "db_has_episode?(): Invalid Date for '#{ep['EpName']}' in tvcomID '#{tvcomID}', cleansing."
									episode[attr_name]=FALSE
							end
							when 'Summary'
								episode[attr_name]=ep[attr_name]
							when 'Season'
								episode[attr_name]=ep[attr_name]
							when 'EpNum'
								episode[attr_name]=ep[attr_name]
						end
					}
					episodes << episode
				}
			end
		end
		return episodes
	end

	#Look in database for actor
	#This functio does NOT populate the actor database, it will only return results already in the database
	#The only way actor biographies are populated is when a search is performed
	#Takes the actor's name, and will check for that in Name, and if no results are found, will also search AKA
	def self.db_has_bio?(name)
		return {} unless $Use_Mysql

		return {}
	end

	def self.store_bio_in_db(actor)
		return 0 unless $Use_Mysql

		return 0
	end

	#This function takes a series hash, and stores it in the database after first removing the old entry
	#It is intended to be run from populate_results()
	def self.store_series_in_db(series)
		return 0 unless $Use_Mysql
		#sanity check the series
		if series.class==Hash
			if series['Details'].class==Hash
				if !series['Details']['Status'].class==String || !series['Details']['Status'].class==FalseClass
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['Details']['Originally on'].class==String || !series['Details']['Originally on'].class==FalseClass
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['Details']['Show score'].class==String || !series['Details']['Show score'].class==FalseClass
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['Details']['Premiered'].class==String || !series['Details']['Premiered'].class==FalseClass
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['Details']['Title'].class==String || !series['Details']['Title'].class==FalseClass
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['Details']['Summary'].class==String || !series['Details']['Summary'].class==FalseClass
					raise "store_series_in_db(): OMg bad args!!!!!!"				
				end
				if !series['Details']['Show Categories'].class==String || !series['Details']['Show Categories'].class==FalseClass
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['Details']['Last Aired'].class==FalseClass || !series['Details']['Last Aired'].class==DateTime
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['series_details_url'].class==String || !series['series_details_url'].class==FalseClass
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['Episodes'].class==Array
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				if !series['Episodes'][0].class==Hash
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
				unless series['Episodes'].empty?
					series['Episodes'].each {|episode|
						if !episode['EpName'].class==String || !episode['EpName'].class==FalseClass
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
						if !episode['EpRating'].class==String || !episode['EpRating'].class==FalseClass
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
						if !episode['Aired'].class==String || !episode['Aired'].class==FalseClass
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
						if !episode['Summary'].class==String || !episode['Summary'].class==FalseClass
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
						if !episode['Season'].class==String || !episode['Season'].class==FalseClass
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
						if !episode['EpNum'].class==String || !episode['EpNum'].class==FalseClass
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
					}
				end
				unless series['Credits'].empty?
					series['Credits'].each {|person|
						if !person['Role'].class==String
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
						if !person['Name'].class==String
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
						if !person['Propriety'].class==String
							raise "store_series_in_db(): OMg bad args!!!!!!"
						end
					}
				end
				if !series['tvcomID'].class==String
					raise "store_series_in_db(): OMg bad args!!!!!!"
				end
			else
				raise "store_series_in_db(): OMg bad args!!!!!!"
			end
		else
			raise "store_series_in_db(): OMg bad args!!!!!!"
		end
		
		begin
			DateTime.parse(series['Details']['Premiered'].to_s)
		rescue ArgumentError => e
			raise $! unless e.to_s.match(/invalid date/i)
			series['Details']['Premiered']=FALSE
		end
		begin
			DateTime.parse(series['Details']['Last Aired'].to_s)
		rescue ArgumentError => e
			raise $! unless e.to_s.match(/invalid date/i)
			series['Details']['Last Aired']=FALSE
		end
		printf "store_series_in_db(): Storing ..."	
		sql_String='INSERT INTO Series_Details (Title, Status, Originally_On, Show_Score, Premiered, Last_Aired, Summary, Show_Categories, tvcomID, DateAdded, series_details_url) '
		sql_String << 'VALUES ('
		pp series['Details']['Title'] unless series['Details']['Title'].class==String
		sql_String << "'#{Mysql.escape_string(series['Details']['Title'])}', "
		series['Details']['Status'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Status'])}', "
		series['Details']['Originally on'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Originally on'])}', "
		series['Details']['Show score'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Show score'])}', "
		series['Details']['Premiered'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{DateTime.parse(series['Details']['Premiered'].to_s)}', "
		series['Details']['Last Aired'].class==DateTime ? sql_String << "'#{series['Details']['Last Aired'].to_s}', " : sql_String << "NULL, "
		series['Details']['Summary'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Summary'])}', "
		series['Details']['Show Categories'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Show Categories'])}', "
		sql_String << "'#{Mysql.escape_string(series['tvcomID'])}', "
		sql_String << "NOW(), "
		sql_String << "'#{Mysql.escape_string(series['series_details_url'])}')"

		TvDotComScraper.sql_do("DELETE FROM Series_Details WHERE tvcomID='#{Mysql.escape_string(series['tvcomID'])}'")
		effected= TvDotComScraper.sql_do(sql_String)

		series['Episodes'].each {|episode|
			sql_String="INSERT INTO Episodes (tvcomID, EpName, EpRating, Aired, Season, Summary, EpNum, DateAdded) VALUES ("
			sql_String << "'#{series['tvcomID']}', "
			episode['EpName'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(episode['EpName'])}', "
			episode['EpRating'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(episode['EpRating'])}', "
			(episode['Aired'].class==FalseClass||episode['Aired'].class==String and episode['Aired'].empty?) ? sql_String << "NULL, " : sql_String << "'#{DateTime.parse(episode['Aired'].to_s).to_s}', "
			sql_String << "'#{episode['Season']}', "
			episode['Summary'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(episode['Summary'])}', "
			episode['EpNum'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(episode['EpNum'])}', "
			sql_String << "NOW())"
			TvDotComScraper.sql_do sql_String
		}

		#duplicate credits entries have been found in the past
		#This is here solely for the removal of duplicated credit entries, if you can simplify it please by all means, do so (And cc me?)
		#Note this was written with 1.8.6, .uniq would work if this was 1.8.7
		series['Credits'].each_index {|credits_index|
			series['Credits'][credits_index]['sha1']=''
			series['Credits'][credits_index]['sha1']=hash_filename(series['Credits'][credits_index]['Name'] + series['Credits'][credits_index]['Role'] + series['tvcomID'])
		}
		cast={}
		series['Credits']=series['Credits'].delete_if {|person|
			!cast[person['sha1']]= person unless cast.has_key? person['sha1']
#			cast.has_key? person['sha1']
		}
		
		cast.each {|person|
			sql_String="INSERT INTO Cast_and_Crew (tvcomID, Name, Role, Propriety, DateAdded) VALUES ("
			sql_String << " '#{series['tvcomID']}', "
			sql_String << " '#{Mysql.escape_string(person[1]['Name'])}', "
			sql_String << " '#{Mysql.escape_string(person[1]['Role'])}', "
			sql_String << " #{person[1]['Propriety']}, "
			sql_String << " NOW() )"
			TvDotComScraper.sql_do sql_String
		}

		printf " Done\n"
		return effected
	end
end

