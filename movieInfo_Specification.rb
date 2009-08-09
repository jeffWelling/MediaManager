$movieInfoSpec={
	'Title'=>'',
	'EpisodeID'=>'',
	'EpisodeName'=>'',
	'Season'=>'',
	'URL'=>'',
	'Year'=>'',

	'Categorization'=>'',    #  In the form of Library/Movies    , the script will fill in [/Thomas Crown Affair/X where X is 'epNum - EpName'] when it creates the symlinks
	'Path'=>'',
	'Size'=>'',
	'FileSHA'=>'',

	'PlayCommand'=>''	
}

class MovieInfo
	def initialize(file_path)
		@file_path=file_path
		@size=File.size file_path
		@path_sha=hash_filename file_path
		@date_added=DateTime.now.to_s
	end
	def file_path
		@file_path
	end
end
