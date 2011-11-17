require 'spec_helper'

describe 'puppet node_rackspace terminate' do
  subject { Puppet::Face[:node_rackspace, :current] }

  describe 'option validation' do
    context 'without any options' do
      it 'should require serverid' do
        pattern = /wrong number of arguments/
        expect { subject.terminate }.to raise_error ArgumentError, pattern
      end
    end
  end

  describe 'the behavior of terminate' do
    before :each do
      Puppet::CloudPack::Rackspace.any_instance.stubs(:create_connection).returns(servers)
    end

    context 'when a cloud server matches the serverid' do
      let(:servers) do
        mock('Fog::Compute[:rackspace]') do
          expects(:servers).returns(self)
          expects(:get).returns(self)
          expects(:destroy).once
        end
      end

      it 'should accept a serverid' do
        subject.terminate('12345678')
      end

      it 'should return a status hash' do
        subject.terminate('12345678').should be_a_kind_of(Hash)
      end
    end

    context 'when no cloud servers match the serverid' do
      let(:servers) do
        mock('Fog::Compute[:rackspace]') do
          expects(:servers).returns(self)
          expects(:get).returns(nil)
          expects(:destroy).never
        end
      end

      it 'should not invoke destory' do
        subject.terminate('12345678')
      end
    end
  end

  describe 'inline documentation' do
    subject { Puppet::Face[:node_rackspace, :current].get_action :terminate }

    its(:summary)     { should =~ /terminate.*rackspace/im }
    its(:description) { should =~ /terminate.*rackspace/im }
    its(:returns)     { should =~ /hash/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
