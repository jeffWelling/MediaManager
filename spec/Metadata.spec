#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../spec"))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

load 'lib/MediaManager.rb'
include MediaManager

describe Metadata do
  it "Extract all episodeIDs from a string" do
    Metadata.getEpisodeID("Foo/bar/Ze episode vis ze bang!s02e12 omg s333e0033 1718x700 s02e13.avi").should == ['s02e12', 's02e13']
    Metadata.getEpisodeID("Foo/bar/Ze episode vis ze bang!s02e12 omg s333e0033 1718x700.avi").should == 's02e12'
  end
end
