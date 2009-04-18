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
	def self.searchTVDB(name)
		$TVDB_search_cache||={}
		puts "searchTVDB(): Searching for '#{name}'"
		
		name_hash = Digest::SHA1.hexdigest(name.downcase)
		
		if $TVDB_search_cache.has_key? name_hash
			puts "searchTVDB(): '#{name}' cached"
			return $TVDB_search_cache
		end
	
		$TVDB_Mirror||= XmlSimple.xml_in(agent.get("http://www.thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/mirrors.xml").body)['Mirror'][0]['mirrorpath'][0]

		#To be used when adding new series to mysql
		time= XmlSimple.xml_in(agent.get("http://www.thetvdb.com/api/Updates.php?type=none").body)['Time'][0].to_i

raise
		begin
			$TVDB_search_cache.merge!( name_hash => XmlSimple.xml_in( agent.get("#{$MMCONF_TVDB_MIRROR}/api/GetSeries.php?seriesname=#{ERB::Util.url_encode name}").body ))
		rescue Timeout::Error=>e
			retry if deal_with_timeout(e)==:retry
		rescue Errno::ETIMEDOUT=>e
			retry if deal_with_timeout(e)==:retry
		end

		return $TVDB_search_cache[name_hash]

	end
end
