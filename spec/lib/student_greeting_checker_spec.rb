# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/lib/student_greeting_checker"

describe StudentGreetingChecker do
  before do
    create(:course, id: 1, start: 2.weeks.ago, end: Time.zone.today + 2.weeks)
    create(:user, id: 1, username: 'Danny', greeter: true)
    create(:courses_user,
           id: 1,
           course_id: 1,
           user_id: 1,
           role: CoursesUsers::Roles::WIKI_ED_STAFF_ROLE)
    create(:user, id: 2, username: 'Ragesoss')
    create(:courses_user,
           id: 2,
           course_id: 1,
           user_id: 2,
           role: CoursesUsers::Roles::STUDENT_ROLE)
  end

  it 'pulls the usernames of all greeters' do
    expect(described_class.new.instance_variable_get(:@greeter_usernames)).to eq(['Danny'])
  end

  describe '.check_all_ungreeted_students' do
    subject { described_class.check_all_ungreeted_students }

    it 'does nothing for students with blank talk pages' do
      expect_any_instance_of(WikiApi).to receive(:get_page_content).and_return('')
      subject
      expect(User.find(2).greeted).to eq(false)
    end

    it 'skips students who are already greeted' do
      User.find(2).update(greeted: true)
      # No response stubs are active, so this will fail an edit is attempted.
      subject
      expect(User.find(2).greeted).to eq(true)
    end

    it 'updates students whose talk pages have been edited by greeters' do
      # This returns the respected response for when 'Danny' has edited the talk
      # page of 'Ragesoss'.
      stub_contributors_query
      subject
      expect(User.find(2).greeted).to eq(true)
    end

    describe '.check' do
      let(:course) { Course.find(1) }
      let(:wiki) { course.home_wiki }
      let(:greeters) { [User.find(1)] }
      let(:usernames) { greeters.pluck(:username) }
      let(:checker) { StudentGreetingChecker::Check.new(User.find(2), wiki, usernames) }

      describe '#talk_page_blank?' do
        it 'returns true when a PageFetchError with status 429 is raised' do
          allow_any_instance_of(WikiApi).to receive(:get_page_content)
            .and_raise(WikiApi::PageFetchError.new('User:Ragesoss', 429))

          expect(checker.send(:talk_page_blank?)).to eq(true)
        end
      end
    end
  end
end
