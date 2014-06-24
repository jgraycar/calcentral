module MyBadges
  class GoogleMail
    include MyBadges::BadgesModule, DatedFeed, ClassLogger
    include Cache::UserCacheExpiry

    def initialize(uid)
      @uid = uid
      @count_limiter = 25
    end

    def fetch_counts(params = {})
      @google_mail ||= User::Oauth2Data.get_google_email(@uid)
      @rewrite_url ||= !(Mail::Address.new(@google_mail).domain =~ /berkeley.edu/).nil?
      self.class.fetch_from_cache(@uid) do
        internal_fetch_counts params
      end
    end

    private

    def internal_fetch_counts(params = {})
      google_proxy = GoogleApps::MailList.new(user_id: @uid)
      google_mail_results = google_proxy.mail_unread
      logger.debug "Processing GMail XML results: #{google_mail_results.inspect}"
      response = {:count => 0, :items => []}
      if google_mail_results && google_mail_results.response && google_mail_results.response.status == 200
        nokogiri_xml = nil

        begin
          nokogiri_xml = Nokogiri::XML.parse(google_mail_results.response.body)
        rescue => e
          logger.fatal "Error parsing XML output for GoogleApps::MailList: #{e}"
          nokogiri_xml = nil
        end

        if nokogiri_xml
          response[:count] = get_count nokogiri_xml
          response[:items] = get_items nokogiri_xml
        end
      end
      response
    end

    def get_count(nokogiri_xml)
      begin
        nokogiri_xml.search('fullcount').first.content.to_i
      rescue => e
        logger.warn "Error parsing XML output for unread counts from GoogleApps::MailList: #{e}"
        return 0
      end
    end

    def get_items(nokogiri_xml)
      items = []
      begin
        iter_count = 0
        raw_items = get_nodeset('entry', nokogiri_xml)
        raw_items.each do |raw_entry|
          break if iter_count >= @count_limiter
          entry = {}

          begin
            %w(title summary).each do |key|
              entry[key.to_sym] = get_node_value(key, raw_entry)
            end
            entry[:modifiedTime] = get_node_value("modified", raw_entry)
            entry[:link] = "http://bmail.berkeley.edu/"

            author_set = get_nodeset('author', raw_entry.search('author'))
            entry[:editor] = get_node_value('name', author_set)

            #change modified into a proper date.
            if entry[:modifiedTime]
              begin
                entry[:modifiedTime] = format_date DateTime.iso8601(entry[:modifiedTime])
              rescue => e
                logger.warn "Could not parse modified: #{entry[:modifiedTime]}"
                next
              end
            end
            items << entry
            iter_count +=1
          rescue => e
            logger.warn "Unable to parse entry - #{raw_entry}"
            next
          end
        end
        items
      rescue => e
        logger.fatal "Error parsing XML output for mail items from GoogleApps::MailList: #{e}"
        logger.debug "Full dump of xml: #{nokogiri_xml}"
      end
      items
    end

    def get_nodeset(key, nodeset, optional = false)
      result = nodeset.search(key)
      if result.nil? && !optional
        raise ArgumentError, "unmatched key: #{key} on nodeset: #{nodeset}"
      end

      if result && result.is_a?(Nokogiri::XML::NodeSet)
        result
      else
        raise ArgumentError, "Not a Nodeset on key: #{key} type: #{result.class}"
      end

    end

    def get_node_value(key, nodeset, optional = false)
      # TODO: should tidy this up...
      result = nodeset.at_css(key)
      if result.nil? && !optional
        raise ArgumentError, "unmatched key: #{key} on nodeset: #{nodeset}"
      end

      if !result.nil? && !result.content.nil?
        result.content
      elsif !optional
        raise ArgumentError, "non-leaf node on key: #{key} value: #{result}"
      end
    end
  end
end
