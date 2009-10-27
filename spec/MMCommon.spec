#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../spec"))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

load 'MMCommon.rb'
include MediaManager

describe MMCommon do
  it "scans a target, returning an array containing the full paths to every item found" do
    target= File.dirname(File.expand_path(__FILE__))
    returned=scan_target( target )
    objects=Dir.glob(target+'/**', File::FNM_DOTMATCH).delete_if {|path| File.basename(path)=='.' || File.basename(path)=='..'}
    objects << target
    returned.length.should == objects.length
    objects.each {|p|
      returned.include?(p).should==true
    }
  end
end
