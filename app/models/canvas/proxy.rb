module Canvas
  require 'signet/oauth_2/client'

  class Proxy < BaseProxy
    include ClassLogger, SafeJsonParser
    include Cache::UserCacheExpiry

    attr_accessor :client
    APP_ID = "Canvas"
    APP_NAME = "bCourses"

    def initialize(options = {})
      super(Settings.canvas_proxy, options)
      if @fake
        @uid = @settings.test_user_id
      end
      access_token = if @fake
                       'fake_access_token'
                     elsif options[:access_token]
                       options[:access_token]
                     else
                       @settings.admin_access_token
                     end
      @client = Signet::OAuth2::Client.new(:access_token => access_token)
    end

    def request(api_path, vcr_id = "", fetch_options = {})
      self.class.smart_fetch_from_cache(
        {id: @uid,
         user_message_on_exception: "Remote server unreachable",
         return_nil_on_generic_error: true}) do
        request_internal(api_path, vcr_id, fetch_options)
      end
    end

    def request_uncached(api_path, vcr_id = "", fetch_options = {})
      begin
        request_internal(api_path, vcr_id, fetch_options)
      rescue => e
        self.class.handle_exception(e, @uid, "Remote server unreachable", true)
      end
    end

    def request_internal(api_path, vcr_id = "", fetch_options = {})
      fetch_options.reverse_merge!(
        :method => :get,
        :uri => "#{@settings.url_root}/api/v1/#{api_path}"
      )
      logger.info "Making request with @fake = #{@fake}, options = #{fetch_options}, cache expiration #{self.class.expires_in}"
      ActiveSupport::Notifications.instrument('proxy', {url: fetch_options[:uri], class: self.class}) do
        FakeableProxy.wrap_request("#{APP_ID}#{vcr_id}", @fake) do
          if (nonstandard_connection = fetch_options[:non_oauth_connection])
            response = nonstandard_connection.get(fetch_options[:uri])
          else
            response = @client.fetch_protected_resource(fetch_options)
          end
          # Canvas proxy returns nil for error response.
          if response.status >= 400
            if existence_check && response.status == 404
              logger.debug("404 status returned for URL '#{fetch_options[:uri]}', UID #{@uid}")
              return nil
            end
            raise Errors::ProxyError.new(
                    "Connection failed for URL '#{fetch_options[:uri]}', UID #{@uid}: #{response.status} #{response.body}", nil, nil)
          else
            response
          end
        end
      end
    end

    def self.access_granted?(user_id)
      user_id && has_account?(user_id)
    end

    def url_root
      @settings.url_root
    end

    def self.has_account?(user_id)
      Settings.canvas_proxy.fake || (Canvas::SisUserProfile.new(user_id: user_id).sis_user_profile != nil)
    end

    def self.canvas_current_terms
      terms = []
      campus_terms = Berkeley::Terms.fetch
      if (future_term = campus_terms.future) && future_term.name == 'Fall'
        terms.push future_term
      end
      terms.push campus_terms.next if campus_terms.next
      terms.push campus_terms.current
      terms
    end

    def self.current_sis_term_ids
      canvas_current_terms.collect do |term|
        term_to_sis_id(term.year, term.code)
      end
    end

    def self.sis_section_id_to_ccn_and_term(sis_term_id)
      if (parsed = /SEC:(?<term_yr>\d+)-(?<term_cd>[[:upper:]])-(?<ccn>\d+).*/.match(sis_term_id))
        {
          term_yr: parsed[:term_yr],
          term_cd: parsed[:term_cd],
          ccn: parsed[:ccn].to_i.to_s
        }
      end
    end

    def self.term_to_sis_id(term_yr, term_cd)
      "TERM:#{term_yr}-#{term_cd}"
    end

    def next_page_params(response)
      # If the response's link header included a "next" page pointer...
      if response && (next_link = LinkHeader.parse(response['link']).find_link(['rel', 'next']))
        # ... then extract the query string from its URL.
        next_query_string = /.+\?(.+)/.match(next_link.href)[1]
      else
        nil
      end
    end

    def existence_check
      false
    end

  end
end
