require 'MMCommon'
require 'xmlsimple'
require 'erb'
require 'digest/sha1'

module MediaManager
	module MM_TVDB
		extend MMCommon
		def self.searchTVDB name
			nameHash = Digest::SHA1.hexdigest(name.downcase)

			#cause the thetcdb.com programmers api said so?    but still, wtf?	
			unless $MMCONF_TVDB_MIRROR then
				mirrors_xml = XmlSimple.xml_in agent.get("http://www.thetvdb.com/api/#{$MMCONF_TVDB_APIKEY}/mirrors.xml").body
				$MMCONF_TVDB_MIRROR= mirrors_xml['Mirror'][0]['mirrorpath'][0]
			end

			return $TVDB_CACHE[nameHash] if $TVDB_CACHE.include?(nameHash)

			$TVDB_CACHE.merge!( nameHash => XmlSimple.xml_in( agent.get("#{$MMCONF_TVDB_MIRROR}/api/GetSeries.php?seriesname=#{ERB::Util.url_encode name}").body ))
			
			#I use a return statement instead of not using it at all is because the first return excludes the hash, so consistency
			return $TVDB_CACHE[nameHash]

		end

		#This function takes a string which is expected to represent an unaltered
		#filename as downloaded from the interwebs.  Full-paths are acceptable.
		def self.TVDB_include? fPath
			#split the full path and reverse it, so that the extention is [0]
			#with the full path parts climbing higher.
			pathToArray
			

		end
	end
end

