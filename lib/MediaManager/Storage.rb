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
module MediaManager
  #This class is meant to be the abstracted interface to the information storage system
  #Instead of coding specifically for a SQL database or YAML file as a database backend,
  #This class will be used, which will decide wether to use sql or whatnot based on configs
  $yaml_import_list='~/.mmanager/import_list.yaml'
  class Storage
    class << self
      #Take paths, an array of paths, and put it the backend
      def importPaths paths
        puts "Importing #{paths.length} things!"

      end
      def saveToYaml paths
        MMCommon.writeFile YAML.dump(paths), $yaml_import_list
      end
    end
  end
end
