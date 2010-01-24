#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../spec"))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

load 'lib/MediaManager.rb'
include MediaManager

describe Media do
  it "Returns a sha1 sum based only on the metadata so that objects with identical info can be seen as the same" do
    obj1=MediaManager::Media::MediaFile.new
    obj2=MediaManager::Media::MediaFile.new
    obj3=MediaManager::Media::MediaFile.new
    obj1.title="Dead Like Me is an awesome TV show!"
    obj2.title="Dead Like Me is an awesome TV show!"
    obj3.title="Dead Like Me should never have been cancelled"
    obj1.sha1.should == obj2.sha1
    obj1.sha1.should_not == obj3.sha1
  end
end
