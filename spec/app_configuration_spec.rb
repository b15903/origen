require "spec_helper"

describe "Application Configuration" do

  it "captures the application name" do
    Origen.config.name.should == "Origen Core"
  end

  specify "LSF configuration works" do
    Origen.config.lsf.debug.should == false
    Origen.config.lsf.debug = true
    Origen.config.lsf.debug.should == true
  end

  it 'uses the correct default RC tag prepend' do
    Origen.app.config.rc_tag_prepend_v.should == true
  end

  #specify "LSF configuration can be set from the application.rb file" do
  #  Origen.config.lsf.project.should == "origen core"
  #end

end
