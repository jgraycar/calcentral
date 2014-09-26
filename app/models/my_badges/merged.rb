module MyBadges
  class Merged < FilteredViewAsModel
    include Cache::LiveUpdatesEnabled

    GOOGLE_SOURCES = {
      'bcal' => GoogleCalendar,
      'bdrive' => GoogleDrive,
      'bmail' => GoogleMail
    }

    def initialize(uid, options={})
      super(uid, options)
      @now_time = Time.zone.now

      # set law_student to true if user's only college is School of Law
      profile_feed = Bearfacts::Profile.new({:user_id => @uid}).get
      doc = profile_feed[:xml_doc]
      @law_student = false
      if !(doc.blank? || doc.css("studentGeneralProfile").blank?)
        general_profile = doc.css("studentGeneralProfile")
        @law_student = general_profile.css("collegePrimary").text.strip.eql? "LAW"
      end
    end

    def get_feed_internal
      feed = {
        badges: get_google_badges,
        studentInfo: StudentInfo.new(@uid).get,
        isLawStudent: @law_student
      }
      feed[:alert] = EtsBlog::Alerts.new.get_latest if Settings.features.app_alerts
      logger.debug "#{self.class.name} get_feed is #{feed.inspect}"
      feed
    end

    def filter_for_view_as(feed)
      filtered_badges = {}
      GOOGLE_SOURCES.each_key do |key|
        filtered_badges[key] = {
          count: 0,
          items: []
        }
      end
      feed[:badges] = filtered_badges
      feed
    end

    def get_google_badges
      badges = {}
      if GoogleApps::Proxy.access_granted?(@uid)
        GOOGLE_SOURCES.each do |key, provider|
          badges[key] = provider.new(@uid).fetch_counts
        end
      end
      badges
    end

  end
end
