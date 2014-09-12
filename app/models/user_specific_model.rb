class UserSpecificModel < AbstractModel
  attr_reader :authentication_state

  def self.from_session(session_state)
    self.new(session_state[:user_id], {
      original_user_id: session_state[:original_user_id],
      lti_authenticated_only: session_state[:lti_authenticated_only]
    })
  end

  def initialize(uid, options={})
    super(uid, options)
    @uid = uid
    @authentication_state = AuthenticationState.new(@options.merge(user_id: @uid))
    @law_student = false
    profile_feed = Bearfacts::Profile.new({:user_id => uid}).get
    doc = profile_feed[:xml_doc]
    if !(doc.blank? || doc.css("studentGeneralProfile").blank?)
      general_profile = doc.css("studentGeneralProfile")
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

  def directly_authenticated?
    @authentication_state.directly_authenticated?
  end

end
