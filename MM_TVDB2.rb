$MMCONF_TVDB_APIKEY="722A9E49CA2070A2"
$cacheLifetime=30

require 'xmlsimple'
require 'erb'
require 'digest/sha1'
require 'open-uri'

module MediaManager
	module MM_TVDB2
		extend MMCommon
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

		def self.extract_ep_info(raw_ep)
			episode_attributes=['id', 'SeasonNumber', 'Director', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'ProductionCode', 
				'IMDB_ID', 'Overview', 'Writer', 'EpisodeName' ]
			ep={}
			episode_attributes.each {|atr|
				raw_ep[atr][0].class==String ? ep[atr]=raw_ep[atr][0] : ep[atr]=FALSE
			}
			return ep
		end

		def self.store_series(series)
			badargs="store_series(): Bad arguments."
			raise badargs unless series.class==Hash
			cols=['Status', 'Runtime', 'FirstAired', 'Genre', 'lastupdated', 'IMDB_ID', 'Title', 'Network', 'Overview', 'Rating', 'ContentRating', 'Actors', 'thetvdb_id']
			series['thetvdb_id']=series['thetvdb_id'].to_s

			#Series has no Title, should RARELY happen
			series['Title']='' if series['Title'].class==Hash
			puts "store_series(): CRITICAL WARNING - THIS SERIES HAS NO TITLE" if series['Title'].class==Hash

			cols.each {|col|
				raise "#{badargs + "   " + col + " : " + "#{series[col].class}" }" unless series[col].class==String or series[col].class==FalseClass
			}

			sqlAddUpdate("DELETE FROM Tvdb_Series WHERE thetvdb_id='#{series['thetvdb_id']}'")
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

			return sqlAddUpdate(sql_string).to_i
		end

		def self.store_ep_in_db(ep, thetvdb_series_id)
			sqlAddUpdate("DELETE FROM Tvdb_Episodes WHERE id='#{ep['id']}'")
			columns=['id', 'Director', 'SeasonNumber', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'IMDB_ID', 'ProductionCode', 'Overview', 'Writer', 'EpisodeName']
			sql_string="INSERT INTO Tvdb_Episodes (thetvdb_id, id, Director, SeasonNumber, GuestStars, FirstAired, EpisodeNumber, lastupdated, IMDB_ID, ProductionCode, Overview, Writer, EpisodeName, DateAdded) VALUES ( '#{thetvdb_series_id}', "

			columns.each {|col|
				if col.match(/firstaired/i)
					begin
						ep['FirstAired']=DateTime.parse(ep['FirstAired']).to_s unless ep['FirstAired'].class==FalseClass
					rescue ArgumentError => e
						raise $! unless e.to_s.match(/invalid date/i)
						ep['FirstAired']=FALSE
					end
				end
				ep[col]=999999 if col=='SeasonNumber' and ep[col].class==FalseClass
				ep[col].class==FalseClass ? sql_string << "NULL, " : sql_string << "'#{Mysql.escape_string("#{ep[col]}")}', "
			}
			sql_string << " NOW())"
			return sqlAddUpdate(sql_string).to_i
		end


		def self.store_series_in_db(series)
			badargs="store_series_in_db(): Bad arguments."
			raise badargs unless series.class==Hash
			cols=['Status', 'Runtime', 'FirstAired', 'Genre', 'lastupdated', 'IMDB_ID', 'Title', 'Network', 'Overview', 'Rating', 'ContentRating', 'Actors', 'thetvdb_id']
			ep_cols=['id', 'Director', 'SeasonNumber', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'IMDB_ID', 'ProductionCode', 'Overview', 'Writer', 'EpisodeName']
			series['thetvdb_id']=series['thetvdb_id'].to_s
			#Series has no Title, should RARELY happen
			series['Title']='' if series['Title'].class==Hash
			puts "store_series(): CRITICAL WARNING - THIS SERIES HAS NO TITLE" if series['Title'].class==Hash
			cols.each {|col|
				raise "#{badargs + "   " + col + " : " + "#{series[col].class}" }" unless series[col].class==String or series[col].class==FalseClass
			}
			raise badargs unless series['Episodes'].class==Array
			series['Episodes'].each {|episode|
				raise badargs unless !episode.empty?
				ep_cols.each {|col|
					raise badargs unless episode.has_key?(col) and episode[col].class==String or episode[col].class==FalseClass
				}
			}
			printf "store_series_in_db(): ... "
			count=0
			sqlAddUpdate("DELETE FROM Tvdb_Series WHERE thetvdb_id='#{series['thetvdb_id']}'")
			sqlAddUpdate("DELETE FROM Tvdb_Episodes WHERE thetvdb_id='#{series['thetvdb_id']}'")

			count += store_series(series)		
			series['Episodes'].each {|ep|
				count += store_ep_in_db(ep, series['thetvdb_id'])
			}
			puts "Done."
			return count
		end

		#This method is run only by the db_has_series?() method, when an 'expired' item is found or
		#from the populate_results() method, to make sure the results we are pulling are up to date
		#it gets all the thetvdb_ids from the database, and updates them all, pursuant to the API
		def self.update_db(err=:no)
			url=''
			begin
			url="http://www.thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/mirrors.xml"
			$TVDB_Mirror||= XmlSimple.xml_in(agent.get(url).body)['Mirror'][0]['mirrorpath'][0]
			#Get the timestamp to use
			lastupdated=sqlSearch("SELECT * FROM Tvdb_lastupdated")[0]
			if lastupdated.class==Hash
				lastupdated_DateAdded=DateTime.now.-(9999)
				lastupdated_DateAdded=DateTime.parse(lastupdated['DateAdded'].to_s) unless lastupdated['DateAdded'].nil?
				lastupdated=lastupdated['lastupdated']

				#DateTime.now - 15 = 15Days in the past
				if DateTime.now.-(15) > DateTime.parse(lastupdated_DateAdded.to_s.gsub(/.\d\d:\d\d$/i,''))
					puts "update_db(): Last update was too long ago, updating everything."
					lastupdated=0
				end
			else
				#Have never done update before, update every series in the database and store the time.
				lastupdated=0
			end

			#If there is no lastupdated in the database, or the one in the database is more than 15 days old
			if lastupdated!=0
				#900 = (60Secs in a minute * 15 minutes)
				#the gsub below is supposed to remove the timezone info from the DateTimes
				halfHourAgo= DateTime.parse(DateTime.parse(Time.now.-(300).to_s).to_s.gsub(/.\d\d:\d\d$/i,''))
				wen_lastupdated= DateTime.parse(lastupdated_DateAdded.to_s.gsub(/.\d\d:\d\d$/i,''))
				#pp fiveMinAgo.to_s
				#pp wen_lastupdated.to_s
				#pp lastupdated_DateAdded
				if wen_lastupdated > halfHourAgo
					puts "update_db(): Already updated less than 30 minutes ago."
					return 0
				end
				#Do the update
				puts "update_db(): Updating based on lastupdated."
				url="http://www.thetvdb.com/api/Updates.php?type=all&time=#{lastupdated}"
				updates=XmlSimple.xml_in(agent.get(url).body)
				raise "NOTIME!!!" unless updates.has_key? 'Time'
				(lastupdated=0 and break) if (updates.has_key? 'Series' and updates['Series'].length == 1000)
				(lastupdated=0 and break) if (updates.has_key? 'Episode' and updates['Episode'].length == 1000)
				return 0 unless updates.has_key?('Series') or updates.has_key?('Episode')
				series_columns=['Actors', 'Status', 'ContentRating', 'Runtime', 'Genre', 'FirstAired', 'lastupdated', 'Rating', 'Overview', 'Network', 'IMDB_ID']
				puts "update_db():  Number of series/episodes to update and number of '.' printed may differ.  See source for info."
				#The '.' denotes an item that was ^actually^ updates, whereas the line that prints the number of series to update
				#prints the total number of series that have changed not just the ones that have changed that we have.
				if updates.has_key? 'Series'
					printf "update_db(): Updating #{updates['Series'].length} series; "
					updates['Series'].each {|seriesID|
						next unless sqlSearch("SELECT 'thetvdb_id' FROM Tvdb_Series WHERE thetvdb_id='#{seriesID}'").empty?
						series={}
						url="#{$TVDB_Mirror}/api/#{$MMCONF_TVDB_APIKEY}/series/#{seriesID}/en.xml"
						raw_series_xml=XmlSimple.xml_in(agent.get(url).body)
						series['Title']=raw_series_xml['Series'][0]['SeriesName'][0]
						series['thetvdb_id']=raw_series_xml['Series'][0]['id'][0]
						
						series_columns.each {|col|
							raw_series_xml['Series'][0][col][0].class==String ? series[col]=raw_series_xml['Series'][0][col][0] : series[col]=FALSE
						}
						store_series(series)
						printf '.'
					}
					printf "\n"
					puts "update_db(): Done updating series."
				end

				if updates.has_key? 'Episode' 
					printf "update_db(): Updating #{updates['Episode'].length} episodes; "
					updates['Episode'].each {|ep_id|
						next unless sqlSearch("SELECT 'id' FROM Tvdb_Episodes WHERE id='#{ep_id}'").empty?
						episode=[]
						begin
							url="#{$TVDB_Mirror}/api/#{$MMCONF_TVDB_APIKEY}/episodes/#{ep_id}/en.xml"
							ep_as_xml=XmlSimple.xml_in(agent.get(url).body)
						rescue
							pp url
							puts "update_db(): ERROR during processing/getting the above link"
							raise PANIC
						end
						store_ep_in_db(extract_ep_info(ep_as_xml['Episode'][0]), ep_as_xml['Episode'][0]['seriesid'][0] )
						printf "."
					}
					printf "\n"
					puts "update_db(): Done updating episodes."
				end
				time=updates['Time']
			end
			
			if lastupdated==0
				##update every series in the database
				series=[]
				puts "update_db(): Updating based on no lastupdated."
				url="http://www.thetvdb.com/api/Updates.php?type=none"
				time=XmlSimple.xml_in(agent.get(url).body)['Time'][0]
				sql_results=sqlSearch("SELECT thetvdb_id, Title FROM Tvdb_Series")
				#if sql_results.length == 0 than there are no series in the database yet, therefor nothing to update.
				MM_TVDB2.populate_results(sql_results, FALSE, FALSE) unless sql_results.length==0
			end
			sqlAddUpdate("TRUNCATE TABLE Tvdb_lastupdated")
			sqlAddUpdate("INSERT INTO Tvdb_lastupdated (lastupdated, DateAdded) VALUES ('#{time}', NOW())")
			puts "update_db(): Done."
			rescue => e
				if e.to_s.match(/404/) #The expected failure that happens once in awhile
					if err==:no
						puts "\nupdate_db(): Update Failed! If this is the first (couple) times you've seen this, ignore it for ~1 hour."
						return
					else
						pp url
						raise $!
					end
				else #Hm, irregular failure
					raise $!
				end
			end
		end

		def self.db_has_series?(thetvdb_id)
			#Sanity check argument
			raise "db_has_series?(): Takes a Fixnum only, and it must be a thetvdb_id" unless thetvdb_id.class==Fixnum
			series={}

			series_cache=sqlSearch("SELECT * FROM Tvdb_Series WHERE thetvdb_id='#{thetvdb_id}'")
			series_eps_cache=sqlSearch("SELECT * FROM Tvdb_Episodes WHERE thetvdb_id='#{thetvdb_id}'")

			#There is some kind of bug that results in series_cache sometimes being an array with the part we want at the first element
			if series_cache.class==Array
				series_cache=series_cache[0]
			end

			if series_cache.nil? or series_cache.empty?
				return {}
			else
				if DateTime.parse(series_cache['DateAdded'].to_s) < DateTime.now.-($cacheLifetime)
					#Series may be outdated, do update and if necessary redo sqlsearches
					raise "db_has_series?(): expired episode found, FIXME!"
				end
			end

			series_columns=['Status', 'Runtime', 'FirstAired', 'Genre', 'lastupdated', 'IMDB_ID', 'Title', 'Network', 'Overview', 'Rating', 'ContentRating', 'Actors', 'thetvdb_id', 'DateAdded']
			episode_columns=['id', 'Director', 'SeasonNumber', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'IMDB_ID', 'ProductionCode', 'Overview', 'Writer', 'EpisodeName', 'DateAdded']

			series_columns.each {|col|
				series[col]=FALSE
				if col.match(/firstaired/i) or col.match(/dateadded/i)
					begin
						series[col]=DateTime.parse(series_cache[col].to_s)
					rescue ArgumentError => e
						raise $! unless e.to_s.match(/invalid date/i)
						raise $! unless series_cache[col].to_s
					end
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
						begin
							ep[col]=DateTime.parse(cached_ep[col].to_s) unless col.match(/dateadded/i)
						rescue ArgumentError => e
							raise $! unless e.to_s.match(/invalid date/i)
							raise $! unless cached_ep[col].nil?
							ep[col]=FALSE
						end
					else
						ep[col]=cached_ep[col].to_s
					end
				}
				series['Episodes'] << ep
			}

			return series
		end

		def self.wipe_cache
			sqlAddUpdate "TRUNCATE TABLE Tvdb_Series"
			sqlAddUpdate "TRUNCATE TABLE Tvdb_Episodes"
			sqlAddUpdate "TRUNCATE TABLE Tvdb_lastupdated"
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
			begin
				number_of_times ||=0
				$Time= XmlSimple.xml_in(agent.get("http://www.thetvdb.com/api/Updates.php?type=none").body)['Time'][0].to_i
			rescue
				number_of_times+= 1
				retry if number_of_times < 5
				raise $!
			end

			begin
				page= XmlSimple.xml_in( agent.get("#{$TVDB_Mirror}/api/GetSeries.php?seriesname=#{ERB::Util.url_encode name}").body )
			rescue Timeout::Error=>e
				retry if deal_with_timeout(e)==:retry
			rescue Errno::ETIMEDOUT=>e
				retry if deal_with_timeout(e)==:retry
			end

			search_results=[]
			if page['Series'].nil?
				puts "searchTVDB('#{name}'): Done."
				return []
			end
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
			
			puts "searchTVDB('#{name}'): Done."
			return search_results

		end

		#This function is called by the user on the search_results returned by the searchTVDB() defined above
		def self.populate_results(search_results, check_cache=TRUE, updatedb=TRUE)
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
			if updatedb
				puts "populate_results(): Calling update_db() first."
				MM_TVDB2.update_db
			end
			puts "populate_results(): Processing #{search_results.length} items..."
			#Incase its not already there 
			$TVDB_Mirror||= XmlSimple.xml_in(agent.get("http://www.thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/mirrors.xml").body)['Mirror'][0]['mirrorpath'][0]


			search_results.each {|result|
				#TODO Lookup info from SQL here, series details and episodes TODO#
				series={}
				series['Episodes']=[]
				cache={}

				#Check the cache, return if found
				cache=MM_TVDB2.db_has_series?(result['thetvdb_id']) if check_cache
				unless cache.empty?
					puts "populate_results('#{result['Title']}'): Already cached."
					series.merge!(cache)
					populated_results << series
					next
				end
				
				printf "populate_results('#{result['Title']}'): "
				raw_info= XmlSimple.xml_in(agent.get("#{$TVDB_Mirror}/api/#{$MMCONF_TVDB_APIKEY}/series/#{result['thetvdb_id']}/all/en.xml").body )			
				puts "Gotcha!"

				series.merge! result	
				result=raw_info
				series_columns=['Actors', 'Status', 'ContentRating', 'Runtime', 'Genre', 'FirstAired', 'lastupdated', 'Rating', 'Overview', 'Network', 'IMDB_ID']

				series_columns.each {|col|
					result['Series'][0][col][0].class==String ? series[col]=result['Series'][0][col][0] : series[col]=FALSE
				}
				result['Series'][0]['SeriesName'][0].class==String ? series['Title']=result['Series'][0]['SeriesName'][0] : series['Title']=FALSE
				
				episode_attributes=['id', 'SeasonNumber', 'Director', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'ProductionCode', 
					'IMDB_ID', 'Overview', 'Writer', 'EpisodeName' ]
				unless result['Episode'].nil?
				result['Episode'].each {|episode|
					series['Episodes'] << extract_ep_info(episode)
				}					
				end
			
				populated_results << series
				MM_TVDB2.store_series_in_db(series)
			} #End search_results.each |result|
			return populated_results
		end
	end
end
