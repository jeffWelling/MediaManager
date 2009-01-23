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
			
				$TVDB_CACHE.merge!( nameHash => XmlSimple.xml_in( agent.get("#{$MMCONF_TVDB_MIRROR}/api/GetSeries.php?seriesname=#{ERB::Util.url_encode name}").body ))

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
			episodeList=[]

			unless noCache
				sqlResults= sqlSearch("SELECT Season, EpisodeNumber, EpisodeName FROM EpisodeCache WHERE SeriesID = '#{seriesID}'")
				sqlResults.each {|episode|
					episodeList<<{'EpisodeName'=>episode['EpisodeName'], 'EpisodeID'=>"S#{episode['Season']}E#{episode['EpisodeNumber']}" }
				}
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
			sleep 1    #Be nice to the poor web server (Dont DOS)
			epTable= open("http://thetvdb.com"<<allEpisodeURL).read.gsub("\n", ' ').match( /id="listtable".*<\/table>[\s]*<\/div>[\s]*<div/m )
			#That regex took me soo long to get right.  It locks onto the beginning of the list of episodes by looking for the listtable id tag
			#It hooks the bottom of the list by looking for the end of a table, a division, and the opening of another div
			#The closing sequence needs to be unique enough so as not to match any other closing table definitions in the page.
			raise "Could not scrape episode list from theTVDB.com." if epTable.nil?
			epTable=epTable[0]
			noEpisodes=TRUE if epTable.index('<tr><td class=odd colspan=3>No Episodes Found</td></tr>')

			unless noEpisodes
				
				i=0
				index={0=>'EpisodeID', 1=>'EpisodeName', 2=>'', 3=>'', 4=>'', 5=>''}
				field=0
				
				#Break it down into an array to work with in segments
				epTable=epTable.split( '</tr>' )
				epTable.each_index {|i| epTable[i]=epTable[i].split('</td>') }

				
				epTable.each {|row| field=0; episode={}; skip=FALSE; row.each {|epInfo|
					skip=TRUE if 
					temp=epInfo.match(/>[^<]+</)
					unless temp.nil?
						episode[(index[field])]=temp[0]
						field=field+1
					end	
				}; episodeList<<episode; }
			end

			#remove Specials from the episode List, they may be useful
			#in the future, but currently cause problems in this script
			episodeList= episodeList.delete_if {|episode|
				#Delete if there is no episodeName
				episode.has_key?('EpisodeName')!=TRUE or episode['EpisodeID'].match(/special/i)
			}



			#Swap the episodeID for our preferred format
			episodeList.each_index {|episode|
				next if episodeList[episode]['EpisodeID'].match(/special/i)
				next if episodeList[episode]['EpisodeID'].match(/\d/).nil?
				episodeList[episode]['EpisodeID']= 'S' \
					<< episodeList[episode]['EpisodeID'].match(/[\d]+ /)[0].strip \
					<< 'E' << episodeList[episode]['EpisodeID'].match(/ [\d]+/)[0].strip
			}

			#Put each episode in the cache
			episodeList.each_index {|i|
				#Get rid of the '>' and '<' from the ends of the EpisodeName
				episodeList[i]['EpisodeName']=episodeList[i]['EpisodeName'].chop.reverse.chop.reverse
				sqlStr= "SELECT uid FROM EpisodeCache WHERE SeriesID='#{seriesID}' AND " \
					"Season='#{episodeList[i]['EpisodeID'].match(/S[\d]+/)[0].reverse.chop.reverse}' AND "\
					"EpisodeNumber='#{episodeList[i]['EpisodeID'].match(/E[\d]+/)[0].reverse.chop.reverse}' AND "\
					"EpisodeName='#{Mysql.escape_string(episodeList[i]['EpisodeName'])}'"
				exist= sqlSearch(sqlStr)

				#puts "getAllEpisodes: Not adding duplicate episode #{seriesID} #{episodeList[i]['EpisodeID']}" unless exist.empty?
				#puts "getAllEpisodes: Caching #{seriesID} #{episodeList[i]['EpisodeID']}" if exist.empty?
				sqlStr= "INSERT INTO EpisodeCache (EpisodeName, EpisodeNumber, Season, SeriesID, DateAdded) VALUES " \
					<< "('#{Mysql.escape_string(episodeList[i]['EpisodeName'])}', " \
					<< "'#{episodeList[i]['EpisodeID'].match(/E[\d]*/)[0].reverse.chop.reverse}', " \
					<< "'#{episodeList[i]['EpisodeID'].match(/S[\d]*/)[0].reverse.chop.reverse}', '#{seriesID}', NOW())" \
					if exist.empty?

				sqlAddUpdate(sqlStr)
			}

			return episodeList

		end
		
	end
end

