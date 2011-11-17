require 'spec_helper'

describe 'puppet node_rackspace find' do
  subject { Puppet::Face[:node_rackspace, :current] }

  server_attributes = {
    :id        => '12345678',
    :name      => 'slice12345678',
    :host_id   => '277eed7bbd0aaffdebe80a3b27183837',
    :addresses => { "public" => '127.0.0.1' },
    :state     => 'BUILD',
    :progress  => '0',
  }

  describe 'option validation' do
    context 'without any options' do
      it 'should require server_id' do
        pattern = /wrong number of arguments/
        expect { subject.find }.to raise_error ArgumentError, pattern
      end
    end
  end

  describe 'the behavior of find' do
    before :each do
      Puppet::CloudPack::Rackspace.any_instance.stubs(:create_connection).returns(server)
    end

    context 'when a server exists' do
      let(:server) do
        mock('Fog::Compute[:rackspace]') do
          expects(:servers).returns(self)
          expects(:get).returns(self)
          expects(:attributes).returns(server_attributes)
        end
      end

      it 'should find a server' do
         expected_attributes = {
          :id        => '12345678',
          :name      => 'slice12345678',
          :host_id   => '277eed7bbd0aaffdebe80a3b27183837',
          :addresses => { "public" => '127.0.0.1' },
          :state     => 'BUILD',
          :progress  => '0',
        }
        subject.find('123456789').should == [expected_attributes]
      end
    end

    context 'when a server does not exists' do
      let(:server) do
        mock('Fog::Compute[:rackspace]') do
          expects(:servers).returns(self)
          expects(:get).returns(nil)
          expects(:attributes).never
        end
      end

      it 'should not find a server' do
        subject.find('123456789').should == []
      end
    end
  end

  describe 'inline documentation' do
    subject { Puppet::Face[:node_rackspace, :current].get_action :find }

    its(:summary)     { should =~ /find.*rackspace/im }
    its(:description) { should =~ /find.*rackspace/im }
    its(:returns)     { should =~ /hash/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
