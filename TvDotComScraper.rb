require 'rubygems'
require 'mechanize'
require 'dbi'
require 'mysql'
require 'timeout'

#another change
#OMG BRANCH LOOKATME IMA BRANCH
#Configuration variables
$Database_name='TvDotComScraperCache'
$Database_host='mysql.osnetwork'
$Database_user='TvDotCom'
$Database_password='omgrandom'
$anti_flood=2
$Use_Mysql=TRUE
$Sql_Check=TRUE
$Populate_Bios=TRUE

module TvDotComScraper
	#Custom added self. to every function because it wouldnt freaking work without it, and I dont feel like relearning methods and scopes this very second, if it bothers you then you fix it.
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
			when 'official site'
				return page_as_string.match(/#{key}\<.*?\>\<.*href=".+?"/i)[0].
					match(/href=".*?"$/)[0].
					gsub(/^href=/,'').chop.reverse.chop.reverse
			when 'show categories'
				return page_as_string.match(/#{key}\<.*?\<\/span>/i)[0].
					gsub(/show categories:/i, '').gsub(/\<.*?\>/, '')
			when 'summary'
				if page_as_string.match(/\<div class="summary long"\>\s+\<span class="long"\>.*?\<\/span\>/im)
					return page_as_string.match(/\<div class="summary long"\>\s+\<span class="long"\>.*?\<\/span\>/im)[0].gsub(/\<.*?\>/, '').strip
				else
					return FALSE
				end
			when 'show score'
				return page_as_string.match(/\<h\d\>Show Score\<\/h\d\>\s+?\<div.+?\<\/div\>\s+?<div class="global_score"\>.+?\<\/div\>/im)[0].
					gsub(/\<.+?\>/, '').match(/(\d){1,}\.(\d){1,}/)[0]
			when 'title'
				return page_as_string.match(/\<!--\/header_area--\>\s+?(\<div.+?\>\s+?){1,4}?(\<span.+?\<\/span\>\s+){1}?\<h\d\>.+?\<\/h\d\>/im)[0].
					match(/\<h\d\>.+?\<\/h\d\>$/i)[0].gsub(/\<.+?\>/, '')
			when 'originally on'
				pp 'OMGOMGOMG'
				bit=page_as_string.match(/\<span class="tagline"\>.+?\<\/span\>/im)[0]
				if bit[2].strip.empty?
					return bit[1].gsub(/\<.+?\>/, '').split("\n")[1].gsub(/\(.+?\)\s+$/, '').strip
				else
					return bit[2].strip
				end
		end
	pp key
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
#	pp body.match(top_result_regex)[0]
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
			info=0
			info=db_has_series?(search_results[results_i]['tvcomID'].to_i)
			search_results[results_i].merge!({ 'Details' => info['Details'] }) unless info.empty?
			search_results[results_i]['Episodes']=[]
			next unless info.empty?
			page_as_string=TvDotComScraper.get_page(search_results[results_i]['series_details_url'])
			episode_page_as_string=TvDotComScraper.get_page(page_as_string.match(/http:\/\/www\.tv\.com\/.+?\/show\/\d+?\/episode.html/i)[0])
			stars_page_as_string=TvDotComScraper.get_page(cast=page_as_string.match(/http:\/\/www\.tv\.com\/.+?\/show\/\d+?\/cast\.html/i)[0])
			recurring_page_as_string=TvDotComScraper.get_page(cast+'?flag=2')
			crew_page_as_string=TvDotComScraper.get_page(cast+'?flag=3')

			#Fill in the 'Details' part
			search_results[results_i]['Details']={}
			values=['Originally on', 'Status', 'Premiered', 'Last Aired', 'Show Categories', 'Official Site', 'Summary', 'Show score', 'Title']
			values.each {|attribute|
				search_results[results_i]['Details'][attribute]= TvDotComScraper.get_value_of(attribute, page_as_string)
			}

			#populate stars, recurring roles, and writers and directors
			stars_raw=stars_page_as_string.match(/\<h1 class="module_title"\>STARS\<\/h1\>(\s+)?(\<\/div\>\s+){2}?(\<div class=".*?"\>){2}?\s+\<ul\>(.[^\\\n]+)?/im)[0].split('<li')
			search_results[results_i]['Credits']=[]
			unless stars_raw[1].match(/there are currently no cast members./i)
				stars_raw.each_index {|stars_raw_i|
					next if stars_raw_i==0  #Skip first array element, junk entry containing html tags that we matched above
					actor={}
					name=stars_raw[stars_raw_i].match(/\<h3 class="name"\>(\<.+?\>)?.+?(\<.+?\>)?\<\/h3\>/i)[0].gsub(/\<.+?\>/,'')
					role=stars_raw[stars_raw_i].match(/\<div class="role"\>.+?\<\/div\>/i)[0].gsub(/\<.+?\>/, '')
					actor_bio_url=stars_raw[stars_raw_i].match(/\<h3 class="name"\>.+?\<\/h3\>/i)[0].
						match(/<a.+?\>/)[0].gsub(/^.+?"/, '').chop.chop
					actor={ 'Name' => name, 'Role' => role }
					if $Populate_Bios.class==TrueClass
						birthplace=''
						birthdate=''
						aka=''
						recent_role=''
						recent_role_series=''
						summary=''
						bio=TvDotComScraper.db_has_bio?(actor['Name'])
						unless bio.empty?
							#TODO
							#MERGE BIO INFO
						else
							#db_has_bio returned nothing, get bio
							actor_bio_page_string=TvDotComScraper.get_page(actor_bio_url)
							

						end
					end
				}
			end

			printf '=>>>'
			begin	
				allepisode_page_as_string=TvDotComScraper.agent(300).get(episode_page_as_string.match(/Other\<.+?\>\s+&nbsp;\s+\<.+?\>All/im)[0].
					match(/".+"/i)[0].chop.reverse.chop.reverse).body unless episode_page_as_string.match(/Other\<.+?\>\s+&nbsp;\s+\<.+?\>All/im).nil?
			rescue Timeout::Error => e
				retry if TvDotComScraper.deal_with_timeout(e)==TRUE
			rescue Errno::ETIMEDOUT => e
				retry if TvDotComScraper.deal_with_timeout(e)==TRUE
			end
			printf "<=   "

			#Fill in the episodes
			allepisode_page_as_string=episode_page_as_string if episode_page_as_string.match(/Other\<.+?\>\s+&nbsp;\s+\<.+?\>All/im).nil?
			episodes_raw=""
			episodes_raw=allepisode_page_as_string.match(/print episode guide.+?\<script type=\"text\/javascript"\>/im )[0].
				split('</li>') unless allepisode_page_as_string.match(/print episode guide.+?\<script type=\"text\/javascript"\>/im).nil?
			printf "[no-episodes] " if episodes_raw.empty?
			#next if episodes_raw.empty?
			unless episodes_raw.empty?
				episodes_raw.each {|episode_as_string|
					episode={}
					next if episode_as_string.gsub(/\<.*?\>/, '').strip.empty?
					#Season, Ep Number, and Ep Name
					first_bit=episode_as_string.match(/\<h\d class="title"\>.+?\<\/a\>\<\/h\d\>/im)[0].
						match(/^\<.+?\>.+?\<a.*?\>/i)[0]
					if first_bit.match(/season \d+/i)
						episode['Season']=first_bit.match(/season \d+/i)[0].
							match(/\d+/)[0]
					elsif first_bit.match(/pilot/i)
						printf "   WARNING: episode with no season, but could be pilot.  defaulting to season 1  --- "
						episode['Season']='1'
					end
					if first_bit.match(/Ep \d+/i)
						episode['EpNum']=first_bit.match(/Ep \d+/i)[0].
							match(/\d+/)[0]
					elsif first_bit.match(/pilot/i)
						pp first_bit
						if first_bit.gsub(/\<.+?\>/, '').match(/pilot/i)
							episode['EpNum']=first_bit.gsub(/\<.+?\>/, '').match(/pilot/i)[0]
						else 
							#'pilot' is in the html tags but not in text
							episode['EpNum']='Pilot'
						end
					elsif first_bit.match(/special/i)
						episode['EpNum']=first_bit.gsub(/\<.+?\>/, '').match(/special/i)[0]
					else
						episode['EpNum']='Special'
					end
					episode['EpName']=episode_as_string.match(/\<h\d class="title"\>.+?\<\/a\>\<\/h\d\>/im)[0].
						match(/\<a.+?\>.*?(\<.+?\>){2}/)[0].
						gsub(/^\<a.+?\>/, '').gsub(/(\<.+?\>){2}/, '')
					if episode_as_string.match(/\<span class="score"\>.+?\<\/span\>/)
						episode['EpRating']=episode_as_string.match(/\<span class="score"\>.+?\<\/span\>/)[0].
							gsub(/\<.+?\>/,'')
					else
						episode['EpRating']=FALSE
					end
					if episode_as_string.match(/\<\/p\>Aired:/)
						episode['Summary']=episode_as_string.match(/\<div class="info"\>\<p\>.*?\<\/p>Aired:/im)[0].
							gsub(/^(\<.*?\>){2}/, '').gsub(/\<\/p\>Aired:$/i, '')
						begin
							episode['Aired']=DateTime.parse(episode_as_string.match(/Aired: \<span.+?\>.+?$/)[0].
								gsub('Aired: ', '').gsub(/\<.+?\>/, ''))
						rescue ArgumentError => e
						printf "   WARNING: Invalid date detected.  Purged.   ---"
							episode['Aired']=FALSE
						end
					else
						episode['Summary']=episode_as_string.match(/\<div class="info"\>\<p\>.*?\<\/p>\<\/div\>/im)[0].
							gsub(/^(\<.*?\>){2}/, '').gsub(/\<\/p\>\<\/div\>$/i, '')
						episode['Aired']=''
					end

					next if episode['EpName'].match(/to be deleted/i)
					search_results[results_i]['Episodes'] << episode
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
			formatted_result={'Details'=> {}, 'Episodes'=>[]}
			attrs=['Status', 'Originally on', 'Show score', 'Premiered', 'Title', 'Summary', 'Show Categories', 'Last Aired', 'Official Site']
			unless arry.empty? 
				attrs.each {|attribute|
					attribute1='Originally_On'	if attribute.match(/originally on/i)
					attribute1='Show_Score' if attribute.match(/show score/i)
					attribute1='Show_Categories' if attribute.match(/show categories/i)
					attribute1='Official_Site' if attribute.match(/official site/i)
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
		sql_String='INSERT INTO Series_Details (Title, Status, Originally_On, Show_Score, Premiered, Last_Aired, Summary, Show_Categories, Official_Site, tvcomID, DateAdded, series_details_url) '
		sql_String << 'VALUES ('
		sql_String << "'#{Mysql.escape_string(series['Details']['Title'])}', "
		series['Details']['Status'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Status'])}', "
		series['Details']['Originally on'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Originally on'])}', "
		series['Details']['Show score'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Show score'])}', "
		series['Details']['Premiered'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{DateTime.parse(series['Details']['Premiered'].to_s)}', "
		series['Details']['Last Aired'].class==String ? sql_String << "'#{DateTime.parse(series['Details']['Last Aired']).to_s}', " : sql_String << "NULL, "
		series['Details']['Summary'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Summary'])}', "
		series['Details']['Show Categories'].class==FalseClass ? sql_String << "NULL, " : sql_String << "'#{Mysql.escape_string(series['Details']['Show Categories'])}', "
		series['Details']['Official Site'].class==String ? sql_String << "'#{Mysql.escape_string(series['Details']['Official Site'])}', " : sql_String << "NULL, "
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
		printf " Done\n"
		return effected
	end
end

