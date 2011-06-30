require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:node, :current] do
  before :all do
    data = Fog::AWS::Compute::Mock.data['us-east-1'][Fog.credentials[:aws_access_key_id]]
    data[:images]['ami-12345'] = { 'imageId' => 'ami-12345' }
    data[:key_pairs]['some_keypair'] = { 'keyName' => 'some_keypair' }
  end

  before :each do
    @options = {
      :platform => 'AWS',
      :image    => 'ami-12345',
      :type     => 'm1.small',
      :keypair  => 'some_keypair'
    }
  end

  describe 'option validation' do
    before :each do
      Puppet::CloudPack.expects(:create).never
    end

    describe '(platform)' do
      it 'should require a platform' do
        @options.delete(:platform)
        expect { subject.create(@options) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the platform' do
        @options[:platform] = 'UnsupportedProvider'
        expect { subject.create(@options) }.to raise_error ArgumentError, /one of/
      end
    end

    describe '(type)' do
      it 'should require a type' do
        @options.delete(:type)
        expect { subject.create(@options) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the tyoe' do
        @options[:type] = 'UnsupportedType'
        expect { subject.create(@options) }.to raise_error ArgumentError, /one of/
      end
    end

    describe '(image)' do
      it 'should require an image' do
        @options.delete(:image)
        expect { subject.create(@options) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the image name' do
        @options[:image] = 'RejectedImageName'
        expect { subject.create(@options) }.to raise_error ArgumentError,
          /unrecognized.*: #{@options[:image]}/i
      end
    end

    describe '(keypair)' do
      it 'should require a keypair name' do
        @options.delete(:keypair)
        expect { subject.create(@options) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the image name' do
        @options[:keypair] = 'RejectedKeypairName'
        expect { subject.create(@options) }.to raise_error ArgumentError,
          /unrecognized.*: #{@options[:keypair]}/i
      end
    end

    describe '(security-group)' do
      it 'should split group names into an array' do
        @options[:group] = %w[ A B C D E ].join(File::PATH_SEPARATOR)
        subject.create(@options) rescue nil
        @options[:group].should == %w[ A B C D E ]
      end

      it 'should validate all group names' do
        @options[:group] = %w[ A B C ]
        expect { subject.create(@options) }.to raise_error ArgumentError,
          /unrecognized.*: #{@options[:group].join(', ')}/i
      end
    end
  end
end
