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
  Using=:yaml       #One of either :sqlite, :mysql, or :yaml
  Basedir='~/.mmanager/'
  Yaml_import_list= Basedir + 'import_list.yaml'
  Sqlite_file= Basedir + 'mmanager.sqlite'
  Sql_database='mmanager'  #We will assume the database is already created, by jebus or someone.
  Mysql_host='mysql'
  Mysql_user='omgwtfbbqsqluser'
  Mysql_pass='omgwtfbbqsqlpass'
  Import_list= Basedir + 'import_list.yaml'
  Hashes_list= Basedir + 'hashes.yaml'
  Library_data_list= Basedir + 'library_data.yaml'
  class Storage
    class << self
      def basedir
        Basedir
      end
      def sqlConnect
        FileUtils.makedirs(File.dirname(File.expand_path(Sqlite_file))) if Using==:sqlite and !File.directory?(File.dirname(File.expand_path(Sqlite_file)))
        #requires the libdbd-sqlite3-ruby package if your getting "DBI::InterfaceError: Unable to load driver 'sqlite3'"
        Using==:sqlite ? DBI.connect("dbi:sqlite3:#{File.expand_path(Sqlite_file)}") : DBI.connect("dbi:Mysql:mmanager:#{Mysql_host}", Mysql_user, Mysql_pass)
      end
      def createImportPathsTable sql_handle=nil
        sql_handle||=sqlConnect
        sql_handle= sqlConnect if sql_handle.disconnected?
        sql_handle.do("create table paths(id integer primary key, path varchar)")
        sql_handle.disconnect
      end

      def savePathsToYaml paths
        MMCommon.writeFile YAML.dump(paths), Yaml_import_list
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
          raise er
        ensure
          handle.disconnect
        end
      end
      def readPathsFromYaml
        YAML.load MMCommon.readFile(Import_list).join
      end
      def readPathsFromSql
        #TODO Complete me
      end

      #Take paths, an array of paths, and store it in the selected backend
      def savePaths paths
        Using == :yaml ? savePathsToYaml(paths) : savePathsToSql(paths)
      end
      def readPaths
        Using == :yaml ? readPathsFromYaml : readPathsFromSql
      end

      def saveHashesToYaml hashes
        MMCommon.writeFile YAML.dump(hashes), Hashes_list
      end
      def saveHashesToSql hashes
        #TODO Code me!
      end
      def readHashesFromYaml
        YAML.load MMCommon.readFile(Hashes_list).join
      end
      def readHashesFromSql
      end
      def saveHashes hashes
        Using == :yaml ? saveHashesToYaml(hashes) : saveHashesToSql(hashes)
      end
      def readHashes
        Using == :yaml ? readHashesFromYaml : readHashesFromSql
      end

      #Lookup metadata by path.  Will return nil if path has not been processed.
      #Returns a single populated MediaFile class (or child) if path has been processed. Nil otherwise.
      def metaByPath  path
        return nil
      end
      def saveLibraryData data
        Using==:yaml ? saveLibraryDataToYaml(data) : saveLibraryDataToSql(data)
      end
      def saveLibraryDataToYaml data
        MMCommon.writeFile YAML.dump(data), Library_data_list
      end
      def saveLibraryDataToSql data
        return true
      end
      def loadLibraryData
        Using==:yaml ? loadLibraryDataFromYaml : loadLibraryDataFromSql
      end
      def loadLibraryDataFromYaml
        YAML.load MMCommon.readFile(Library_data_list).join
      end
      def loadLibraryDataFromSql
        return true
      end
    end
  end
end
