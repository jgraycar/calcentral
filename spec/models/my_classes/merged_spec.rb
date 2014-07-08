require "spec_helper"

describe MyClasses::Merged do
  let(:user_id) {rand(99999).to_s}

  describe '#get_feed_internal' do
    context 'when no campus course associations or LMS access' do
      subject { MyClasses::Merged.new(user_id).get_feed }
      before {Canvas::Proxy.stub(:access_granted?).with(user_id).and_return(false)}
      before {Sakai::Proxy.stub(:access_granted?).with(user_id).and_return(false)}
      before {CampusOracle::UserCourses.stub(:new).and_return(double({get_all_campus_courses: {}}) )}
      its([:classes]) {should eq []}
      its([:current_term]) {should be_present}
    end
    context 'when an instructor in the test data', :if => CampusOracle::Queries.test_data? do
      let(:user_id) {'238382'}
      subject { MyClasses::Merged.new(user_id).get_feed[:classes] }
      it 'contains at least one class for the instructor' do
        instructing_classes = subject.select {|entry| entry[:role] == "Instructor" }
        expect(instructing_classes.empty?).to be_false
        instructing_classes.each {|c| expect(c[:site_url].blank?).to be_false}
      end
    end
  end

  describe '#expire_cache' do
    let(:user_cache_key) {MyClasses::Merged.cache_key(user_id)}
    let(:pseudo_user_cache_key) {MyClasses::Merged.cache_key(Calcentral::PSEUDO_USER_PREFIX + user_id)}
    before {Rails.cache.write(user_cache_key, 'myclasses cached user value')}
    before {Rails.cache.write(pseudo_user_cache_key, 'myclasses cached pseudo user value')}
    it 'clears both user and pseudo-user caches' do
      MyClasses::Merged.new(user_id).expire_cache
      expect(Rails.cache.fetch(user_cache_key)).to eq nil
      expect(Rails.cache.fetch(pseudo_user_cache_key)).to eq nil
    end
  end

end
