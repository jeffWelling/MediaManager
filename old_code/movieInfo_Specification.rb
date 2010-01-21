$movieInfoSpec={
	'Title'=>'',
	'EpisodeID'=>'',
	'EpisodeName'=>'',
	'Season'=>'',
	'URL'=>'',
	'Year'=>'',
	'tvdbSeriesID'=>'',
	'imdbID'=>'',

	'Categorization'=>'',    #  In the form of Library/Movies    , the script will fill in [/Thomas Crown Affair/X where X is 'epNum - EpName'] when it creates the symlinks

	'Path'=>'',
	'PathSHA'=>'',
	'Size'=>'',
	'FileSHA'=>'',

	'PlayCommand'=>'',

	#from the database
#	'id'=>'',
	'DateAdded'=>'',
	'DateModified'=>'',
	
}

class MovieInfo
	@@movieInfo_attributes=['Title', 'EpisodeID', 'EpisodeName', 'Season', 'URL', 'Year', 'tvdbSeriesID', 'imdbID', 'Categorization', 'Path',
		'PathSHA', 'Size', 'FileSHA', 'id', 'DateAdded', 'DateModified', 'tv/movie', 'EpisodeAired', 'EpisodeNumber']

	def to_s
		string_to_print=''
		@@movieInfo_attributes.each {|attribute|
			string_to_print << "#{attribute}:  '#{@movieInfo_values[attribute]}', "
		}
		return string_to_print.chop.chop
	end
	def print
		@@movieInfo_attributes.each {|atr|
			puts "#{atr}:\t\t'#{@movieInfo_values[atr]}'"
		}
		return true
	end

	def empty?
		@@movieInfo_attributes.each {|atr|
			return false if !self[atr].nil? and !self[atr].empty? unless atr=='DateAdded'
		}
		return true
	end

	def merge hash_to_merge
		@merges||=[]
		@merge_index||=0
		@merges[@merge_index]=hash_to_merge
		@merge_index >= 4 ? @merge_index=0 : @merge_index+=1
		self
	end
	def merge! thing
		self.merge thing
	end
	def clearMerges
		@merges=[]
		@merge_index=0
	end

	#This is meant to help integration.  By allowing the object to be treated as an array/hash, it should
	#be much easier to migrate to it from the simple movieInfo and movieData objects.
	def [] key
		return @movieInfo_values[key] if @movieInfo_values.has_key? key
		@merges.each {|merged_thing|
			if merged_thing.class==Hash and merged_thing.has_key? key
				return merged_thing[key]
			elsif (merged_thing.class==Fixnum or merged_thing.class==String) and merged_thing==key
				return merged_thing
			elsif merged_thing==key
				return merged_thing
			end
		}
		return nil
	end
	#Become_movieInfo iis a function to help with legacy support, it makes the MovieInfo instance [blindly] take on the
	#properties of the movieInfo hash it is passed.  Emphasis on the way it takes on the properties blindly.  It can be used
	#for any Hash that has corresponding keys.
	def Become movieInfo
		raise "Are you fuck-tarded?" unless movieInfo.class==Hash
		absorbed=0
		movieInfo.each_key {|key|
			if @@movieInfo_attributes.include? key
				@movieInfo_values[key]=movieInfo[key]
				absorbed+=1
			else
				puts "MovieInfo.Become():  What the fuck?  #{key} : #{movieInfo[key]} "
			end
		}	
		absorbed
	end

	def initialize(file_path=nil)
		@movieInfo_values={}
		@@movieInfo_attributes.each {|atr|
			@movieInfo_values.merge!( {atr=>nil} )
		}
		@movieInfo_values['Path']=file_path 
		unless file_path.nil?
			@movieInfo_values['Path']=file_path
			@movieInfo_values['Size']=File.size file_path
			@movieInfo_values['PathSHA']=hash_filename file_path
		end
	end

	def Path
		@movieInfo_values['Path']
	end
	def Size
		@movieInfo_values['Size']
	end
	def PathSha
		@movieInfo_values['PathSHA']
	end
	def setPath path
		@movieInfo_values['Size']=File.size path
		@movieInfo_values['PathSHA']=hash_filename(path)
		@movieInfo_values['Path']=path
	end

	def Title
		@movieInfo_values['Title']
	end
	def setTitle title
		@movieInfo_values['Title']=title
	end
	
	def EpisodeID
		@movieInfo_values['EpisodeID']
	end
	def setEpisodeID episodeID
		if (m=episodeID.match(/(s\d+e\d+|\d+x\d+)/i))
			@movieInfo_values['Season']=m[0].match(/\d+/)[0]  #will match the first set of digits found
			@movieInfo_values['EpisodeNumber']=m[0].match(/\d+$/)[0]
		else
			puts "MovieInfo Object:  WARNING! You've passed an episodeID that does not parse as a season and episode number pair."
		end
		@movieInfo_values['EpisodeID']=episodeID
	end

	def EpisodeName
		@movieInfo_values['EpisodeName']
	end
	def setEpisodeName name
		@movieInfo_values['EpisodeName']=name
	end
	
	def EpisodeNumber
		@movieInfo_values['EpisodeNumber']
	end
	def setEpisodeNumber number
		puts "MovieInfo Object:  STUPIDITY ALERT! Your not supposed to directly enter the episodeNumber yourself, please set it using setEpisodeID!"
		sleep 1
		raise "setEpisodeNumber takes Fixnum class only" unless number.class==Fixnum
		@movieInfo_values['EpisodeNumber']=number
	end
	
	def Season
		@movieInfo_values['Season']
	end
	def setSeason seasonNumber
		puts "MovieInfo Object:  STUPIDITY ALERT! Your not supposed to directly set seasonNumber yourself, please use setEpisodeID"
		sleep 1
		raise "setSeason takes Fixum class only" unless seasonNumber.class==Fixnum
		@movieInfo_values['Season']=seasonNumber
	end

	def URL
		@movieInfo_values['URL']
	end
	def setURL url
		@movieInfo_values['URL']=url
	end
	
	def Year
		@movieInfo_values['Year']
	end
	def setYear year
		@movieInfo_values['Year']=year
	end

	def TvdbSeriesID
		@movieInfo_values['tvdbSeriesID']
	end
	def setTvdbSeriesID id
		@movieInfo_values['tvdbSeriesID']=id
	end

	def IMDB_ID
		@movieInfo_values['imdbID']
	end
	def setIMDB_ID id
		@movieInfo_values['imdbID']=id
	end

	def Categorization
		@movieInfo_values['Categorization']
	end
	def setCategorization category
		raise "setCategorization only takes a string, you blowjob" unless category.class==String
		@movieInfo_values['Categorization']=category
	end

	def Id
		@movieInfo_values['id']
	end
	def DateAdded
		@movieInfo_values['DateAdded']
	end
	def DateModified
		@movieInfo_values['DateModified']
	end
	def setId id
		@movieInfo_values['id']=id
	end
	def setDateAdded date
		@movieInfo_values['DateAdded']=date
	end
	def setDateModified date
		@movieInfo_values['DateModified']=date
	end
			
end
