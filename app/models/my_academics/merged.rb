module MyAcademics
  class Merged < UserSpecificModel

    include Cache::LiveUpdatesEnabled

    # If MyAcademics ever includes data from data sources OTHER than our Bearfacts materialized views,
    # which are updated only once a day, then remove this in favor of the normal expiration scheme.
    def self.expires_in
      self.bearfacts_derived_expiration
    end

    def get_feed_internal
      # -------------------- my added code ----------------------
      law_student = false
      profile_feed = Bearfacts::Profile.new({:user_id => @uid}).get
      doc = profile_feed[:xml_doc]
      if !(doc.blank? || doc.css("studentGeneralProfile").blank?)
        general_profile = doc.css("studentGeneralProfile")
        primary_college = to_text(general_profile.css("collegePrimary"))
        # check to see what procedure should be for multi-college students
        second_college = to_text(general_profile.css("collegeSecond"))
        third_college = to_text(general_profile.css("collegeThird"))
        if [primary_college, second_college, third_college].include? "LAW"
          law_student = true
        end
      end
      # ------------------ end my added code -------------------- 
      feed = {}
      [
        CollegeAndLevel,
        GpaUnits,
        Requirements,
        Regblocks,
        Semesters,
        Teaching,
        Exams,
        Telebears,
      ].each do |provider|
        provider.new(@uid, law_student).merge(feed)
      end
      feed
    end
  end
end
