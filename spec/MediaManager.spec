#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../spec"))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

load 'MediaManager2.rb'

describe MediaManager do
        it "Scans a directory or file, returning an array of items it could not process."
end
