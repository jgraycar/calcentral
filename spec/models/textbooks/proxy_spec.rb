require "spec_helper"

describe Textbooks::Proxy do

  # We do not use shared_examples so as to avoid hammering an external data source
  # with redundant requests.
  def it_is_a_normal_server_response
    expect(subject[:statusCode]).to be_blank
    expect(subject[:books]).to be_present
  end
  def it_has_at_least_one_title
    feed = subject[:books]
    expect(feed[:hasBooks]).to be_true
    first_book = feed[:bookDetails][0][:books][0]
    expect(first_book[:title]).to be_present
    expect(first_book[:author]).to be_present
  end

  describe '#get' do
    describe 'live testext tests enabled for order-independent expectations' do
      subject { Textbooks::Proxy.new({ccns: ccns, slug: slug}).get }

      context 'valid CCN and term slug' do
        let(:ccns) { ['26262'] }
        let(:slug) {'fall-2014'}
        it 'produces the expected textbook feed' do
          it_is_a_normal_server_response
          it_has_at_least_one_title
          book_list = subject[:books][:bookDetails][0]
          expect(book_list[:type]).to eq 'Required'
          first_book = book_list[:books][0]
          [:isbn, :image, :edition, :publisher, :amazonLink, :cheggLink, :oskicatLink, :googlebookLink].each do |key|
            expect(first_book[key]).to be_present
          end
          expect(first_book[:image]).to_not match /http:/
        end
      end

      context 'an unknown CCN' do
        let(:ccns) { ['09259'] }
        let(:slug) {'fall-2014'}
        it 'returns a helpful message' do
          it_is_a_normal_server_response
          feed = subject[:books]
          expect(feed[:hasBooks]).to be_false
          expect(feed[:bookUnavailableError]).to eq 'Textbook information for this course could not be found.'
        end
      end

      context 'an unknown term code' do
        let(:ccns) { ['26262'] }
        let(:slug) {'fall-2074'}
        it 'returns a helpful message' do
          it_is_a_normal_server_response
          feed = subject[:books]
          expect(feed[:hasBooks]).to be_false
          expect(feed[:bookUnavailableError]).to eq 'Textbook information for this term could not be found.'
        end
      end

      context 'multiple CCNs, only one of which has books' do
        let(:ccns) { ['09259', '26262'] }
        let(:slug) {'fall-2014'}
        it 'finds the one with books' do
          it_is_a_normal_server_response
          it_has_at_least_one_title
        end
      end
    end

    describe 'order-dependent tests work from recorded data' do
      subject { Textbooks::Proxy.new({ccns: ccns, slug: slug, fake: true}).get }

      context 'a required text with no ISBN' do
        let(:ccns) { ['62120'] }
        let(:slug) {'summer-2014'}
        it 'provides a bookstore link to get the non-ISBN text' do
          it_is_a_normal_server_response
          it_has_at_least_one_title
          necronomicon = subject[:books][:bookDetails][0][:books][1]
          expect(necronomicon[:publisher]).to eq 'UNIVERSITY CUSTOM PUBLISHING'
          expect(necronomicon[:isbn]).to be_nil
          expect(necronomicon[:bookstoreLink]).to be_present
        end
      end

      context 'a choice of required texts' do
        let(:ccns) { ['53798'] }
        let(:slug) {'fall-2014'}
        it 'provides a bookstore link to get the title with choices' do
          it_is_a_normal_server_response
          it_has_at_least_one_title
          choices = subject[:books][:bookDetails][0][:books][1]
          expect(choices[:hasChoices]).to be_true
          expect(choices[:title]).to be_present
          expect(choices[:bookstoreLink]).to be_present
        end
      end
    end

  end

  describe '#get_as_json' do
    include_context 'it writes to the cache'
    it 'returns proper JSON' do
      json = Textbooks::Proxy.new({ccns: ['26262'], slug: 'fall-2014'}).get_as_json
      expect(json).to be_present
      parsed = JSON.parse(json)
      expect(parsed).to be
      unless parsed['statusCode'] && parsed['statusCode'] >= 400
        expect(parsed['books']).to be
      end
    end
    context 'when the bookstore server has problems' do
      before do
        stub_request(:any, /#{Regexp.quote(Settings.textbooks_proxy.base_url)}.*/).to_raise(Errno::EHOSTUNREACH)
      end
      it 'returns a error status code and message' do
        json = Textbooks::Proxy.new({ccns: ['26262'], slug: 'fall-2014', fake: false}).get_as_json
        parsed = JSON.parse(json)
        expect(parsed['statusCode']).to be >= 400
        expect(parsed['body']).to be_present
      end
    end
  end

end
