module MyAcademics
  class Merged < UserSpecificModel

    include Cache::LiveUpdatesEnabled

    def get_feed_internal
      feed = {}
      if law_student?
        # Currently providing same information, but eventually could make different if
        # also modify what controller expects
        providers = [
         LawCollegeAndLevel,
         LawGpaUnits,
         LawRequirements,
         LawRegblocks,
         LawSemesters,
         LawTeaching,
         LawExams,
         LawTelebears,
         LawCanvasSites,
         LawSakaiSites
        ]
      else
        # Provider ordering is significant! In particular, Semesters/Teaching must
        # be merged before course sites.
        providers = [
         CollegeAndLevel,
         GpaUnits,
         Requirements,
         Regblocks,
         Semesters,
         Teaching,
         Exams,
         Telebears,
         CanvasSites,
         SakaiSites
        ]
      end
      providers.each do |provider|
        provider.new(@uid).merge(feed)
      end
      feed
    end

  end
end
