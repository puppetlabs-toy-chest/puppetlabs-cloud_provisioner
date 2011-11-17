require 'spec_helper'



describe 'puppet node_rackspace create' do
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
      it 'should require flavor_id' do
        pattern = /are required.+?flavor_id/
        expect { subject.create }.to raise_error ArgumentError, pattern
      end

      it 'should require image_id' do
        pattern = /are required.+?image_id/
        expect { subject.create }.to raise_error ArgumentError, pattern
      end
    end
  end

  describe 'the behavior of create' do
    before :each do
      Puppet::CloudPack::Rackspace.any_instance.stubs(:create_connection).returns(server)
    end

    let(:server) do
      mock('Fog::Compute[:rackspace]') do
        expects(:servers).returns(self)
        expects(:create).returns(self)
        expects(:password).returns('123456789!@#$')
        expects(:attributes).returns(server_attributes)
      end
    end

    context 'with only required arguments' do
      let(:options) do
        { :image_id => '123456', :flavor_id => '1' }
      end

      it 'should create a server' do
        expected_attributes = {
          :id        => '12345678',
          :name      => 'slice12345678',
          :host_id   => '277eed7bbd0aaffdebe80a3b27183837',
          :addresses => { "public" => '127.0.0.1' },
          :state     => 'BUILD',
          :progress  => '0',
          :password  => '*************',
          :status    => 'success'
        }
        subject.create(options).should == [expected_attributes]
      end
    end

    context 'when --show-password is true' do
      let(:options) do
        { :image_id => '123456', :flavor_id => '1', :show_password => true }
      end

      it 'should store the password in clear text' do
        subject.create(options).first[:password].should == '123456789!@#$'
      end
    end

    context 'when --show-password is false' do
      let(:options) do
        { :image_id => '123456', :flavor_id => '1', :show_password => false }
      end

      it 'should mask the password' do
        subject.create(options).first[:password].should == '*************'
      end
    end

    context 'when --wait-for-boot is true' do
      let(:server) do
        mock('Fog::Compute[:rackspace]') do
          expects(:servers).returns(self)
          expects(:create).returns(self)
          expects(:password).returns('123456789!@#$')
          expects(:attributes).returns(server_attributes)
          expects(:ready?).returns(true)
          expects(:wait_for).with { ready? }
        end
      end

      let(:options) do
        { :image_id  => '123456', :flavor_id => '1', :wait_for_boot => true }
      end

      it 'should wait for the server to boot' do
        subject.create(options)
      end
    end

    context 'when --wait-for-boot is false' do
      let(:server) do
        mock('Fog::Compute[:rackspace]') do
          expects(:servers).returns(self)
          expects(:create).returns(self)
          expects(:password).returns('123456789!@#$')
          expects(:attributes).returns(server_attributes)
          expects(:ready?).never
          expects(:wait_for).never
        end
      end

      let(:options) do
        { :image_id  => '123456', :flavor_id => '1', :wait_for_boot => false }
      end

      it 'should not wait for the server to boot' do
        subject.create(options)
      end
    end
  end

  describe 'inline documentation' do
    subject { Puppet::Face[:node_rackspace, :current].get_action :create }

    its(:summary)     { should =~ /create.*rackspace/im }
    its(:description) { should =~ /create.*rackspace/im }
    its(:returns)     { should =~ /hash/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
