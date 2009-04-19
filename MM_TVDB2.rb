$MMCONF_TVDB_APIKEY="722A9E49CA2070A2"
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



module MM_TVDB2
	def self.store_series_in_db(series)

		return {}
	end

	def self.db_has_series?(thetvdb_id)
		#Sanity check argument
		raise "db_has_series?(): Takes a string only, and it must be a thetvdb_id" unless thetvdb_id.class==String

			
		return {}
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
			series['thetvdb_id']=search_result['seriesid'][0].to_i
			series['IMDB_ID']=search_result['IMDB_ID'][0] if search_result.has_key? 'IMDB_ID'
			series['Title']=search_result['SeriesName'][0]
			search_results << series
		}
		
#		$it=$TVDB_search_cache
#		return $TVDB_search_cache[name_hash]
		return search_results

	end

	#This function is called by the user on the search_results returned by the searchTVDB() defined above
	def self.populate_results(search_results)
		#Sanity check input
		populated_results=[]
		badargs="populate_results(): Argument MUST be a search result as returned from searchTVDB() method."
		raise badargs unless search_results.class==Array
		raise "populate_results(): Was passed an empty arguments set?" if search_results.length==0
		search_results.each {|result|
			raise badargs if !result['Title'].class==String
			raise badargs if !result['thetvdb_id'].class==Fixnum
			raise badargs if result.has_key?('IMDB_ID') and !result['IMDB_ID'].class==String
		}

		search_results.each {|result|
			#TODO Lookup info from SQL here, series details and episodes TODO#
			series={}
			series['Episodes']=[]
			cache={}
			cache=MM_TVDB2.db_has_series?(result['thetvdb_id'])
			series.merge!(cache) unless cache.empty?

			raw_info= XmlSimple.xml_in(agent.get("#{$TVDB_Mirror}/api/#{$MMCONF_TVDB_APIKEY}/series/#{result['thetvdb_id']}/all/en.xml").body )

			series.merge! result	
			result=raw_info
			result['Series'][0]['Actors'][0].class==String ? series['Actors']=result['Series'][0]['Actors'][0] : series['Actors']=FALSE
			result['Series'][0]['Status'][0].class==String ? series['Status']=result['Series'][0]['Status'][0] : series['Series']=FALSE
			result['Series'][0]['ContentRating'].class==String ? series['Content_Rating']=result['Series'][0]['ContentRating'][0] : series['Content_Rating']=FALSE
			result['Series'][0]['Runtime'][0].class==String ? series['Runtime']=result['Series'][0]['Runtime'][0] : series['Runtime']=FALSE
			result['Series'][0]['Genre'][0].class==String ? series['Genre']=result['Series'][0]['Genre'][0] : series['Genre']=FALSE
			result['Series'][0]['FirstAired'][0].class==String ? series['FirstAired']=result['Series'][0]['FirstAired'][0] : series['FirstAired']=FALSE
			series['lastupdated']=result['Series'][0]['lastupdated'][0]
			result['Series'][0]['Rating'][0].class==String ? series['Rating']=result['Series'][0]['Rating'][0] : series['Rating']=FALSE
			result['Series'][0]['Overview'][0].class==String ? series['Overview']=result['Series'][0]['Overview'][0] : series['Overview']=FALSE
			result['Series'][0]['Network'][0].class==String ? series['Network']=result['Series'][0]['Network'][0] : series['Network']=FALSE
			
			episode_attributes=['SeasonNumber', 'Director', 'GuestStars', 'FirstAired', 'EpisodeNumber', 'lastupdated', 'ProductionCode', 
				'IMDB_ID', 'Overview', 'Writer', 'EpisodeName' ]
			result['Episode'].each {|episode|
				ep={}
				episode_attributes.each {|atr|
					episode[atr][0].class==String ? ep[atr]=episode[atr][0] : ep[atr]=FALSE
				}
				series['Episodes'] << ep
			}						
		
			populated_results << series
			MM_TVDB2.store_series_in_db(series)
		} #End search_results.each |result|
		return populated_results
	end
end
