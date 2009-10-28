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
  
  it "returns true if str matches any of the exclusions" do
    str="/home/user/christ_waffers.lol"
    excluded?(str, [/christ/]).should== true
    excluded?(str, [/waffers/]).should== true
    excluded?(str, [/god/]).should== false
    excluded?(str, [/jesus/, /boots/]).should== false
    excluded?(str, [/does/, /god/, /exist\?/]).should== false
    excluded?(str, [/does/, /microsoft/, /produce/, /quality/, /products/]).should== false
    excluded?(str, [/problem/, /between/, /keyboard/, /and/, /chair/, /user/]).should== true
    excluded?(str, [/scientology/, /is/, /a/, /scam/]).should== true
    excluded?(str, [/religion/, /is/, /a/, /scam/]).should== true
    excluded?(str, [/creationism/, / is /, /science/]).should== false
  end
end
