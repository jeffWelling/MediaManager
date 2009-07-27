load 'MMCommon.rb'
require 'xmlsimple'
require 'erb' #Required to encode to url - Line20
require 'digest/sha1'
require 'open-uri'

module MediaManager
	module MM_TVDB
		extend MMCommon
		def self.searchTVDB name
			puts "searchTVDB(): Searching for '#{name}'"
			results=''
			name_hash = Digest::SHA1.hexdigest(name.downcase)

			if $TVDB_CACHE.has_key?(name_hash)
				results= $TVDB_CACHE[name_hash]
				puts "searchTVDB(): #{name} already cached"
			else
				#cause the thetvdb.com programmers api said so?    but still, wtf?	
				unless $MMCONF_TVDB_MIRROR then
					mirrors_xml = XmlSimple.xml_in agent.get("http://www.thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/mirrors.xml").body
					$MMCONF_TVDB_MIRROR= mirrors_xml['Mirror'][0]['mirrorpath'][0]
				end
			
				begin
					$TVDB_CACHE.merge!( name_hash => XmlSimple.xml_in( agent.get("#{$MMCONF_TVDB_MIRROR}/api/GetSeries.php?seriesname=#{ERB::Util.url_encode name}").body ))
				rescue Timeout::Error => e
					puts e
					r= prompt( "Timeout occured, Retry or Quit?", :Retry, nil, [:yes, :no])
					raise :quit if r==:quit
					retry			
				rescue Errno::ETIMEDOUT => e
					puts e
					r= prompt( "Timeout occured, Retry or Quit?", :Retry, nil, [:yes, :no])
					raise :quit if r==:quit
					retry
				end

				results=$TVDB_CACHE[name_hash]
			end

			return '' if results.empty?
			return formatTvdbResults( results )

		end

		#Format results from TVDB
		#return a hash with the parts we store in the database.
		def self.formatTvdbResults( tvdb_results )
			raise "formatTvdbResults() is not supposed to deal with nil results, sort that out first." if tvdb_results.nil?
			results=[]
			tvdb_results['Series'].each_index {|i| tvdb_results['Series'][i].each_key {|item|
			  results[i]||={}
				results[i]['tvdbSeriesID'] = \
					tvdb_results['Series'][i][item] if item=='id'
				results[i]['imdbID'] = \
					tvdb_results['Series'][i][item] if item=='IMDB_ID'
				results[i]['Title'] = \
					tvdb_results['Series'][i][item] if item=='SeriesName'
			}}
			results.each_index {|i|
				results[i]['EpisodeList']= getAllEpisodes(results[i]['tvdbSeriesID'])
			}
			return results
		end
		
		def self.getAllEpisodes( series_id, no_cache=FALSE )
			raise "getAllEpisodes() only takes series_id" if series_id.nil?
			puts "Getting all episodes for #{series_id}"
			episode_list=[]

			unless no_cache
				expired=FALSE
				sql_results= sqlSearch("SELECT * FROM EpisodeCache WHERE SeriesID = '#{series_id}'")
				sql_results.each {|episode|
					episode_list<<{'EpisodeName'=>episode['EpisodeName'], 'EpisodeID'=>"S#{episode['Season']}E#{episode['EpisodeNumber']}" } unless DateTime.parse(episode['DateAdded'].to_s) < DateTime.now.-(3)

					expired=TRUE if DateTime.parse(episode['DateAdded'].to_s) < DateTime.now.-(3)
				}
				if expired
					puts "Cached episodes for #{series_id} have expired, deleting"
					sqlAddUpdate "DELETE FROM EpisodeCache WHERE SeriesID = #{series_id}"
					episode_list=[]
				end
				puts "getAllEpisodes(): #{series_id} from cache." unless episode_list.empty?
				return episode_list unless episode_list.empty?
			end

			regex=/<a href="[^"]*" class="seasonlink">All<\/a>/
			cache=[]
			all_ep_url=''
			#open(url).read.match(match)[0]

			#Dynamically scrape the page and get the 'allepisode' link.  Store so as to not DoS their server.			
			cache = sqlSearch( "SELECT * FROM #{$EpisodeURLTable} WHERE SeriesID = '#{series_id}'" ) #FIXME Sanitize series_id!
			if cache.empty? or no_cache==TRUE
				#Get new episodeURL
				sleep 1
				all_ep_url=open("http://thetvdb.com/?tab=series&id=#{series_id}&lid=7").read.match(regex)[0]
				raise "Problem scraping tvdb.com for allEpisode link!" if all_ep_url.empty?
				sqlAddUpdate( "INSERT INTO TvdbSeriesEpisodeCache (DateAdded, SeriesID, allEpisodeURL) VALUES(NOW(), '#{series_id}', '#{all_ep_url}');" ) unless (cache.empty?)!=TRUE  #FIXME Should update the entry
			else
				all_ep_url=cache[0]['allEpisodeURL']
			end
			all_ep_url=all_ep_url.match( /href="[^"]*"/ )[0].chop.slice( all_ep_url.index('"')-2, all_ep_url.length)
			
			##BEGIN NEW AREA
			episode_list=[]
			#TheTVDB runs slow on weekends soemtimes, dont want to crash fail, retry instead
			begin
				body= XmlSimple.xml_in( MediaManager.agent.get("http://thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/series/#{series_id}/all/en.xml").body )
			rescue Timeout::Error => e
				puts e
				r= prompt( "Timeout occured, Retry or Quit?", :Retry, nil, [:yes, :no])
				raise :quit if r==:quit
				retry			
			rescue Errno::ETIMEDOUT => e
				puts e
				r= prompt( "Timeout occured, Retry or Quit?", :Retry, nil, [:yes, :no])
				raise :quit if r==:quit
				retry
			end

			if body.has_key?('Episode')!=TRUE
				#has no episodeS?
				puts "#{series_id} has no episodes?"
				return []
			end

			body['Episode'].each {|episode|
				episode['EpisodeName'][0]='' if episode['EpisodeName'][0].class==Hash
				episode_list << { 
					'EpisodeName' => episode['EpisodeName'][0], 
					'EpisodeNumber' => episode['EpisodeNumber'][0],
					'Season' => episode['SeasonNumber'][0],
					'SeriesID' => body['Series'][0]['id'][0],
					'EpisodeID' => 'S' << episode['SeasonNumber'][0] \
						<< 'E' << episode['EpisodeNumber'][0]
				}
			}
			cacheEpisodes(episode_list)
			return episode_list
			##END NEW AREA
		end

		def self.cacheEpisodes episode_list
			seriesID=episode_list[0]['SeriesID']
			printf "\nCaching #{seriesID} "
			#Put each episode in the cache
			episode_list.each_index {|i|
				#Get rid of the '>' and '<' from the ends of the EpisodeName
				sqlStr= "SELECT uid FROM EpisodeCache WHERE SeriesID='#{seriesID}' AND " \
					"Season='#{episode_list[i]['EpisodeID'].match(/S[\d]+/)[0].reverse.chop.reverse}' AND "\
					"EpisodeNumber='#{episode_list[i]['EpisodeID'].match(/E[\d]+/)[0].reverse.chop.reverse}' AND "\
					"EpisodeName='#{Mysql.escape_string(episode_list[i]['EpisodeName'])}'"
				exist= sqlSearch(sqlStr)
				
				printf '_' if exist.empty? != TRUE
				if exist.empty? != TRUE
					pp exist
					raise 'panix'
				end
				printf '-' if exist.empty?

				#puts "getAllEpisodes: Not adding duplicate episode #{seriesID} #{episode_list[i]['EpisodeID']}" unless exist.empty?
				#puts "getAllEpisodes: Caching #{seriesID} #{episode_list[i]['EpisodeID']}" if exist.empty?
				sqlStr= "INSERT INTO EpisodeCache (EpisodeName, EpisodeNumber, Season, SeriesID, DateAdded) VALUES " \
					<< "('#{Mysql.escape_string(episode_list[i]['EpisodeName'])}', " \
					<< "'#{episode_list[i]['EpisodeID'].match(/E[\d]*/)[0].reverse.chop.reverse}', " \
					<< "'#{episode_list[i]['EpisodeID'].match(/S[\d]*/)[0].reverse.chop.reverse}', '#{seriesID}', NOW())" \
					if exist.empty?

				sqlAddUpdate(sqlStr) if exist.empty?
			}
			puts "Done Caching."
		end
		
	end
end

