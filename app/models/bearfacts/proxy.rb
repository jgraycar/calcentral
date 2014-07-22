module Bearfacts
  class Proxy < BaseProxy

    include ClassLogger
    include User::Student

    APP_ID = "Bearfacts"

    def initialize(options = {})
      super(Settings.bearfacts_proxy, options)
    end

    def self.expires_in
      self.bearfacts_derived_expiration
    end

    def request(path, vcr_cassette, params = {})
      raw_response = self.class.smart_fetch_from_cache({id: @uid, user_message_on_exception: "Remote server unreachable"}) do
        request_internal(path, vcr_cassette, params)
      end
      parsed_response = {}
      if raw_response[:statusCode] < 400
        # Nokogiri does not serialize to cache reliably.
        parsed_response[:xml_doc] = xml_doc(raw_response[:body])
      elsif raw_response[:statusCode] == 400
        parsed_response[:noStudentId] = true
      else
        parsed_response[:errored] = true
      end
      parsed_response
    end

    def xml_doc(xml_string)
      return nil unless xml_string
      begin
        Nokogiri::XML(xml_string, &:strict)
      rescue Nokogiri::XML::SyntaxError
        logger.error("Error parsing '#{xml_string}' for user #{@uid}")
        nil
      end
    end

    def request_internal(path, vcr_cassette, params = {})
      student_id = lookup_student_id
      if student_id.nil?
        logger.info "Lookup of student_id for uid #@uid failed, cannot call Bearfacts API path #{path}"
        return {
          statusCode: 400
        }
      else
        url = "#{Settings.bearfacts_proxy.base_url}#{path}"
        logger.info "Fake = #@fake; Making request to #{url} on behalf of user #{@uid}, student_id = #{student_id}; cache expiration #{self.class.expires_in}"
        response = ActiveSupport::Notifications.instrument('proxy', { url: url, class: self.class }) do
          FakeableProxy.wrap_request(APP_ID + "_" + vcr_cassette, @fake, {:match_requests_on => [:method, :path]}) {
            token_params = {token: Settings.bearfacts_proxy.token}
            if (Settings.bearfacts_proxy.app_id.present? && Settings.bearfacts_proxy.app_key.present?)
              token_params.merge!({app_id: Settings.bearfacts_proxy.app_id,
                                   app_key: Settings.bearfacts_proxy.app_key, })
            end

            Faraday::Connection.new(
              :url => url,
              :params => params.merge(token_params),
              :ssl => {:verify => false},
              :request => {
                :timeout => Settings.application.outgoing_http_timeout
              }
            ).get
          }
        end
        if response.status >= 400
          raise Errors::ProxyError.new("Connection failed: #{response.status} #{response.body}; url = #{url}")
        end

        logger.debug "Remote server status #{response.status}, Body = #{response.body}"
        return {
          body: response.body,
          statusCode: response.status
        }
      end
    end
  end
end
