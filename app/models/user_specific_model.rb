class UserSpecificModel < AbstractModel

  def self.from_session(session_state)
    self.new(session_state[:user_id], {
      original_user_id: session_state[:original_user_id],
      lti_authenticated_only: session_state[:lti_authenticated_only]
    })
  end

  def initialize(uid, options={})
    super(uid, options)
    @uid = uid
    @law_student = false
    profile_feed = Bearfacts::Profile.new({:user_id => uid}).get
    doc = profile_feed[:xml_doc]
    if !(doc.blank? || doc.css("studentGeneralProfile").blank?)
      general_profile = doc.css("studentGeneralProfile")
      #primary_college = to_text(general_profile.css("collegePrimary"))
      # check to see what procedure should be for multi-college students
      #second_college = to_text(general_profile.css("collegeSecond"))
      #third_college = to_text(general_profile.css("collegeThird"))
      # The above is what they use in CollegeAndLevel,
      # but it errored out when testing with UID 212381 (from college_and_level_spec.rb)
      primary_college = general_profile.css("collegePrimary").text.strip
      second_college = general_profile.css("collegeSecond").text.strip
      third_college = general_profile.css("collegeThird").text.strip
      if [primary_college, second_college, third_college].include? "LAW"
        @law_student = true
      end
    end
  end

  def law_student?
    return @law_student
  end

  def indirectly_authenticated?
    self.class.session_indirectly_authenticated?(@options.merge(user_id: @uid))
  end

  def self.session_indirectly_authenticated?(session_state)
    return true if session_state[:lti_authenticated_only]
    uid = session_state[:user_id]
    original_uid = session_state[:original_user_id]
    current_user = User::Auth.get(uid)
    original_uid && uid != original_uid && !current_user.is_test_user
  end

end
