# Page titles on Wikipedia may include dots, so this constraint is needed.

Rails.application.routes.draw do
  get 'errors/file_not_found'
  get 'errors/unprocessable'
  get 'errors/login_error'
  get 'errors/internal_server_error'
  get 'errors/incorrect_passcode'
  put 'errors/incorrect_passcode'

  # Sessions
  # This is for when you open a login link in a new tab, which prevents Rails JS from
  # intercepting the click and issuing a post request. Omniauth login is post-only.
  get 'users/auth/mediawiki', to: redirect('/')
  devise_for :users, controllers: { omniauth_callbacks: 'omniauth_callbacks' }

  devise_scope :user do
    # OmniAuth may fall back to :new_user_session when the OAuth flow fails.
    # So, we treat it as a login error.
    get 'sign_in', to: 'errors#login_error', as: :new_user_session

    get 'sign_out', to: 'users#signout', as: :destroy_user_session
    get 'sign_out_oauth', to: 'devise/sessions#destroy',
                          as: :true_destroy_user_session
  end

  get '/settings/all_admins' => 'settings#all_admins'
  post '/settings/upgrade_admin' => 'settings#upgrade_admin'
  post '/settings/downgrade_admin' => 'settings#downgrade_admin'

  get '/settings/special_users' => 'settings#special_users'
  post '/settings/upgrade_special_user' => 'settings#upgrade_special_user'
  post '/settings/downgrade_special_user' => 'settings#downgrade_special_user'

  post '/settings/update_salesforce_credentials' => 'settings#update_salesforce_credentials'

  get '/settings/course_creation' => 'settings#course_creation'
  post '/settings/update_course_creation' => 'settings#update_course_creation'

  get '/settings/default_campaign' => 'settings#default_campaign'
  post '/settings/add_featured_campaign' => 'settings#add_featured_campaign'
  post '/settings/remove_featured_campaign' => 'settings#remove_featured_campaign'
  post '/settings/update_default_campaign' => 'settings#update_default_campaign'

  post '/settings/update_impact_stats' => 'settings#update_impact_stats'

  get '/settings/fetch_site_notice' => 'settings#fetch_site_notice'
  post '/settings/update_site_notice' => 'settings#update_site_notice'
  

  # Griddler allows us to receive incoming emails. By default,
  # the path for incoming emails is /email_processor
  mount_griddler

  #UserProfilesController
  controller :user_profiles do
    get 'users/:username/taught_courses_articles' => 'user_profiles#taught_courses_articles', constraints: { username: /.*/ }
    get 'users/:username' => 'user_profiles#show' , constraints: { username: /.*/ }
    get 'user_stats' => 'user_profiles#stats'
    get 'stats_graphs' => 'user_profiles#stats_graphs'
    delete 'profile_image' => 'user_profiles#delete_profile_image', as: 'delete_profile_image', constraints: { username: /.*/ }
    get 'update_email_preferences/:username' => 'user_profiles#update_email_preferences', constraints: { username: /.*/ }
    post 'users/update/:username' => 'user_profiles#update' , constraints: { username: /.*/ }
  end

  #PersonalDataController
  controller :personal_data do
    get 'download_personal_data' => 'personal_data#show'
    get 'download_personal_data_csv' => 'personal_data#personal_data_csv'
  end

  # Users
  resources :users, only: [:index, :show], param: :username, constraints: { username: /.*/ }

  resources :assignments do
    patch '/status' => 'assignments#update_status'
    resources :assignment_suggestions
  end
  patch '/assignments/:id/update_sandbox_url' => 'assignments#update_sandbox_url'
  put '/assignments/:assignment_id/claim' => 'assignments#claim'
  post '/assignments/assign_reviewers_randomly' => 'assignments#assign_reviewers_randomly'

  get 'mass_enrollment/:course_id'  => 'mass_enrollment#index',
      constraints: { course_id: /.*/ }
  post 'mass_enrollment/:course_id'  => 'mass_enrollment#add_users',
      constraints: { course_id: /.*/ }

  get '/requested_accounts_campaigns/*campaign_slug/create' => 'requested_accounts_campaigns#create_accounts',
      constraints: { campaign_slug: /.*/ }
  put '/requested_accounts_campaigns/*campaign_slug/enable_account_requests' => 'requested_accounts_campaigns#enable_account_requests',
      constraints: { campaign_slug: /.*/ }
  put '/requested_accounts_campaigns/*campaign_slug/disable_account_requests' => 'requested_accounts_campaigns#disable_account_requests',
      constraints: { campaign_slug: /.*/ }
  get '/requested_accounts_campaigns/*campaign_slug' => 'requested_accounts_campaigns#index',
      constraints: { campaign_slug: /.*/ }

  put 'requested_accounts' => 'requested_accounts#request_account'
  delete 'requested_accounts/*course_slug/*id/delete' => 'requested_accounts#destroy',
      constraints: { course_slug: /.*/ }
  post 'requested_accounts/*course_slug/create' => 'requested_accounts#create_accounts',
      constraints: { course_slug: /.*/ }
  get 'requested_accounts/*course_slug/enable_account_requests' => 'requested_accounts#enable_account_requests',
      constraints: { course_slug: /.*/ }
  get 'requested_accounts/:course_slug' => 'requested_accounts#show',
      constraints: { course_slug: /.*/ }
  get '/requested_accounts' => 'requested_accounts#index'
  post '/requested_accounts' => 'requested_accounts#create_all_accounts'
  get '/update_username' => 'update_username#index'
  post '/update_username' => 'update_username#update'

  # Copy course from another server
  get 'copy_course' => 'copy_course#index'
  post 'copy_course' => 'copy_course#copy'

  # Change timeslice duration
  get 'timeslice_duration' => 'timeslice_duration#index'
  get 'timeslice_duration/update' => 'timeslice_duration#show'
  post 'timeslice_duration/update' => 'timeslice_duration#update'

  # Self-enrollment: joining a course by entering a passcode or visiting a url
  get 'courses/:course_id/enroll/(:passcode)' => 'self_enrollment#enroll_self',
      constraints: { course_id: /.*/ }

  # Courses
  controller :courses do
    get 'courses/new' => 'courses#new',
        constraints: { id: /.*/ } # repeat of resources

    get 'courses/*id/manual_update' => 'courses#manual_update',
        :as => :manual_update, constraints: { id: /.*/ }
    get 'courses/*id/notify_untrained' => 'courses#notify_untrained',
        :as => :notify_untrained, constraints: { id: /.*/ }
    get 'courses/*id/needs_update' =>  'courses#needs_update',
        :as => :needs_update, constraints: { id: /.*/ }
    get 'courses/*id/ores_plot' =>  'ores_plot#course_plot',
        constraints: { id: /.*/ }
    get 'courses/*id/refresh_ores_data' =>  'ores_plot#refresh_ores_data',
        :as => :refresh_ores_data, constraints: { id: /.*/ }
    get 'courses/*id/check' => 'courses#check',
        :as => :check, constraints: { id: /.*/ }
    get 'courses/search.json' => 'courses#search'
    match 'courses/*id/campaign' => 'courses#list',
          constraints: { id: /.*/ }, via: [:post, :delete]
    match 'courses/*id/tag' => 'courses#tag',
          constraints: { id: /.*/ }, via: [:post, :delete]
    match 'courses/*id/user' => 'users/enrollment#index',
          constraints: { id: /.*/ }, via: [:post, :delete]

    # show-type actions: first all the specific json endpoints,
    # then the catchall show endpoint
    get 'courses/:slug/course.json' => 'courses#course',
        constraints: { slug: /.*/ }
    get 'courses/:slug/articles.json' => 'courses#articles',
        constraints: { slug: /.*/ }
    get 'courses/:slug/users.json' => 'courses#users',
        constraints: { slug: /.*/ }
    get 'courses/:slug/assignments.json' => 'courses#assignments',
        constraints: { slug: /.*/ }
    get 'courses/:slug/campaigns.json' => 'courses#campaigns',
        constraints: { slug: /.*/ }
    get 'courses/:slug/categories.json' => 'courses#categories',
        constraints: { slug: /.*/ }
    get 'courses/:slug/tags.json' => 'courses#tags',
        constraints: { slug: /.*/ }
    get 'courses/:slug/timeline.json' => 'courses#timeline',
        constraints: { slug: /.*/ }
    get 'courses/:slug/uploads.json' => 'courses#uploads',
        constraints: { slug: /.*/ }
    get 'courses/:slug/alerts.json' => 'courses#alerts',
        constraints: { slug: /.*/ }
    get 'courses/:school/:titleterm(/:_subpage(/:_subsubpage(/:_subsubsubpage)))' => 'courses#show',
        :as => 'show',
        constraints: {
          school: /[^\/]*/,
          titleterm: /[^\/]*/,
          _subsubsubpage: /.*/
        }

    get '/courses/classroom_program_students.json',
        to: 'courses#classroom_program_students_json',
        as: :classroom_program_students
    get '/courses/classroom_program_students_and_instructors.json',
        to: 'courses#classroom_program_students_and_instructors_json',
        as: :classroom_program_students_and_instructors
    get '/courses/fellows_cohort_students.json',
        to: 'courses#fellows_cohort_students_json',
        as: :fellows_cohort_students
    get '/courses/fellows_cohort_students_and_instructors.json',
        to: 'courses#fellows_cohort_students_and_instructors_json',
        as: :fellows_cohort_students_and_instructors

    post '/courses/:slug/students/add_to_watchlist', to: 'courses/watchlist#add_to_watchlist', as: 'add_to_watchlist',
        constraints: { slug: /.*/ }
    delete 'courses/:slug/delete_from_campaign' => 'courses/delete_from_campaign#delete_course_from_campaign', as: 'delete_from_campaign', 
      constraints: { 
        slug: /.*/ 
      }
    get 'embed/course_stats/:school/:titleterm(/:_subpage(/:_subsubpage))' => 'embed#course_stats',
    constraints: {
        school: /[^\/]*/,
        titleterm: /[^\/]*/
    }

    post 'clone_course/:id' => 'course_clone#clone', as: 'course_clone'
    post 'courses/:id/update_syllabus' => 'courses/syllabuses#update'
    delete 'courses/:id/delete_all_weeks' => 'courses#delete_all_weeks',
      constraints: {
        id: /.*/
      }
    get 'find_course/:course_id' => 'courses#find'
  end

  # Course Notes
  resources :admin_course_notes, constraints: { id: /\d+/ } do
    get 'find_course_note', on: :member
  end

  # Categories
  post 'categories' => 'categories#add_categories'
  delete 'categories' => 'categories#remove_category'
  get 'categories/:id' => 'categories#category'

  get 'lookups/campaign(.:format)' => 'lookups#campaign'
  get 'lookups/tag(.:format)' => 'lookups#tag'

  # Timeline
  resources :courses, constraints: { id: /.*/ } do
    resources :weeks, only: [:index, :new, :create], constraints: { id: /.*/ }
    # get 'courses' => 'courses#index'
  end
  resources :weeks, only: [:index, :show, :edit, :update, :destroy]
  resources :blocks, only: [:show, :edit, :update, :destroy]
  post 'courses/:course_id/timeline' => 'timeline#update_timeline',
       constraints: { course_id: /.*/ }
  post 'courses/:course_id/enable_timeline' => 'timeline#enable_timeline',
       constraints: { course_id: /.*/ }
  post 'courses/:course_id/disable_timeline' => 'timeline#disable_timeline',
       constraints: { course_id: /.*/ }

  get 'articles/article_data' => 'articles#article_data'
  get 'articles/details' => 'articles#details'
  post 'articles/status' => 'articles#update_tracked_status'

  resources :courses_users, only: [:index]
  resources :alerts, only: [:create] do
    member do
      get 'resolve'
      put 'resolve'
    end
    collection do
      post 'notify_instructors'
    end
  end

  put 'greeting' => 'greeting#greet_course_students'

  # Article Finder
  get 'article_finder' => 'article_finder#index'

  # Reports and analytics
  get 'analytics(/*any)' => 'analytics#index'
  post 'analytics(/*any)' => 'analytics#results'
  get 'usage' => 'analytics#usage'
  get 'ungreeted' => 'analytics#ungreeted'
  get 'tagged_courses_csv/:tag' => 'analytics#tagged_courses_csv'
  get 'all_courses_csv' => 'analytics#all_courses_csv'
  get 'all_courses' => 'analytics#all_courses'
  get 'all_campaigns' => 'analytics#all_campaigns'

  # Reports generated in background
  # Course reports
  get 'course_csv' => 'reports#course_csv'
  get 'course_uploads_csv' => 'reports#course_uploads_csv'
  get 'course_students_csv' => 'reports#course_students_csv'
  get 'course_articles_csv' => 'reports#course_articles_csv'
  get 'course_wikidata_csv' => 'reports#course_wikidata_csv'
  # Campaign reports
  get 'campaigns/:slug/students' => 'reports#campaign_students_csv'
  get 'campaigns/:slug/instructors' => 'reports#campaign_instructors_csv'
  get 'campaigns/:slug/courses' => 'reports#campaign_courses_csv'
  get 'campaigns/:slug/articles_csv' => 'reports#campaign_articles_csv'
  get 'campaigns/:slug/wikidata' => 'reports#campaign_wikidata_csv'

  # Campaigns
  get 'campaigns/current/alerts' => 'campaigns#current_alerts', defaults: { format: 'html' }
  resources :campaigns, param: :slug, except: :show do
    member do
      get 'overview'
      get 'programs'
      get 'articles'
      get 'users'
      get 'assignments'
      get 'ores_plot'
      get 'alerts'
      put 'add_organizer'
      put 'remove_organizer'
      put 'remove_course'
      get 'active_courses'
    end
  end

  get 'campaigns/statistics.json' => 'campaigns#statistics'
  get 'campaigns/featured_campaigns' => 'campaigns#featured_campaigns'
  get 'campaigns/:slug.json',
      controller: :campaigns,
      action: :show
  get 'campaigns/:slug', to: redirect('campaigns/%{slug}/programs')
  get 'campaigns/:slug/programs/:courses_query',
      controller: :campaigns,
      action: :programs,
      to: 'campaigns/%{slug}/programs?courses_query=%{courses_query}'
  get 'campaigns/:slug/ores_data.json' =>  'ores_plot#campaign_plot'
  get 'current_term(/:subpage)' => 'campaigns#current_term'

  # Courses by tag
  resources :tagged_courses, param: :tag, except: :show do
    member do
      get 'programs'
      get 'articles'
      get 'alerts'
    end
  end

  # Custom JSON route for tagged courses stats
  get 'tagged_courses/:tag.json',
    controller: :tagged_courses,
    action: :stats 

  # Recent Activity
  get 'recent-activity(/*any)' => 'recent_activity#index', as: :recent_activity

  get 'revision_analytics/recent_uploads',
      controller: 'revision_analytics',
      action: 'recent_uploads'

  # Revision Feedback
  get '/revision_feedback' => 'revision_feedback#index'

  # Wizard
  get 'wizards' => 'wizard#wizard_index'
  get 'wizards/:wizard_id' => 'wizard#wizard'
  post 'courses/:course_id/wizard/:wizard_id' => 'wizard#submit_wizard',
       constraints: { course_id: /.*/ }

  # Training
  get 'training' => 'training#index'
  get 'training/:library_id' => 'training#show', as: :training_library
  get 'training/:library_id/:module_id' => 'training#training_module', as: :training_module
  get 'training_modules_users' => 'training_modules_users#index'
  post 'training_modules_users' => 'training_modules_users#create_or_update'
  post 'training_modules_users/exercise' => 'training_modules_users#mark_exercise_complete'
  get 'reload_trainings' => 'training#reload'

  get 'training_status' => 'training_status#show'
  get 'user_training_status' => 'training_status#user'

  # for React
  get 'training/:library_id/:module_id(/*any)' => 'training#slide_view'

  # API for slides for a module
  get 'training_modules' => 'training_modules#index'
  get 'training_module' => 'training_modules#show'

  # To find training modules by id
  get 'find_training_module/:module_id' => 'training_modules#find'

  # To find individual slides by id
  get 'find_training_slide/:slide_id' => 'training#find_slide'

  # Misc
  # get 'courses' => 'courses#index'
  get 'explore' => 'explore#index'
  get 'explore/search' => 'explore#search'
  get 'unsubmitted_courses' => 'unsubmitted_courses#index'
  get 'active_courses' => 'active_courses#index'
  get '/courses_by_wiki/:language.:project(.org)' => 'courses_by_wiki#show'

    # LTI
  get 'lti' => 'lti_launch#launch'

  # frequenty asked questions
  resources :faq do
    member do
      get 'handle_special_faq_query'  # Defines a route for a specific FAQ instance
    end
  end
  get '/faq/test' => 'faq#test'
  get '/faq_topics' => 'faq_topics#index'
  get '/faq_topics/new' => 'faq_topics#new'
  post '/faq_topics' => 'faq_topics#create'
  get '/faq_topics/:slug/edit' => 'faq_topics#edit'
  post '/faq_topics/:slug' => 'faq_topics#update'
  delete '/faq_topics/:slug' => 'faq_topics#delete'

  # Authenticated users root to the courses dashboard
  authenticated :user do
    root to: "dashboard#index", as: :courses_dashboard
  end

  get 'dashboard' => 'dashboard#index'
  get 'my_account' => 'dashboard#my_account'

  # Unauthenticated users root to the home page
  root to: 'home#index'

  # Surveys
  mount Rapidfire::Engine => "/surveys/rapidfire", :as => 'rapidfire'
  get '/surveys/results' => 'surveys#results_index', as: 'results'
  resources :survey_assignments, path: 'surveys/assignments'
  post '/survey_assignments/:id/send_test_email' => 'survey_assignments#send_test_email', as: 'send_test_email'
  put '/surveys/question_position' => 'questions#update_position'
  get '/survey/results/:id' => 'survey_results#results', as: 'survey_results'
  get '/survey/question/results/:id' => 'questions#results', as: 'question_results'
  get '/surveys/question_group_question/:id' => 'questions#question'
  get '/surveys/:id/question_group' => 'surveys#edit_question_groups', :as => "edit_question_groups"
  post '/surveys/question_group/clone/:id' => 'surveys#clone_question_group'
  post '/surveys/question/clone/:id' => 'surveys#clone_question'
  post '/surveys/update_question_group_position' => 'surveys#update_question_group_position'
  resources :surveys
  get '/surveys/:id/optout' => 'surveys#optout', as: 'optout'
  get '/surveys/select_course/:id' => 'surveys#course_select'
  put '/survey_notification' => 'survey_notifications#update'
  post '/survey_notification/create' => 'survey_assignments#create_notifications', as: 'create_notifications'
  post '/survey_notification/send' => 'survey_assignments#send_notifications', as: 'send_notifications'
  get '/survey/responses' => 'survey_responses#index'
  delete '/survey/responses/:id/delete' => 'survey_responses#delete'

  # Onboarding
  get 'onboarding(/*any)' => 'onboarding#index', as: :onboarding
  put 'onboarding/onboard' => 'onboarding#onboard', as: :onboard
  put 'onboarding/supplementary' => 'onboarding#supplementary', as: :supplementary

  # Update Locale Preference
  post '/update_locale/:locale' => 'users/locale#update_locale', as: :update_locale
  get '/update_locale/:locale' => 'users/locale#update_locale'

  # Route aliases for React frontend
  get '/course_creator(/*any)' => 'dashboard#index', as: :course_creator

  get '/feedback' => 'feedback_form_responses#new', as: :feedback
  get '/feedback_form_responses' => 'feedback_form_responses#index'
  get '/feedback_form_responses/:id' => 'feedback_form_responses#show', as: :feedback_form_response
  post '/feedback_form_responses' => 'feedback_form_responses#create'
  get '/feedback/confirmation' => 'feedback_form_responses#confirmation'

  # Salesforce
  if Features.wiki_ed?
    put '/salesforce/link/:course_id' => 'salesforce#link'
    put '/salesforce/update/:course_id' => 'salesforce#update'
    get '/salesforce/create_media' => 'salesforce#create_media'
  end

  # Wikimedia Event Center
  post '/wikimedia_event_center/confirm_event_sync' => 'wikimedia_event_center#confirm_event_sync'
  post '/wikimedia_event_center/update_event_participants' => 'wikimedia_event_center#update_event_participants'
  post '/wikimedia_event_center/unsync_event' => 'wikimedia_event_center#unsync_event'

  # Experiments
  namespace :experiments do
    get 'fall2017_cmu_experiment/:course_id/:email_code/opt_in' => 'fall2017_cmu_experiment#opt_in'
    get 'fall2017_cmu_experiment/:course_id/:email_code/opt_out' => 'fall2017_cmu_experiment#opt_out'
    get 'fall2017_cmu_experiment/course_list' => 'fall2017_cmu_experiment#course_list'
    get 'spring2018_cmu_experiment/:course_id/:email_code/opt_in' => 'spring2018_cmu_experiment#opt_in'
    get 'spring2018_cmu_experiment/:course_id/:email_code/opt_out' => 'spring2018_cmu_experiment#opt_out'
    get 'spring2018_cmu_experiment/course_list' => 'spring2018_cmu_experiment#course_list'
  end

  resources :admin
  resources :alerts_list

  namespace :mass_email do
    get 'term_recap' => 'term_recap#index'
    post 'term_recap/send' => 'term_recap#send_recap_emails'
  end

  get '/redirect/sandbox/:sandbox' => 'redirects#sandbox'

  resources :settings, only: [:index]

  authenticate :user, lambda { |u| u.admin? } do
    post '/tickets/reply' => 'tickets#reply', format: false
    post '/tickets/notify_owner' => 'tickets#notify_owner', format: false
    get '/tickets/search' => 'tickets#search', format: false
    get '/tickets/*dashboard' => 'tickets#dashboard', format: false
    mount TicketDispenser::Engine, at: "/td"
  end

  require 'sidekiq_unique_jobs/web'
  require 'sidekiq/cron/web'
  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  get '/private_information' => 'about_this_site#private_information'
  get '/styleguide' => 'styleguide#index'

  get '/status' => 'system_status#index'

  # Errors
  match '/404', to: 'errors#file_not_found', via: :all
  match '/422', to: 'errors#unprocessable', via: :all
  match '/599', to: 'errors#login_error', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all

end
