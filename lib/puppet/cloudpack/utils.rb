module Puppet::CloudPack::Utils
  class RetryException < Exception
  end
  
  def self.retry_action(retries=3, pause=0)
    # Helper method to retry actions n number of times, re-raise the exception
    # after the retry count has been met.
    unless block_given?
      raise RetryException, 'No block given'
    end
    begin
      yield
    rescue 
      sleep pause if pause > 0
      if (retries -= 1) > 0
        retry
      else 
        raise
      end
    end
  end
end
