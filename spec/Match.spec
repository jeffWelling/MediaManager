#!/usr/bin/env ruby
#  Copyright 2009, Jeff Welling
#
#    This file is part of MediaManager.
#
#    MediaManager is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    MediaManager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with MediaManager.  If not, see <http://www.gnu.org/licenses/>.

$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../spec"))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))

load 'lib/MediaManager.rb'
include MediaManager

describe Match do
  it "Matches various patterns" do
    Match.fuzzy_match( 'abc', 'abc' ).should_not == false
    Match.fuzzy_match( 'abc123', 'abc' ).should_not == false
    Match.fuzzy_match( '1 to two', 'One').should_not == false
    Match.fuzzy_match( '1 to two', 'one').should_not == false
    #TODO Fix the match code to be insensitive to which side which string goes in so that
    #     we can also do fuzzy_match('one', '1 to two') as well as those above.
  end
end
