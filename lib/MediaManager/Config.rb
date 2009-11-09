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
  module Config
    class << self
      def initialize
        @config=OpenStruct.new
      end
      attr_reader :config
      #Read the config file, and load it into the options class variable
      def loadConfigs
        @config=OpenStruct.new(MediaManager::MMCommon.readConfig)
      end
      #Save the @config openstruct
      def saveConfigs
        MediaManager::MMCommon.saveConfig @config
      end
    end
  end
end
