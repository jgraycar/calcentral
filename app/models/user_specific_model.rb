class UserSpecificModel < AbstractModel

  def initialize(uid, options={})
    super(uid, options)
    @uid = uid
    if options
      @original_uid = options[:original_user_id]
    end      
    # -------------------- my added code ----------------------
    @law_student = false
    profile_feed = Bearfacts::Profile.new({:user_id => @uid}).get
    doc = profile_feed[:xml_doc]
    if !(doc.blank? || doc.css("studentGeneralProfile").blank?)
      general_profile = doc.css("studentGeneralProfile")
      primary_college = to_text(general_profile.css("collegePrimary"))
      # check to see what procedure should be for multi-college students
      second_college = to_text(general_profile.css("collegeSecond"))
      third_college = to_text(general_profile.css("collegeThird"))
      if [primary_college, second_college, third_college].include? "LAW"
        @law_student = true
      end
    end
    # ------------------ end my added code -------------------- 
  end

  def instance_key
    @uid
  end

  def is_acting_as_nonfake_user?
    current_user = User::Auth.get(@uid)
    @original_uid && @uid != @original_uid && !current_user.is_test_user
  end

end
