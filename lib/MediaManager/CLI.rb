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
  #Assist with operation via the CLI
  class CLI
    #Run from the mmanager executable file
    def self.execute
      parse(ARGV).execute!
    end

    def self.parse(args)
      cli= new(args)
      cli
    end
    
    def initialize(args)
      @args= args.dup
      if args.empty? 
        MMCommon.pprint "Your supposed to actually tell me to do something,  gawsh napoleon..\nTry the 'help' flag."
        exit 1
      end
      @action= args.shift
      #Combine both initialize, and parse_options! methods from ticgit
    end
    attr_reader :action, :args

    def execute! 
      if mod= Command.get(action)
        extend(mod)
        
        if respond_to?(:parser)
          option_parser= Command.parser(action, &method(:parser))
        else
          option_parser= Command.parser(action)
        end
        
        option_parser.parse!(args)
        execute if respond_to?(:execute)
      else
        puts usage
        if args.empty? and !action
          exit
        else
          puts "#{action} is not a command, try the -h option to get a clue"
          exit 1
        end
      end
    end

    def usage(args=nil)
      old_args= args|| [action, *self.args].compact
      if respond_to?(:parser)
        Command.parser('COMMAND', &method(:parser))
      else
        Command.usage(old_args.first, old_args)
      end
    end
  end
end
