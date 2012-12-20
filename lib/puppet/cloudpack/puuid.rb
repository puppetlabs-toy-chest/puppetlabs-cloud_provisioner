begin
  # Part of Ruby 1.9.2+ stdlib, prior versions
  # have this module but without the 'uuid' function.
  require 'securerandom'
  if defined? SecureRandom.uuid
    guid_function = lambda { SecureRandom.uuid.to_s }
    guid_provider = 'securerandom'
  end
rescue LoadError
end

unless guid_function
  begin
    require 'guid'
    guid_function = lambda { Guid.new.to_s }
    guid_provider = 'guid'
  rescue LoadError
  end
end

unless guid_function
  begin
    require 'uuid'
    guid_function = lambda { UUID.generate.to_s }
    guid_provider = 'uuid'
  rescue LoadError
  end
end

unless guid_function
  begin
    require 'uuidtools'
    guid_function = lambda { UUIDTools::UUID.random_create.to_s }
    guid_provider = 'uuidtools'
  rescue LoadError
  end
end


unless guid_function
  raise 'Could not find UUID function in SecureRandom or in Gems guid, uuid, or uuidtools'
end

module Puppet::CloudPack::PUUID
  def uuid
    guid_function.call
  end
end
