class BaseProxy
  extend Cache::Cacheable
  include ClassLogger

  attr_accessor :fake, :settings

  def initialize(settings, options = {})
    @settings = settings
    @fake = (options[:fake] != nil) ? options[:fake] : @settings.fake
    @uid = options[:user_id]
    @law_student = law_student?(@uid)
  end

  def law_student?(uid)
    is_law_student = false
    profile_feed = Bearfacts::Profile.new({:user_id => uid}).get
    doc = profile_feed[:xml_doc]
    if !(doc.blank? || doc.css("studentGeneralProfile").blank?)
      general_profile = doc.css("studentGeneralProfile")
      primary_college = to_text(general_profile.css("collegePrimary"))
      # check to see what procedure should be for multi-college students
      second_college = to_text(general_profile.css("collegeSecond"))
      third_college = to_text(general_profile.css("collegeThird"))
      if [primary_college, second_college, third_college].include? "LAW"
        is_law_student = true
      end
    end
    return is_law_student
  end
    
  # by default, all merged models will prevent act as users to read their
  # data without the enable_for_act_as mix-in.
  def self.allow_pseudo_user?
    false
  end

  def lookup_student_id
    student = CampusOracle::UserAttributes.new(user_id: @uid).get_feed
    student.try(:[], "student_id")
  end

end
