#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/file_bucket/dipper'

describe Puppet::Type.type(:oratab).provider(:parsed), '(integration)' do
  include PuppetlabsSpec::Files

  before :each do
    described_class.stubs(:suitable?).returns true
    described_class.stubs(:default_target).returns fake_oratab
    Puppet::Type.type(:oratab).stubs(:defaultprovider).returns described_class
  end

  let :fake_oratab do
    filename = tmpfilename('oratab')
    unless File.exists? filename
      FileUtils.cp(my_fixture('input'), filename)
    end
    filename
  end

  # this resource is absent in our fake oratab
  let :resource_absent do
    Puppet::Type.type(:oratab).new(
      :name   => 'NO_SUCH_DATABASE',
      :ensure => :absent
    )
  end

  # this resource is present in our fake oratab and completly insync
  let :resource_present do
    Puppet::Type.type(:oratab).new(
      :name   => 'DB_INSYNC',
      :ensure => :present,
      :home   => '/u01/app/oracle/product/10.1.0/db_1',
      :atboot => :yes
    )
  end

  # this resource is not present in our fake oratab
  let :resource_create do
    Puppet::Type.type(:oratab).new(
      :name        => 'DB_CREATE',
      :ensure      => :present,
      :home        => '/u01/app/oracle/product/10.1.0/db_2',
      :description => 'added by puppet',
      :atboot      => :no
    )
  end

  # this resource is present in our fake oratab
  let :resource_delete do
    Puppet::Type.type(:oratab).new(
      :name   => 'DB_DELETE',
      :ensure => :absent
    )
  end

  # this resource is present in our fake oratab but with :home => '/u01/app/oracle/product/10.1.0/db_4'
  let :resource_sync_home do
     Puppet::Type.type(:oratab).new(
      :name   => 'DB_SYNC_HOME',
      :ensure => :present,
      :home   => '/new/home'
    )
  end

  # this resource is present in our fake oratab but with :atboot => :no
  let :resource_sync_atboot do
     Puppet::Type.type(:oratab).new(
      :name   => 'DB_SYNC_ATBOOT',
      :ensure => :present,
      :home   => '/u01/app/oracle/product/10.1.0/db_1',
      :atboot => :yes
    )
  end

  # this resource is present in our fake oratab but with :description => 'change me'
  let :resource_sync_description do
    Puppet::Type.type(:oratab).new(
      :name        => 'DB_SYNC_DESCRIPTION',
      :ensure      => :present,
      :atboot      => :no,
      :description => 'new desc'
    )
  end

  # this resource is present in our fake oratab but with :description => 'delete me'
  let :resource_delete_description do
    Puppet::Type.type(:oratab).new(
      :name        => 'DB_DELETE_DESCRIPTION',
      :ensure      => :present,
      :description => ''
    )
  end

  after :each do
    described_class.clear
  end

  def run_in_catalog(*resources)
    Puppet::FileBucket::Dipper.any_instance.stubs(:backup) # Don't backup to filebucket
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false
    resources.each do |resource|
      resource.expects(:err).never
      catalog.add_resource(resource)
    end
    catalog.apply
  end

  def check_content_against(fixture)
    content = File.read(fake_oratab).lines.map{|l| l.chomp}.reject{|l| l=~ /^\s*#|^\s*$/}.sort.join("\n")
    expected_content = File.read(my_fixture(fixture)).lines.map{|l| l.chomp}.reject{|l| l=~ /^\s*#|^\s*$/}.sort.join("\n")
    content.should == expected_content
  end

  describe "when managing one resource" do

    describe "with ensure set to absent" do
      it "should do nothing if already absent" do
        run_in_catalog(resource_absent)
        check_content_against('input')
      end

      it "should remove oratab entry if currently present" do
        run_in_catalog(resource_delete)
        check_content_against('output_single_delete')
      end
    end

    describe "with ensure set to present" do
      it "should do nothing if already present and in sync" do
        run_in_catalog(resource_present)
        check_content_against('input')
      end

      it "should create an oratab entry if currently absent" do
        run_in_catalog(resource_create)
        check_content_against('output_single_create')
      end

      it "should sync home if out of sync" do
        run_in_catalog(resource_sync_home)
        check_content_against('output_single_sync_home')
      end

      it "should sync atboot if out of sync" do
        run_in_catalog(resource_sync_atboot)
        check_content_against('output_single_sync_atboot')
      end

      it "should sync description if out sync" do
        run_in_catalog(resource_sync_description)
        check_content_against('output_single_sync_description')
      end

      it "should remove the description (including the #-sign) if description is empty" do
        run_in_catalog(resource_delete_description)
        check_content_against('output_single_sync_description_delete')
      end
    end
  end

  describe "when managing multiple resources" do
    it "should to the right thing (tm)" do
      run_in_catalog(
        resource_absent,
        resource_present,
        resource_create,
        resource_delete,
        resource_sync_home,
        resource_sync_atboot,
        resource_sync_description,
        resource_delete_description
      )
      check_content_against('output_multiple')
    end
  end

end
