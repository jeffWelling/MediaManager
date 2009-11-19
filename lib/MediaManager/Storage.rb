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
  $using=:yaml       #One of either :sqlite, :mysql, or :yaml
  $yaml_import_list='~/.mmanager/import_list.yaml'
  $sqlite_file='~/.mmanager/mmanager.sqlite'
  $sql_database='mmanager'  #We will assume the database is already created, by jebus or someone.
  $mysql_host='mysql'
  $mysql_user='omgwtfbbqsqluser'
  $mysql_pass='omgwtfbbqsqlpass'
  class Storage
    class << self
      def sqlConnect
        FileUtils.makedirs(File.dirname(File.expand_path($sqlite_file))) if $using==:sqlite and !File.directory?(File.dirname(File.expand_path($sqlite_file)))
        #requires the libdbd-sqlite3-ruby package if your getting "DBI::InterfaceError: Unable to load driver 'sqlite3'"
        $using==:sqlite ? DBI.connect("dbi:sqlite3:#{File.expand_path($sqlite_file)}") : DBI.connect("dbi:Mysql:mmanager:#{$mysql_host}", $mysql_user, $mysql_pass)
      end
      def createImportPathsTable sql_handle=nil
        sql_handle||=sqlConnect
        sql_handle= sqlConnect if sql_handle.disconnected?
        sql_handle.do("create table paths(id integer primary key, path varchar)")
        sql_handle.disconnect
      end

      def savePathsToYaml paths
        MMCommon.writeFile YAML.dump(paths), $yaml_import_list
      end 
      #Sql method to import paths to sql database, swappable with the saveToYaml method
      def savePathsToSql paths
        begin
          e=nil
          s=nil
          handle= sqlConnect
          paths.each {|path|
            #Feels like we should be escaping path before using it, but I can't find a sqlite3 escapeString method...?
            e=path
            handle.do( s="insert into paths (path) values (' #{path} ') " )
          }
        rescue DBI::ProgrammingError => er
          (createImportPathsTable(handle) and retry) if er.to_s[/no such table/i]
          puts e
          puts s
          raise er
        ensure
          handle.disconnect
        end
      end

      #Take paths, an array of paths, and store it in the selected backend
      def importPaths paths
        $using!=:sqlite ? savePathsToYaml(paths) : savePathsToSql(paths)
      end
    end
  end
end
