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
    @law_student = law_student?(uid)
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
