require 'katello_test_helper'

module Katello
  describe Glue::Candlepin::Consumer do
    include OrchestrationHelper

    let(:facts) do
      {
        "net.interface.eth2.broadcast" => "123.123.123.123",
        "net.interface.eth2.ipv4_address" => "192.168.127.5",
        "net.interface.eth2.netmask" => "255.255.255.0",
        "net.interface.eth2.ipv6_address.link" => "fe80::1a03:73ff:fe44:6d94",
        "net.interface.eth0.broadcast" => "123.123.123.123",
        "net.interface.eth0.ipv4_address" => "192.168.127.4",
        "net.interface.eth0.netmask" => "255.255.255.0",
        "net.interface.eth0.ipv6_address.link" => "fe80::2a03:73ff:fe44:6d94",
        "net.interface.em1.broadcast" => "123.123.123.123",
        "net.interface.em1.ipv4_address" => "192.168.1.6",
        "net.interface.em1.netmask" => "255.255.255.0",
        "net.interface.em1.ipv6_address.link" => "fc80::2a03:73ff:fe44:6d94"
      }
    end
    let(:system_name) { 'testing' }
    let(:cp_type) { 'system' }
    let(:uuid) { '1234' }
    let(:description) { 'description' }

    before(:each) do
      @system = System.new(:name => system_name,
                           :cp_type => cp_type,
                           :facts => facts,
                           :description => description,
                           :uuid => uuid,
                           :serviceLevel => nil)
    end

    describe "the system has a lot of interfaces" do
      it "should have three interfaces" do
        @system.interfaces.size.must_equal(3)
      end

      it "should have an invalid interface" do
        @system.facts["net.interface.em2.ipv4_address"] = nil
        @system.interfaces.size.must_equal(3)
      end

      it "should have an extra interface" do
        @system.facts["net.interface.eth4.ipv4_address"] = '192.168.1.121'
        @system.interfaces.size.must_equal(4)
      end

      it "should have correct interface mappings" do
        @system.facts["net.interface.eth4.ipv4_address"] = '192.168.1.121'
        @system.interfaces.each do |i|
          if i[:name] == 'eth4'
            i[:addr].must_equal('192.168.1.121')
          end
        end
      end

      it "should not flip out about multiple facts" do
        @system.facts["net.interface.eth4.ipv4_address"] = '192.168.1.121'
        @system.facts["net.interface.eth4.ipv4_address"] = '192.168.1.125'
        @system.facts["net.interface.eth4.ipv4_address"] = '192.168.1.123'
        @system.facts["net.interface.eth4.ipv4_address"] = '192.168.1.122'
        @system.interfaces.size.must_equal(4)
      end
    end
  end
end
