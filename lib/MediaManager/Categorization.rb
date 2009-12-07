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
  #This module deals with creating your library, based on your imported and processed paths
  #The way the Library is laid out should be customizatble by placing a file in the
  #categorization according to the examples.
  module Categorization
    SCHEMES=[]
    class << self
      def makeLibrary
        #get paths
        #read customizable cateogization files
        #for every path with a tag, map it to it's spot based on the selected categorization scheme.
      end
      def loadSchemes
        Dir.glob(File.expand_path("lib/MediaManager/categorization_schemes/*")).each {|cat_scheme|
          if cat_scheme[/\.yaml\s?$/i]
            SCHEMES << (scheme=YAML.load( MMCommon.readFile(cat_scheme).to_s )) if valid_scheme?(scheme)
          end
        }
      end
      #Return true if scheme is a valid categorization scheme suitable for use creating the library
      def validScheme? scheme
        true
      end
    end
  end
end
