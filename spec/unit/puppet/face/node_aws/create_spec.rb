require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Face[:node_aws, :current] do
  before :all do
    data = Fog::Compute::AWS::Mock.data['us-east-1'][Fog.credentials[:aws_access_key_id]]
    data[:images]['ami-12345'] = { 'imageId' => 'ami-12345' }
    data[:key_pairs]['some_keypair'] = { 'keyName' => 'some_keypair' }
    data[:security_groups]['A'] = { 'groupName' => 'A', 'groupId' => 'sg-deadbeef' }
    data[:security_groups]['D'] = { 'groupName' => 'D', 'groupId' => 'sg-deafd0d0' }
  end

  let :options do
    {
      :image    => 'ami-12345',
      :type     => 'm1.small',
      :keyname  => 'some_keypair',
      :region   => 'us-east-1',
    }
  end

  describe 'option validation' do
    before :each do
      Puppet::CloudPack.expects(:create).never
    end

    describe '(tags)' do
      it 'should exit on improper value' do
        options[:instance_tags] = 'tag1=value2,tag2=value,=broken'
        expect { subject.create(options) }.to raise_error ArgumentError, /could not parse/i
      end

      it 'should produce a hash correctly' do
        options[:instance_tags] = 'tag1=value1,tag2=value2,tag3=value3.1=value3.2'
        Puppet::CloudPack.expects(:create).with() do |opts|
          opts[:instance_tags].should == {
            'tag1' => 'value1',
            'tag2' => 'value2',
            'tag3' => 'value3.1=value3.2'
          }
        end
        subject.create(options)
      end

    end

    describe '(type)' do
      it 'should require a type' do
        options.delete(:type)
        expect { subject.create(options) }.to raise_error ArgumentError, /required/
      end
    end

    describe '(image)' do
      it 'should require an image' do
        options.delete(:image)
        expect { subject.create(options) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the image name' do
        options[:image] = 'RejectedImageName'
        expect { subject.create(options) }.to raise_error ArgumentError,
          /unrecognized.*: #{options[:image]}/i
      end
    end

    describe '(keyname)' do
      it 'should require a keyname' do
        options.delete(:keyname)
        expect { subject.create(options) }.to raise_error ArgumentError, /required/
      end

      it 'should validate the image name' do
        options[:keyname] = 'RejectedKeypairName'
        expect { subject.create(options) }.to raise_error ArgumentError,
          /unrecognized.*: #{options[:keyname]}/i
      end
    end
    describe '(region)' do
      it "should set the region to us-east-1 if no region is supplied" do
        # create a connection before we start fiddling with the options
        connection = Puppet::CloudPack.create_connection(options)
        options.delete(:region)
        Puppet::CloudPack.expects(:create)
        # Note that we need to provide the return value so that
        # no exceptions are thrown from the code which calls
        # the create_connection method and expects it to return
        # something reasonable (i.e. non-nil)
        Puppet::CloudPack.stubs(:create_connection).with() do |opts|
          opts[:region].should == 'us-east-1'
        end.returns(connection)
        subject.create(options)
      end

      it 'should validate the region' do
        options[:region] = 'mars-east-100'
        expect { subject.create(options) }.to raise_error ArgumentError, /Unknown region/
      end
    end

    describe '(security-group)' do
      it 'should call group_option_before_action' do
        options[:security_group] = %w[ A B C D E ].join(File::PATH_SEPARATOR)
        Puppet::CloudPack.expects(:create)
        # This makes sure the before_action calls the group_option_before_action
        # correctly with the options we've specified.
        Puppet::CloudPack.stubs(:group_option_before_action).with() do |opts|
          opts[:security_group].should == options[:security_group]
        end
        subject.create(options)
      end

      it 'should validate all group names' do
        options[:security_group] = %w[ A B C ]
        # note that the group 'A' is mocked to be known to AWS in the 'before :all' block
        # at the start of this file
        expect { subject.create(options) }.to raise_error ArgumentError,
          /unrecognized.*: #{Regexp.quote(%w[ B C ].join(', '))}/i
      end

      it 'should produce an array of security group IDs correctly' do
        options[:security_group] = %w[ sg-deadbeef D ].join(File::PATH_SEPARATOR)
        Puppet::CloudPack.expects(:create).with() do |opts|
          opts[:security_group].should == %w[ sg-deadbeef sg-deafd0d0 ]
        end
        subject.create(options)
      end
    end
  end
end
