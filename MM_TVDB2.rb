$MMCONF_TVDB_APIKEY="722A9E49CA2070A2"
$cacheLifetime="30"

load 'MMCommon.rb'
require 'xmlsimple'
require 'erb'
require 'digest/sha1'
require 'open-uri'

def deal_with_timeout(e)
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

def agent(timeout=300)
	a = WWW::Mechanize.new
	a.read_timeout = timeout if timeout
	a.user_agent_alias= 'Mac Safari'
	a   
end
 
def sql_do( sqlString )
	begin
		$dbh  =  DBI.connect("DBI:Mysql:#{$MMCONF_MYSQL_DBASE}:#{$MMCONF_MYSQL_HOST}", $MMCONF_MYSQL_USER, $MMCONF_MYSQL_PASS)
		r = $dbh.do sqlString
	rescue
		$sql=sqlString
		raise $!
	ensure
		$dbh.disconnect if $dbh.connected?
	end
	return r
end

def sqlSearch(query)
	$dbh  =  DBI.connect("DBI:Mysql:#{$MMCONF_MYSQL_DBASE}:#{$MMCONF_MYSQL_HOST}", $MMCONF_MYSQL_USER, $MMCONF_MYSQL_PASS)
	rez = $dbh.execute query
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
	$dbh.disconnect if $dbh.connected?
	return arry
end

module MM_TVDB2
	def self.store_series_in_db(series)
		badargs="store_series_in_db(): Bad arguments."
		raise badargs unless series.class==Hash
		cols=['Status', 'Runtime', 'FirstAired', 'Genre', 'lastupdated', 'IMDB_ID', 'Title', 'Network', 'Overview', 'Rating', 'ContentRating', 'Actors', 'thetvdb_id']
		ep_cols=['Director', 'SeasonNumber', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'IMDB_ID', 'ProductionCode', 'Overview', 'Writer', 'EpisodeName']
		series['thetvdb_id']=series['thetvdb_id'].to_s
		cols.each {|col|
			raise "#{badargs + "   " + col + " : " + "#{series[col].class}" }" unless series[col].class==String or series[col].class==FalseClass
		}
		raise badargs unless series['Episodes'].class==Array
		series['Episodes'].each {|episode|
			raise badargs unless !episode.empty?
			ep_cols.each {|col|
				raise badargs unless episode[col].class==String or episode[col].class==FalseClass
			}
		}
		printf "store_series_in_db(): ... "
		count=0
		sql_do("DELETE FROM Tvdb_Series WHERE thetvdb_id='#{series['thetvdb_id']}'")
		sql_do("DELETE FROM Tvdb_Episodes WHERE thetvdb_id='#{series['thetvdb_id']}'")
		sql_string='INSERT INTO Tvdb_Series (Status, Runtime, FirstAired, Genre, lastupdated, IMDB_ID, Title, Network, Overview, Rating, ContentRating, Actors, thetvdb_id, DateAdded) VALUES ('
		columns=['Status', 'Runtime', 'FirstAired', 'Genre', 'lastupdated', 'IMDB_ID', 'Title', 'Network', 'Overview', 'Rating', 'ContentRating', 'Actors', 'thetvdb_id']
		begin
			series['FirstAired']=DateTime.parse(series['FirstAired']).to_s unless series['FirstAired'].class==FalseClass
		rescue ArgumentError => e
			raise $! unless e.to_s.match(/invalid date/i)
			series['FirstAired']=FALSE
		end

		columns.each {|col|
				series[col].class==FalseClass ? sql_string << "NULL, " : sql_string << "'#{Mysql.escape_string("#{series[col]}")}', "
		}
		sql_string << ' NOW() )'

		count += sql_do(sql_string).to_i
		sql_string='INSERT INTO Tvdb_Episodes (Director, SeasonNumber, GuestStars, FirstAired, EpisodeNumber, lastupdated, IMDB_ID, ProductionCode, Overview, Writer, EpisodeName, DateAdded) VALUES ('
		columns=['Director', 'SeasonNumber', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'IMDB_ID', 'ProductionCode', 'Overview', 'Writer', 'EpisodeName']

		series['Episodes'].each {|ep|
			sql_string="INSERT INTO Tvdb_Episodes (thetvdb_id, Director, SeasonNumber, GuestStars, FirstAired, EpisodeNumber, lastupdated, IMDB_ID, ProductionCode, Overview, Writer, EpisodeName, DateAdded) VALUES ( '#{series['thetvdb_id']}', "
			begin
				ep['FirstAired']=DateTime.parse(ep['FirstAired']).to_s unless ep['FirstAired'].class==FalseClass
			rescue ArgumentError => e
				raise $! unless e.to_s.match(/invalid date/i)
				ep['FirstAired']=FALSE
			end
		
			columns.each {|col|
				ep[col].class==FalseClass ? sql_string << "NULL, " : sql_string << "'#{Mysql.escape_string("#{ep[col]}")}', "
			}
			sql_string << " NOW())"
			count += sql_do(sql_string).to_i
		}
		puts "Done."
		return count

	end

	#This method is run only by the db_has_series?() method, when an 'expired' item is found
	#it gets all the thetvdb_ids from the database, and updates them all, pursuant to the API
	def self.update_db
		#Get the timestamp to use
		lastupdated=sqlSearch("SELECT * FROM Tvdb_lastupdated")[0]
		if lastupdated.class==Hash
			lastupdated=lastupdated['lastupdated']

		else
			#Have never done update before, update every series in the database and store the time.
			lastupdated=0
		end

		#If there is no lastupdated in the database, or the one in the database is more than 30 days old
		if lastupdated!=0
			#Do the update
			updates=XmlSimple.xml_in(agent.get("http://www.thetvdb.com/api/Updates.php?type=all&time=#{lastupdated}").body)
			$it=updates
			puts "Updating based on lastupdated."

		else
			##update every series in the database
			series=[]
			puts "Updating based on no lastupdated."
			sql_results=sqlSearch("SELECT thetvdb_id, Title FROM Tvdb_Series")
			$it=sql_results
			empty=MM_TVDB2.populate_results(sql_results, FALSE)
			puts "YAYOMGDONEUPDATING!"
			
		end
	end

	def self.db_has_series?(thetvdb_id)
		#Sanity check argument
		raise "db_has_series?(): Takes a string only, and it must be a thetvdb_id" unless thetvdb_id.class==Fixnum
		series={}

		$it1=series_cache=sqlSearch("SELECT * FROM Tvdb_Series WHERE thetvdb_id='#{thetvdb_id}'")
		$it2=series_eps_cache=sqlSearch("SELECT * FROM Tvdb_Episodes WHERE thetvdb_id='#{thetvdb_id}'")

		if DateTime.parse(series_cache['DateAdded'].to_s) < DateTime.now.-($cacheLifetime)
			#Series may be outdated, do update and if necessary redo sqlsearches
			
		end

		series_columns=['Status', 'Runtime', 'FirstAired', 'Genre', 'lastupdated', 'IMDB_ID', 'Title', 'Network', 'Overview', 'Rating', 'ContentRating', 'Actors', 'thetvdb_id', 'DateAdded']
		episode_columns=['Director', 'SeasonNumber', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'IMDB_ID', 'ProductionCode', 'Overview', 'Writer', 'EpisodeName', 'DateAdded']

		series_columns.each {|col|
			series[col]=FALSE
			if col.match(/firstaired/i) or col.match(/dateadded/i)
				series[col]=DateTime.parse(series_cache[col].to_s)
			else
				series[col]=series_cache[col].to_s unless series_cache[col].nil?
			end
		}
		
		series['Episodes']=[]
		series_eps_cache.each {|cached_ep|
			ep={}
			episode_columns.each {|col|
				ep[col]=FALSE unless col.match(/dateadded/i)
				if col.match(/firstaired/i) or col.match(/dateadded/i)
					ep[col]=DateTime.parse(cached_ep[col].to_s) unless col.match(/dateadded/i)
				else
					ep[col]=cached_ep[col].to_s
				end
			}
			series['Episodes'] << ep
		}

		return {}
	end

	def self.wipe_cache
		sql_do "TRUNCATE TABLE Tvdb_Series"
		sql_do "TRUNCATE TABLE Tvdb_Episodes"
	end

	def self.searchTVDB(name)
		$TVDB_search_cache||={}
 		raise "searchTVDB(): Only takes a string as an argument, and I hope I don't have to also tell you its the name your looking for..." unless name.class==String
		puts "searchTVDB(): Searching for '#{name}'"
		
		name_hash = Digest::SHA1.hexdigest(name.downcase)
		
		if $TVDB_search_cache.has_key? name_hash
			puts "searchTVDB(): '#{name}' cached"
			return $TVDB_search_cache
		end
	
		$TVDB_Mirror||= XmlSimple.xml_in(agent.get("http://www.thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/mirrors.xml").body)['Mirror'][0]['mirrorpath'][0]

		#To be used when adding new series to mysql
		$Time= XmlSimple.xml_in(agent.get("http://www.thetvdb.com/api/Updates.php?type=none").body)['Time'][0].to_i

		begin
			page= XmlSimple.xml_in( agent.get("#{$TVDB_Mirror}/api/GetSeries.php?seriesname=#{ERB::Util.url_encode name}").body )
		rescue Timeout::Error=>e
			retry if deal_with_timeout(e)==:retry
		rescue Errno::ETIMEDOUT=>e
			retry if deal_with_timeout(e)==:retry
		end

		search_results=[]
		page['Series'].each {|search_result|
			series={}
			series['thetvdb_id']=FALSE
			series['IMDB_ID']=FALSE
			series['Title']=FALSE
			series['thetvdb_id']=search_result['seriesid'][0].to_i
			series['IMDB_ID']=search_result['IMDB_ID'][0] if search_result.has_key? 'IMDB_ID'
			series['Title']=search_result['SeriesName'][0]
			search_results << series
		}
		
#		$it=$TVDB_search_cache
#		return $TVDB_search_cache[name_hash]
		puts "searchTVDB('#{name}'): Done."
		return search_results

	end

	#This function is called by the user on the search_results returned by the searchTVDB() defined above
	def self.populate_results(search_results, check_cache=TRUE)
		#Sanity check input
		populated_results=[]
		badargs="populate_results(): Argument MUST be a search result as returned from searchTVDB() method."
		raise "populate_results(): check_cache argument MUST be either true or false." unless check_cache.class==TrueClass or check_cache.class==FalseClass
		raise badargs unless search_results.class==Array
		raise "populate_results(): Was passed an empty arguments set?" if search_results.length==0
		search_results.each {|result|
			raise badargs if !result['Title'].class==String
			raise badargs if !result['thetvdb_id'].class==Fixnum
			raise badargs if result.has_key?('IMDB_ID') and !result['IMDB_ID'].class==String
		}
		puts "populate_results(): Processing #{search_results.length} items..."

		#Incase its not already there
		$TVDB_Mirror||= XmlSimple.xml_in(agent.get("http://www.thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/mirrors.xml").body)['Mirror'][0]['mirrorpath'][0]


		search_results.each {|result|
			#TODO Lookup info from SQL here, series details and episodes TODO#
			series={}
			series['Episodes']=[]
			cache={}
			cache=MM_TVDB2.db_has_series?(result['thetvdb_id']) if check_cache
			puts "populate_results('#{result['Title']}'): Already cached." unless cache.empty?
			return series.merge!(cache) unless cache.empty?
			
			printf "populate_results('#{result['Title']}'): "
			raw_info= XmlSimple.xml_in(agent.get("#{$TVDB_Mirror}/api/#{$MMCONF_TVDB_APIKEY}/series/#{result['thetvdb_id']}/all/en.xml").body )
			puts "Gotcha!"

			series.merge! result	
			result=raw_info
			series_columns=['Actors', 'Status', 'ContentRating', 'Runtime', 'Genre', 'FirstAired', 'lastupdated', 'Rating', 'Overview', 'Network', 'IMDB_ID']

			series_columns.each {|col|
				result['Series'][0][col][0].class==String ? series[col]=result['Series'][0][col][0] : series[col]=FALSE
			}
			
			episode_attributes=['SeasonNumber', 'Director', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'ProductionCode', 
				'IMDB_ID', 'Overview', 'Writer', 'EpisodeName' ]
			unless result['Episode'].nil?
			result['Episode'].each {|episode|
				ep={}
				episode_attributes.each {|atr|
					episode[atr][0].class==String ? ep[atr]=episode[atr][0] : ep[atr]=FALSE
				}
				series['Episodes'] << ep
			}					
			end
		
			populated_results << series
			MM_TVDB2.store_series_in_db(series)
		} #End search_results.each |result|
		return populated_results
	end
end
