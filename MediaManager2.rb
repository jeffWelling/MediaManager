#!/usr/bin/ruby
current_dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(current_dir + "/lib")
#require 'MMCommon.rb'
autoload :MediaManager, 'lib/MediaManager.rb'
#Stuff! It happens here!
#include MediaManager::MMCommon

