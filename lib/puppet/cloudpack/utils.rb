module Puppet::CloudPack::Utils
  class RetryException < Exception; end
  class RetryException::NoBlockGiven < RetryException; end
  class RetryException::NoTimeoutGiven < RetryException;end
  class RetryException::Timeout < RetryException; end

  def self.retry_action( parameters = { :retry_exceptions => nil, :timeout => nil } )
    # Retry actions for a specified amount of time. This method will allow the final
    # retry to complete even if that extends beyond the timeout period.
    unless block_given?
      raise RetryException::NoBlockGiven
    end

    raise RetryException::NoTimeoutGiven if parameters[:timeout].nil?
    parameters[:retry_exceptions] ||= Hash.new

    start = Time.now
    failures = 0

    begin
      yield
    rescue Exception => e
      # If we were giving exceptions to catch,
      # catch the excptions we care about and retry.
      # All others fail hard

      raise RetryException::Timeout if timedout?(start, parameters[:timeout])

      retry_exceptions = parameters[:retry_exceptions]

      if ! retry_exceptions.empty?
        if retry_exceptions.include?(key = e.class) or
           retry_exceptions.include?(key = key.name.to_s) or
           retry_exceptions.include?(key = key.to_sym)
        then
          Puppet.info("Caught exception #{e.class}: #{e}")
          Puppet.info(retry_exceptions[key])
        else
          # If the exceptions is not in the list of retry_exceptions re-raise.
          raise e
        end
      end

      failures += 1
      # Increase the amount of time that we sleep after every
      # failed retry attempt.
      sleep (((2 ** failures) -1) * 0.1)

      retry

    end
  end

  def self.timedout?(start, timeout)
    return true if timeout.nil?
    (Time.now - start) >= timeout
  end
end
