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

  module Scrapers
    SCRAPERS={}
    SCRAPER_DOCS={}

    def self.register(plugin_name, doc, *commands)
      autoload( plugin_name, "MediaManager/scrapers/#{plugin_name.downcase}")
      SCRAPER_DOCS[commands]=doc
      commands.each{|cmd| SCRAPERS[cmd]= plugin_name }
    end
  end
end
