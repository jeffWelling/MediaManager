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
  module Command
    COMMANDS={}
    DOCS={}

    def self.register(mod_name, doc, *commands)
      autoload(mod_name, "MediaManager/command/#{mod_name.downcase}")
      DOC[commands]=doc
      commands.each{|cmd| COMMANDS[cmd]= mod_name }
    end
    
    register 'Import', 'Imports a file or directory into the library', 'import'

    def self.get(command)
      if mod_name= COMMANDS[command]
        const_get(mod_name)
      end
    end
    
    def self.usage(action, args)
    end
    
    def self.default_usage(o)
    end
  
    def self.parser(action, &block)
    end
  end
end
