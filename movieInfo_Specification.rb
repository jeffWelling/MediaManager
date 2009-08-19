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
	'id'=>'',
	'DateAdded'=>'',
	'DateModified'=>'',
	
}

class MovieInfo
	#Become_movieInfo is a function to help with legacy support, it makes the MovieInfo instance [blindly] take on the
	#properties of the movieInfo hash it is passed.  Emphasis on the way it takes on the properties blindly.
	def Become_movieInfo movieInfo
		raise "Are you fuck-tarded?" unless movieInfo.class==Hash
		movieInfo.each_key {|key|
			case key
				when 'Title'
					@title=movieInfo[key]
				when 'EpisodeID'
					@episodeID=movieInfo[key]
				when 'EpisodeName'
					@episodeName=movieInfo[key]
				when 'Season'
					@season=movieInfo[key]
				when 'URL'
					@url=movieInfo[key]
				when 'Year'
					@year=movieInfo[key]
				when 'tvdbSeriesID'
					@tvdbSeriesID=movieInfo[key]
				when 'imdbID'
					@imdbID=movieInfo[key]
				when 'Categorization'
					@categorization=movieInfo[key]
				when 'Path'
					@path=movieInfo[key]
				when 'PathSHA'
					@path_sha=movieInfo[key]
				when 'Size'
					@size=movieInfo[key]
				when 'FileSHA'
					@path_sha
				when 'id'
					@id=movieInfo[key]
				when 'DateAdded'
					@date_added=movieInfo[key]
				when 'DateModified'
					@date_modified=movieInfo[key]
				else
					puts "What the fuck?  #{key} : #{movieInfo[key]} "
			end
		}
	end
	def Become_movieObject movie_object
		
	end	

	def initialize(file_path)
		@title=nil
		@episodeID=nil
		@episodeName=nil
		@episodeNumber=nil
		@season=nil
		@url=nil
		@year=nil
		@tvdbSeriesID=nil
		@imdbID=nil

		@categorization=nil

		@path=file_path
		@size=File.size file_path
		@path_sha=hash_filename file_path
		@file_sha=nil

		#these are populated when something is pulled from the database (save date_added)
		@id=nil
		@date_added=DateTime.now.to_s
		@date_modified=nil
	end

	def Path
		@path
	end
	def Size
		@size
	end
	def PathSha
		@path_sha
	end
	def setPath path
		@size=File.size path
		@path_sha=hash_filename(path)
		@path=path
	end

	def Title
		@title
	end
	def setTitle title
		@title=title
	end
	
	def EpisodeID
		@episodeID
	end
	def setEpisodeID episodeID
		if (m=episodeID.match(/(s\d+e\d+|\d+x\d+)/i))
			@season=m[0].match(/\d+/)[0]  #will match the first set of digits found
			@episodeNumber=m[0].match(/\d+$/)[0]
		else
			puts "MovieInfo Object:  WARNING! You've passed an episodeID that does not parse as a season and episode number pair."
		end
		@episodeID=episodeID
	end

	def EpisodeName
		@episodeName
	end
	def setEpisodeName name
		@episodeName=name
	end
	
	def EpisodeNumber
		@episodeNumber
	end
	def setEpisodeNumber number
		puts "MovieInfo Object:  STUPIDITY ALERT! Your not supposed to directly enter the episodeNumber yourself, please set it using setEpisodeID!"
		sleep 1
		raise "setEpisodeNumber takes Fixnum class only" unless number.class==Fixnum
		@episodeNumber=number
	end
	
	def Season
		@season
	end
	def setSeason seasonNumber
		puts "MovieInfo Object:  STUPIDITY ALERT! Your not supposed to directly set seasonNumber yourself, please use setEpisodeID"
		sleep 1
		raise "setSeason takes Fixum class only" unless seasonNumber.class==Fixnum
		@season=seasonNumber
	end

	def URL
		@url
	end
	def setURL url
		@url=url
	end
	
	def Year
		@year
	end
	def setYear year
		@year=year
	end

	def TvdbSeriesID
		@tvdbSeriesID
	end
	def setTvdbSeriesID id
		@tvdbSeriesID=id
	end

	def IMDB_ID
		@imdb_id
	end
	def setIMDB_ID id
		@imdb_id=id
	end

	def Categorization
		@categorization
	end
	def setCategorization category
		raise "setCategorization only takes a string, you blowjob" unless category.class==String
		@categorization=category
	end

	def Id
		@id
	end
	def DateAdded
		@date_added
	end
	def DateModified
		@date_modified
	end
	def setId id
		@id=id
	end
	def setDateAdded date
		@date_added=date
	end
	def setDateModified date
		@date_modified=date
	end
			
end
