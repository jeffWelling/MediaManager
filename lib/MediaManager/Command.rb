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
    DOC={}

    def self.register(mod_name, doc, *commands)
      autoload(mod_name, "MediaManager/commands/#{mod_name.downcase}")
      DOC[commands]=doc
      commands.each{|cmd| COMMANDS[cmd]= mod_name }
    end
    
    register 'Import', 'Imports a file or directory into the library', 'import'
    register 'Config', 'Allows configuring via Irb, saving to the config file', 'config'
    register 'Remap', 'Creates a Library directory from your media files', 'remap'
    register 'Hasher', 'Reads the paths, and generates hashes for the files', 'hasher'

    def self.get(command)
      if mod_name= COMMANDS[command]
        const_get(mod_name)
      end
    end
    
    def self.usage(action, args)
      o= parser(action, &method(:default_usage))
      o.parse!(args)
      o
    end
    
    def self.default_usage(o)
      o.banner= "Usage: mmanager COMMAND [FLAGS] [ARGS]"
      o.top.append  ' ', nil, nil
      o.top.append  'The developers have graced you with these available commands:', nil, nil

      DOC.each {|commands, doc|
        #Use the longest command for the example
        command=commands.sort_by{|cmd| cmd.size}.last
        o.top.append("    %-32s %s" % [command, doc], nil, nil)
      }
    end
  
    def self.parser(action, &block)
      OptionParser.new {|o|
        o.banner= "Usage: mmanager #{action} [FLAGS] [ARGS]"
        
        o.base.append ' ', nil, nil
        o.base.append 'Common options:', nil, nil
        o.on_tail('-V', '--version', 'Show the version number'){
          MMCommon.pprint MediaManager::VERSION
          exit
        }
        o.on_tail('-h', '--help', 'Display ze help'){
          MMCommon.pprint o
          exit
        }
        
        if block_given?
          yield(o)
          unless o.top.list.empty?
            if action
              o.top.prepend "Options for #{action} command:", nil, nil
              o.top.prepend ' ', nil, nil
            end
          end
        end
      }
    end
  end
end
