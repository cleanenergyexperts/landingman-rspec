To use:

1. Add to your Gemfile:
    `echo "gem 'landingman-rspec', github: 'cleanenergyexperts/landingman-rspec'" >> Gemfile`
2. `bundle update`
3. Add a spec directory:
    `mkdir -p spec`
4. Create a spec_helper.rb file in the spec directory to setup your tests. It should look like:
    
    require 'landingman-rspec'
    MIDDLEMAN_APP = ::Middleman::Application.new
    # `xvfb-run -a bundle exec rspec`
    Capybara.javascript_driver = :webkit
    Capybara::Webkit.configure do |config|
      config.ignore_ssl_errors
      config.skip_image_loading
      config.allow_unknown_urls
      config.block_url(...)
    end
    Capybara.app = ::Middleman::Rack.new(MIDDLEMAN_APP).to_app do
      set :root, File.expand_path(File.join(File.dirname(__FILE__), '..'))
      set :environment, :development
      set :show_exceptions, true
    end

5. Create a features directory in the spec directory:
    `mkdir -p spec/features`
6. Create a landing_spec.rb file in the features directory to generate your tests. It should look like:
    
    require 'spec_helper'
    MIDDLEMAN_APP.sitemap.resources.each do |resource|
      next unless LandingmanHelpers::landing_page?(resource)
      describe resource.url, type: :feature, js: true do
        it_behaves_like 'a landing page', resource.url
      end
    end
