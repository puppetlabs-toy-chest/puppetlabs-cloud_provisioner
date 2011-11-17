require 'spec_helper'

describe 'puppet node_rackspace list' do
  subject { Puppet::Face[:node_rackspace, :current] }

  describe 'option validation' do
    context 'without any options' do
      it 'should require kind' do
        pattern = /wrong number of arguments/
        expect { subject.list }.to raise_error ArgumentError, pattern
      end
    end
  end

  describe 'the behavior of list' do
    before :each do
      Puppet::CloudPack::Rackspace.any_instance.stubs(:create_connection).returns(model)
    end

    context 'when kind is images' do
      images = {
        :body => {
          'images' => [
            { 'name'    => 'Debian 6 (Squeeze)',
              'id'      => 104,
              'updated' => '2011-10-27T12:20:27-05:00',
              'status'  => 'ACTIVE'
            }
          ]
        }
      }

      let(:model) do
        mock('Fog::Compute[:rackspace]') do
          expects(:list_images_detail).returns(self)
          expects(:attributes).returns(images)
        end
      end

      let(:kind) { 'images' }

      it 'should set kind to images' do
        subject.list(kind)[:kind].should == 'images'
      end

      it 'should return a list of images' do
        subject.list(kind)[:images].should be_a_kind_of(Array)
      end

      it 'should return a list of image attributes' do
        subject.list(kind)[:images].should == images[:body]['images']
      end
    end

    context 'when kind is servers' do
      server_attributes = {
        :id        => '12345678',
        :name      => 'slice12345678',
        :host_id   => '277eed7bbd0aaffdebe80a3b27183837',
        :addresses => { "public" => '127.0.0.1' },
        :state     => 'BUILD',
        :progress  => '0',
      }

      let(:model) do
        mock('Fog::Compute[:rackspace]') do
          expects(:empty?).returns(false)
          expects(:servers).returns(self)
          expects(:collect).yields(self).returns([server_attributes])
          expects(:attributes).returns(server_attributes)
        end
      end

      let(:kind) { 'servers' }

      it 'should set kind to servers' do
        subject.list(kind)[:kind].should == 'servers'
      end

      it 'should return a list of servers' do
        subject.list(kind)[:servers].should be_a_kind_of(Array)
      end

      it 'should return a list of servers attributes' do
        subject.list(kind)[:servers].should == [server_attributes]
      end
    end

    context 'when kind is flavors' do
      flavors = {
        :body => {
          'flavors' => [
            { 'name' => '256 server', 'id' => 1, 'ram' => 256, 'disk' => 10 },
            { 'name' => '512 server', 'id' => 2, 'ram' => 512, 'disk' => 20 }
          ]
        }
      }

      let(:model) do
        mock('Fog::Compute[:rackspace]') do
          expects(:list_flavors_detail).returns(self)
          expects(:attributes).returns(flavors)
        end
      end

      let(:kind) { 'flavors' }

      it 'should set kind to flavors' do
        subject.list(kind)[:kind].should == 'flavors'
      end

      it 'should return a list of flavors' do
        subject.list(kind)[:flavors].should be_a_kind_of(Array)
      end

      it 'should return a list of flavor attributes' do
        subject.list(kind)[:flavors].should == flavors[:body]['flavors']
      end
    end
  end

  describe 'inline documentation' do
    subject { Puppet::Face[:node_rackspace, :current].get_action :list }

    its(:summary)     { should =~ /list.*rackspace/im }
    its(:description) { should =~ /list.*rackspace/im }
    its(:returns)     { should =~ /hash/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
