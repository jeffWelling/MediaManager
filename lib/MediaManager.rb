=begin
  Copyright 2009, Jeff Welling

    This file is part of MediaManager.

    MediaManager is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    MediaManager is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MediaManager.  If not, see <http://www.gnu.org/licenses/>.
  
=end
$config_file="~/.mmanager/mmanager.config.yaml"
current_dir=File.expand_path(File.dirname(__FILE__))
unless $LOAD_PATH.first == (current_dir)
  $LOAD_PATH.unshift(current_dir)
end
autoload :Find, 'find'
autoload :OptionParser, 'optparse'
autoload :YAML, 'yaml'
autoload :OpenStruct, 'ostruct'
autoload :DBI, 'dbi'
autoload :FileUtils, 'fileutils'

require 'rubygems'
require 'digest/sha1'
require 'libthetvdb/lib/libthetvdb.rb'
require 'ftools'


#require 'linguistics'  #Linguistics (>=?)1.0.5
#autoload :Linguistics, 'linguistics'      #Using this autoload instead of the require throws "no such file to load"
autoload :TMDBParty, 'tmdb_party/lib/tmdb_party.rb'

module MediaManager
  autoload :LibraryData, 'MediaManager/LibraryDataObj'
  autoload :VERSION, 'MediaManager/Version'
  autoload :MMCommon, 'MediaManager/MMCommon'
  autoload :CLI, 'MediaManager/CLI'
  autoload :Command, 'MediaManager/Command'
  autoload :Config, 'MediaManager/Config'
  autoload :Storage, 'MediaManager/Storage'
  autoload :Scrapers, 'MediaManager/Scrapers'
  autoload :Match, 'MediaManager/Match'
  autoload :Media, 'MediaManager/Media'
  autoload :Metadata, 'MediaManager/Metadata'
end
