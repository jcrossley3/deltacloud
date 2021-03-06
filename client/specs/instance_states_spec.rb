#
# Copyright (C) 2009  Red Hat, Inc.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA


require 'specs/spec_helper'

=begin
Spec::Matchers.define :include_transition do |action,to|
  match do |transitions|
    found = transitions.find{|e| e.action.to_s == action.to_s && e.to.to_s == to.to_s }
    ! found.nil?
  end
end
=end

describe "instance-states" do

  it_should_behave_like "all resources"

  it "should allow retrieval of instance-state information" do
    DeltaCloud.new( API_NAME, API_PASSWORD, API_URL ) do |client|
      instance_states = client.instance_states
      instance_states.should_not be_nil
      instance_states.should_not be_empty

      instance_states[0].name.should eql( 'start' )
      instance_states[0].transitions.size.should eql( 1 )
      instance_states[0].transitions[0].should_not be_auto

      instance_states[1].name.should eql( 'pending' )
      instance_states[1].transitions.size.should eql( 1 )
      instance_states[1].transitions[0].should be_auto

      instance_states[2].name.should eql( 'running' )
      instance_states[2].transitions.size.should eql( 2 )
      includes_transition( instance_states[2].transitions, :reboot, :running ).should be_true
      includes_transition( instance_states[2].transitions, :stop, :stopped ).should be_true
    end
  end

  it "should allow retrieval of a single instance-state blob" do
    DeltaCloud.new( API_NAME, API_PASSWORD, API_URL ) do |client|
      instance_state = client.instance_state( :pending )
      instance_state.should_not be_nil
      instance_state.name.should eql( 'pending' )
      instance_state.transitions.size.should eql( 1 )
      instance_state.transitions[0].should be_auto

      instance_state = client.instance_state( :running )
      instance_state.name.should eql( 'running' )
      instance_state.transitions.size.should eql( 2 )
      includes_transition( instance_state.transitions, :reboot, :running ).should be_true
      includes_transition( instance_state.transitions, :stop, :stopped ).should be_true
    end
  end

  def includes_transition( transitions, action, to )
    found = transitions.find{|e| e.action.to_s == action.to_s && e.to.to_s == to.to_s }
    ! found.nil?
  end


end
