require 'puppet'
require 'google/api_client'

require 'pathname'

# A helper to capture logic around authentication and interaction with the
# Google API, especially around authentication with the OAuth2 system.
#
# @api private
class Puppet::GoogleAPI
  # The list of "standard" projects to search for images when hunting by name;
  # the Google supplied images live in these.
  StandardImageProjects  = ['debian-cloud', 'centos-cloud']

  # Create a new instance; this will implicitly authorize if required, or
  # otherwise refresh the access token.  It makes state changes in the rest of
  # the system -- potentially storing the refresh token in the statedir, or
  # updating cached data about the token for other clients.
  #
  # @warning since this deals with shared on-disk state, and contains a
  # password-equivalent authorization, we need to make sure that we treat the
  # file content as atomic, as well as secure, against cross-process activity.
  #
  # @warning I am making the assumption that "last update wins" is the correct
  # policy for handling on-disk storage of tokens, since no other guidance was
  # given by Google documentation.  No effort has been made to, eg, merge
  # partial updates to authentication state, etc.
  #
  # @param client_id [String] the (optional) client ID to use during
  # the registration / auth query process if that is required
  #
  # @param client_secret [String] the (optional) client secret to use during
  # the registration / auth query process if that is required.
  #
  # @note you are under no obligation to supply a client id or secret while
  # setting this up and, in most cases, you probably shouldn't supply them.
  # If a previous set were given we will have them stored away in our state
  # supply as required -- and if not, the user should call `register` at the
  # face level and provide them.  Don't routinely supply these data.
  def initialize(client_id = nil, client_secret = nil)
    # First, load our state from disk if it is available.
    load_state!

    # ...and now try and authenticate with the server; this will request
    # authorization if required.
    authenticate!(client_id, client_secret)
  end

  def discover(name, version)
    # @todo danielp 2013-09-13: we should cache the discovery document and
    # reuse it if it is fresh enough here; see
    # https://code.google.com/p/google-api-ruby-client/#APIs_Discovery_Service
    # for an example of the `register_discovery_document`; basically, cache
    # the "discovery document" hash to disk, and feed it through that.
    #
    # Right now we take the hit of a full HTTP fetch for every discovery which
    # is going to be heavier and slower than we ultimately want in production.
    client.discovered_api(name, version)
  end

  def execute(method, parameters = {}, body = nil)
    # We have to do our own handling, as the execute! method -- which throws
    # great errors most of the time -- doesn't have anything to support 401
    # specially, and worse, doesn't have suitable hooks to allow us to stash
    # away our auth state if and only if it changed.
    args = {
      :api_method  => method,
      :parameters  => parameters,
      :body_object => body
    }
    result = client.execute(args)
    if result.status == 401     # reauthenticate and retry
      authenticate!
      execute(method, parameters)
    elsif result.status != 200
      # @todo danielp 2013-09-17: I am thinking that maybe a 404 result should
      # return either an empty array (for convenience in punning) or nil,
      # since that is a more "normal" failure than any of the alternatives...
      raise "#{method} failed #{result.status}: #{result.error_message || 'unknown error'}"
    end

    # We return the data content; that includes support for fetching further
    # pages, which we handle here, returning an array of one or more bodies to
    # the caller.
    if result.data.respond_to?('next_page_token')
      # We might have multiple pages of results, collect them all, and return
      # them in an array of multiple items.  Since they potentially have
      # specialized item storage formats by type, we can't generically do
      # anything to vivify the final object format.
      page = result.data
      results = []
      while page do
        results << page
        page = page.next_page_token ? page.next_page : nil
      end
      results
    else
      # Just return the single result, in an array, to match the API with the
      # paged data above.
      #
      # @todo danielp 2013-09-16: it isn't clear this is needed, since we
      # already need specialized knowledge in the caller, but ...
      [result.data]
    end
  end

  def compute
    @compute ||= Puppet::GoogleAPI::Compute.new(self)
  end


  # A helper to render a hash as human-focused text
  #
  # @todo danielp 2013-09-16: I don't like putting this here, but there
  # doesn't seem to be anywhere better, and Puppet doesn't offer
  # the capability.  The default behaviour is "render as a human-hostile JSON
  # string", so that won't do either.  Oh, well.
  def self.hash_to_human_s(hash)
    keylen = hash.keys.map{|k| k.to_s.length}.max
    hash.map do |key, value|
      key.to_s.rjust(keylen) + ': ' +
        value.to_s.gsub("\n", "\n#{' ' * (keylen + 2)}")
    end.join("\n")
  end

  ########################################################################
  private

  def authenticate!(client_id = nil, client_secret = nil)
    # Process:
    # 1. Try and load credentials from disk, and see if the auth token is
    #    still valid.
    # 2. See if we have a refresh token to obtain a new auth token.
    # 3. If we got registration details, request auth via the browser and
    #    stash away the tokens we got in return.
    # 4. Fail with an informative message asking the user to register.

    # Next, see if we have an access token.  If we do, and it has not expired,
    # life is simple and we just stop.  We can make requests right now.  (The
    # case where we expire between this check and the first invocation is
    # handled by our other methods, later.
    return if client.authorization.access_token and not client.authorization.expired?

    # If we have a refresh token then we can try and obtain a new access token
    # using it.  This may explode if the user revoked our access.
    #
    # @note this technically doesn't need to happen now: as long as we have a
    # refresh token, we should be bale to automatically retry operations that
    # get a 401 back from the server, and if that works we should be good.
    if client.authorization.refresh_token
      client.authorization.fetch_access_token!

      # Since we updated stuff, store our state right on back to disk for
      # later use.  This avoids refreshing the token early if it would still
      # be valid for a subsequent operation -- which avoids rate limiting that
      # Google (quite reasonably) impose on clients.
      save_state!
    end

    # If that was sufficient to get our token, stop working.
    return if client.authorization.access_token and not client.authorization.expired?

    if client_id and client_secret
      # We can try the registration workflow and see if that gets us an
      # appropriate token.  It should, since it is the only path to complete
      # this process.
      client.authorization.client_id     = client_id
      client.authorization.client_secret = client_secret
      # @todo danielp 2013-09-19: I don't think we need access to anything
      # beyond basic compute, so limiting it to that for now.  However, that
      # means that this isn't a general API wrapper, only a compute
      # specific wrapper.  Should we fix that?
      client.authorization.scope         = 'https://www.googleapis.com/auth/compute'
      # 'out of band' auth response: this gives the user a token they need to
      # copy and paste back into our application to authenticate.
      client.authorization.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'

      # Let the user know what URL they have to visit, and prompt them to
      # enter the generated token.  This is, necessarily an interactive
      # process -- making it impossible to automate anything with this tool,
      # if you don't have a human sitting there.  Such is life.
      $stdout.puts <<EOT
At this stage you will need to grant node_gce authorization to access the
Google Compute API through your generated credentials.  In order to do that
you must copy and paste this URL into a web browser:

#{client.authorization.authorization_uri}

When you have proceeded through the authorization workflow, a token will be
generated for you to put back into the system.  Please paste that token here
and hit return; we will then verify the token with Google and exchange it for
a set of persistent credentials.

EOT

      $stdout.write "Enter authorization code: "
      client.authorization.code = $stdin.gets.chomp

      # This performs the validation and token exchange.  This will raise with
      # a reasonable error message if the process fails for some reason.
      client.authorization.fetch_access_token!

      # If we got this far, everything was successful, and we should store
      # away the authentication data for later use.
      save_state!
    end

    # If that was sufficient to get our token, stop working.
    return if client.authorization.access_token and not client.authorization.expired?

    # If we got here, nothing else worked, so we fail with a message informing
    # the user about what went wrong and just give it up.
    raise "No GCE credentials available; please `puppet node_gce register` with the GCE console"
  end

  def client
    @client ||= Google::APIClient.new(
      :application_name    => 'Puppet Cloud Provisioner',
      :application_version => '1.0.0',
      # This seems like something you would want, right?  The client
      # automatically retries any 401 after refreshing the token.  Well, that
      # would work with one caveat: it has *no* hooks to allow saving the
      # state of the updated token, and no indication it happened.
      #
      # Which means that we would either (a) save our state optimistically
      # after every single remote operation, or (b) end up refreshing much
      # more often than we technically need to, risking rate limiting and
      # abuse detection from Google.
      #
      # So, we take that the path of least resistance, provide our own
      # handling of the 401 error, and turn off the implicit support.
      :auto_refresh_token  => false)
  end


  def state_file
    Pathname(Puppet[:statedir]) + 'google-api-auth.json'
  end

  def load_state!
    content = state_file.read rescue nil
    return unless content

    content = PSON.parse(content) rescue nil
    return unless content

    # Check our version, and handle obsolete stored data; this is a simple
    # integer to bump when semantics change or whatever.  If you need to do
    # anything other than panic, just do it. :)
    content['version'] == 3 or raise "unknown stored state version #{content['version']}"

    # We have our content, update the auth data with it.
    #
    # @todo danielp 2013-09-12: this might be more closely tied to the
    # implementation than I would otherwise like, but by copying *all* the
    # data that was present in the original and reinjecting it I hope we avoid
    # the worst possible failure modes.
    client.authorization.update!(
      'client_id'            => content['authorization']['client_id'],
      'client_secret'        => content['authorization']['client_secret'],
      'access_token'         => content['authorization']['access_token'],
      'refresh_token'        => content['authorization']['refresh_token'],
      'expires_in'           => content['authorization']['expires_in'],
      # This *MUST* be converted to a time instance to satisfy Signet!
      'issued_at'            => Time.at(content['authorization']['issued_at']),
      'authorization_uri'    => 'https://accounts.google.com/o/oauth2/auth',
      'token_credential_uri' => 'https://accounts.google.com/o/oauth2/token',
      # I hope this is correct: it should match the installed app flow we use
      # to do the formal auth process.  (Perhaps we should consider bringing
      # that code inline rather than using the supplied version?)
      'redirect_uri'         => 'urn:ietf:wg:oauth:2.0:oob'
    )
  end

  # Save our current object state to disk, ready to reload later with
  # `load_state!`.
  #
  # @todo danielp 2013-09-12: this implicitly saves state of the client,
  # rather than explicitly being told what state to save.  IMO, that is the
  # correct model since we are trying to hide our internals, but... I can't
  # help but feel a little unsure that is the right pattern.
  def save_state!
    data = {
      # This reflects the "schema" and semantics of this data; bump this if
      # you ever change the content or structure of the hash to avoid data
      # loss or other problems.
      'version' => 3,
      'authorization' => {
        # The fields to save from the authorization object.
        'client_id'            => client.authorization.client_id,
        'client_secret'        => client.authorization.client_secret,
        'access_token'         => client.authorization.access_token,
        'refresh_token'        => client.authorization.refresh_token,
        'expires_in'           => client.authorization.expires_in,
        # This is returned as a Time instance from Signet
        'issued_at'            => client.authorization.issued_at.to_i,
      }
    }

    Puppet::Util.replace_file(state_file, 0600) {|fh| fh.puts(data.to_pson) }
  end
end

require 'puppet/google_api/compute'
