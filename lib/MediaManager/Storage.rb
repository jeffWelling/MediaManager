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
  $using=:sqlite       #One of either :sqlite, :mysql, or :yaml
  $yaml_import_list='~/.mmanager/import_list.yaml'
  $sqlite_file='~/.mmanager/mmanager.sqlite'
  $sql_database='mmanager'  #We will assume the database is already created, by jebus or someone.
  $mysql_host='mysql'
  $mysql_user='omgwtfbbqsqluser'
  $mysql_pass='omgwtfbbqsqlpass'
  class Storage
    class << self
      def saveToYaml paths
        MMCommon.writeFile YAML.dump(paths), $yaml_import_list
      end 
      #Take paths, an array of paths, and put it the backend
      def importPaths paths
        $using==:sqlite ? saveToYaml(paths) : savePathsToSql(paths)
      end
      #Sql method to import paths to sql database, swappable with the saveToYaml method
      def savePathsToSql paths
        
      end
      def sqlConnect
        $using==:sqlite ? DBI.connect( ) : DBI.connect("dbi:Mysql:mmanager:#{$mysql_host}", $mysql_user, $mysql_pass)
      end
    end
  end
end
