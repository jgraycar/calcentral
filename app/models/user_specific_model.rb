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

    # set law_student to true if user's only college is School of Law
    profile_feed = Bearfacts::Profile.new({:user_id => uid}).get
    doc = profile_feed[:xml_doc]
    @law_student = false
    if !(doc.blank? || doc.css("studentGeneralProfile").blank?)
      general_profile = doc.css("studentGeneralProfile")
      @law_student = general_profile.css("collegePrimary").text.strip.eql? "LAW"
    end
  end

  def directly_authenticated?
    @authentication_state.directly_authenticated?
  end

end
