class BaseProxy
  extend Cache::Cacheable
  include ClassLogger

  attr_accessor :fake, :settings

  def initialize(settings, options = {})
    @settings = settings
    @fake = (options[:fake] != nil) ? options[:fake] : @settings.fake
    @uid = options[:user_id]
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

  def verify_ssl?
    Settings.application.layer == 'production'
  end

  # HTTParty is our preferred HTTP connectivity lib. Use this get_response method wherever possible.
  def get_response(url, additional_options={})
    ActiveSupport::Notifications.instrument('proxy', {url: url, class: self.class}) do
      HTTParty.get(
        url,
        {
          timeout: Settings.application.outgoing_http_timeout,
          verify: verify_ssl?
        }.merge(additional_options)
      )
    end
  end

end
