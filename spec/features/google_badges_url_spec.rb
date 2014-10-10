require 'spec_helper'
require 'headless'
require 'selenium-webdriver'

feature 'MyBadges urls:' do
  def selenium_check_url_exists(url, truthy_match = nil)
    truthy_match ||= url
    visit url
    within("div.signin-card") {
      fill_in "Email", with: Settings.google_proxy.test_user_email
      fill_in "Passwd", with: Settings.google_proxy.test_user_password
      click_button "signIn"
    }
    visit url
    sleep 5 #waiting for redirect
    current_url.include?(truthy_match).should be_truthy
    malformed_link = url[0..-2] + "ohnoes"
    visit malformed_link
    sleep 5 #waiting for redirect
    current_url.include?(malformed_link).should be_falsey
  end

  before(:all) do
    @headless = Headless.new(display: 98)
    @headless.start
  end

  after(:all) do
    @headless.destroy if @headless
  end

  before(:each) do
    Capybara.current_driver = :selenium
    @user_id = rand(999999).to_s
    @real_mail_list = GoogleApps::MailList.new(
      :fake => false,
      :access_token => Settings.google_proxy.test_user_access_token,
      :refresh_token => Settings.google_proxy.test_user_refresh_token,
      :expiration_time => 0
    )
    @real_calendar_events = GoogleApps::EventsRecentItems.new(
      :fake => false,
      :access_token => Settings.google_proxy.test_user_access_token,
      :refresh_token => Settings.google_proxy.test_user_refresh_token,
      :expiration_time => 0
    )
    @fake_calendar_events = GoogleApps::EventsRecentItems.new(:fake => true)
  end

  scenario 'see if munged urls from google_calendar badges resolve', :testext => true do
    #This requires an existing event to be exist from the time listed below.
    event_listed_after = "2013-05-09T12:42:02-07:00"
    GoogleApps::Proxy.stub(:access_granted?).and_return(true)
    GoogleApps::EventsRecentItems.stub(:new).and_return(@real_calendar_events)
    results = MyBadges::GoogleCalendar.new(@user_id).fetch_counts(
      {
        timeMin: event_listed_after,
        updatedMin: nil
      })
    results[:items].size.should_not == 0
    first_link = results[:items].first[:link]
    eid = Rack::Utils.parse_query(URI.parse(first_link).query)['eid']
    selenium_check_url_exists(first_link, eid)
  end

  scenario 'see if mungled ruls from google_calendar badges != passed through urls for berkeley.edu tokens' do
    User::Oauth2Data.stub(:get_google_email).and_return("oski.the.creepy.bear@berkeley.edu")
    GoogleApps::Proxy.stub(:access_granted?).and_return(true)
    GoogleApps::EventsRecentItems.stub(:new).and_return(@fake_calendar_events)
    raw_feed = GoogleApps::EventsRecentItems.new(@uid).recent_items.first.data["items"]
    munged_feed = MyBadges::GoogleCalendar.new(@user_id).fetch_counts
    # find something where title is == summary
    found_matching_item = false
    munged_feed[:items].each do |item|
      matched_items = raw_feed.select {|raw_item| raw_item["summary"] == item[:title]}
      if matched_items.present?
        matched_items.first["htmlLink"].should_not == item[:link]
        found_matching_item = true
        break
      end
    end
    #makes sure something was tested.
    found_matching_item.should_not be_falsey
  end
end
