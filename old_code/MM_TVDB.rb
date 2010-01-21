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
			nameHash = Digest::SHA1.hexdigest(name.downcase)

			if $TVDB_CACHE.has_key?(nameHash)
				results= $TVDB_CACHE[nameHash]
				puts "searchTVDB(): #{name} already cached"
			else
				#cause the thetvdb.com programmers api said so?    but still, wtf?	
				unless $MMCONF_TVDB_MIRROR then
					mirrors_xml = XmlSimple.xml_in agent.get("http://www.thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/mirrors.xml").body
					$MMCONF_TVDB_MIRROR= mirrors_xml['Mirror'][0]['mirrorpath'][0]
				end
			
				begin
					$TVDB_CACHE.merge!( nameHash => XmlSimple.xml_in( agent.get("#{$MMCONF_TVDB_MIRROR}/api/GetSeries.php?seriesname=#{ERB::Util.url_encode name}").body ))
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

				results=$TVDB_CACHE[nameHash]
			end

			return '' if results.empty?
			return formatTvdbResults( results )

		end

		#Format results from TVDB
		#return a hash with the parts we store in the database.
		def self.formatTvdbResults( tvdbResults )
			raise "formatTvdbResults() is not supposed to deal with nil results, sort that out first." if tvdbResults.nil?
			results=[]
			tvdbResults['Series'].each_index {|i| tvdbResults['Series'][i].each_key {|item|
			  results[i]||={}
				results[i]['tvdbSeriesID'] = \
					tvdbResults['Series'][i][item] if item=='id'
				results[i]['imdbID'] = \
					tvdbResults['Series'][i][item] if item=='IMDB_ID'
				results[i]['Title'] = \
					tvdbResults['Series'][i][item] if item=='SeriesName'
			}}
			results.each_index {|i|
				results[i]['EpisodeList']= getAllEpisodes(results[i]['tvdbSeriesID'])
			}
			return results
		end
		
		def self.getAllEpisodes( seriesID, noCache=FALSE )
			raise "getAllEpisodes() only takes seriesID" if seriesID.nil?
			puts "Getting all episodes for #{seriesID}"
			episodeList=[]

			unless noCache
				expired=FALSE
				sqlResults= sqlSearch("SELECT * FROM EpisodeCache WHERE SeriesID = '#{seriesID}'")
				sqlResults.each {|episode|
					episodeList<<{'EpisodeName'=>episode['EpisodeName'], 'EpisodeID'=>"S#{episode['Season']}E#{episode['EpisodeNumber']}" } unless DateTime.parse(episode['DateAdded'].to_s) < DateTime.now.-(3)

					expired=TRUE if DateTime.parse(episode['DateAdded'].to_s) < DateTime.now.-(3)
				}
				if expired
					puts "Cached episodes for #{seriesID} have expired, deleting"
					sqlAddUpdate "DELETE FROM EpisodeCache WHERE SeriesID = #{seriesID}"
					episodeList=[]
				end
				puts "getAllEpisodes(): #{seriesID} from cache." unless episodeList.empty?
				return episodeList unless episodeList.empty?
			end

			regex=/<a href="[^"]*" class="seasonlink">All<\/a>/
			cache=[]
			allEpisodeURL=''
			#open(url).read.match(match)[0]

			#Dynamically scrape the page and get the 'allepisode' link.  Store so as to not DoS their server.			
			cache = sqlSearch( "SELECT * FROM #{$EpisodeURLTable} WHERE SeriesID = '#{seriesID}'" ) #FIXME Sanitize seriesID!
			if cache.empty? or noCache==TRUE
				#Get new episodeURL
				sleep 1
				allEpisodeURL=open("http://thetvdb.com/?tab=series&id=#{seriesID}&lid=7").read.match(regex)[0]
				raise "Problem scraping tvdb.com for allEpisode link!" if allEpisodeURL.empty?
				sqlAddUpdate( "INSERT INTO TvdbSeriesEpisodeCache (DateAdded, SeriesID, allEpisodeURL) VALUES(NOW(), '#{seriesID}', '#{allEpisodeURL}');" ) unless (cache.empty?)!=TRUE  #FIXME Should update the entry
			else
				allEpisodeURL=cache[0]['allEpisodeURL']
			end
			allEpisodeURL=allEpisodeURL.match( /href="[^"]*"/ )[0].chop.slice( allEpisodeURL.index('"')-2, allEpisodeURL.length)
			
			##BEGIN NEW AREA
			episodeList=[]
			#TheTVDB runs slow on weekends soemtimes, dont want to crash fail, retry instead
			begin
				body= XmlSimple.xml_in( MediaManager.agent.get("http://thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/series/#{seriesID}/all/en.xml").body )
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
				puts "#{seriesID} has no episodes?"
				return []
			end

			body['Episode'].each {|episode|
				episode['EpisodeName'][0]='' if episode['EpisodeName'][0].class==Hash
				episodeList << { 
					'EpisodeName' => episode['EpisodeName'][0], 
					'EpisodeNumber' => episode['EpisodeNumber'][0],
					'Season' => episode['SeasonNumber'][0],
					'SeriesID' => body['Series'][0]['id'][0],
					'EpisodeID' => 'S' << episode['SeasonNumber'][0] \
						<< 'E' << episode['EpisodeNumber'][0]
				}
			}
			cacheEpisodes(episodeList)
			return episodeList
			episodeList=[]


			##END NEW AREA
		end

		def self.cacheEpisodes episodeList
			seriesID=episodeList[0]['SeriesID']
			printf "\nCaching #{seriesID} "
			#Put each episode in the cache
			episodeList.each_index {|i|
				#Get rid of the '>' and '<' from the ends of the EpisodeName
				sqlStr= "SELECT uid FROM EpisodeCache WHERE SeriesID='#{seriesID}' AND " \
					"Season='#{episodeList[i]['EpisodeID'].match(/S[\d]+/)[0].reverse.chop.reverse}' AND "\
					"EpisodeNumber='#{episodeList[i]['EpisodeID'].match(/E[\d]+/)[0].reverse.chop.reverse}' AND "\
					"EpisodeName='#{Mysql.escape_string(episodeList[i]['EpisodeName'])}'"
				exist= sqlSearch(sqlStr)
				
				printf '_' if exist.empty? != TRUE
				if exist.empty? != TRUE
					pp exist
					raise 'panix'
				end
				printf '-' if exist.empty?

				#puts "getAllEpisodes: Not adding duplicate episode #{seriesID} #{episodeList[i]['EpisodeID']}" unless exist.empty?
				#puts "getAllEpisodes: Caching #{seriesID} #{episodeList[i]['EpisodeID']}" if exist.empty?
				sqlStr= "INSERT INTO EpisodeCache (EpisodeName, EpisodeNumber, Season, SeriesID, DateAdded) VALUES " \
					<< "('#{Mysql.escape_string(episodeList[i]['EpisodeName'])}', " \
					<< "'#{episodeList[i]['EpisodeID'].match(/E[\d]*/)[0].reverse.chop.reverse}', " \
					<< "'#{episodeList[i]['EpisodeID'].match(/S[\d]*/)[0].reverse.chop.reverse}', '#{seriesID}', NOW())" \
					if exist.empty?

				sqlAddUpdate(sqlStr) if exist.empty?
			}
			puts "Done Caching."
		end
		
	end
end

