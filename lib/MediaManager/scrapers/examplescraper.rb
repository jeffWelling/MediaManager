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

#Example scraper module
module MediaManager
  module Scrapers
    #Note that the name of the module is the same as the 
    module Examplescraper
      class << self
        #Accessible in irb as MediaManager::Scrapers::TestScraper.doit
        def doit
          puts 'jesusfuck'
        end
      end
    end
  end
end

