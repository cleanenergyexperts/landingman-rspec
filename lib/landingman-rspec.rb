require 'rspec'
require 'nokogiri'
require 'capybara-webkit'
require 'capybara/rspec'
require 'middleman-core'
require 'middleman/rack'
require 'middleman-core/rack'
require 'uri'

module LandingmanHelpers
  ###
  # Common Test Constants
  ###
  FORM_XPATH = "//form[contains(@action, '/track/lead')]"
  UUID_REGEX = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
  TEST_DATA = {
    zip: '90266',
    phone: '8886306690',
    first_name: 'TEST',
    last_name: 'TESTER',
    email: 'SyntheticsTest@SynthTest.com',
    electric_bill: '$401-500',
    property_ownership: 'OWN',
    electric_utility: 'Los Angeles Dept Water & Power (LADWP)',
    roof_shade: 'No Shade',
    street: '1601 N. SEPULVEDA BLVD, #227',
    city: 'MANHATTAN BEACH',
    state: 'CA'
  }

  ###
  # Helper Functions
  ###

  def uuid_regex
    UUID_REGEX
  end

  def self.landing_page?(resource)
    return false unless resource.ext == '.html'   # skip non-html files
    url = resource.url
    return false if url.start_with?('/showcase/') # skip the showcase of landing pages
    doc = Nokogiri::HTML(resource.render)
    forms = doc.xpath(FORM_XPATH)
    return false if forms.nil? || forms.empty?    # skip pages without Zeus forms
    true
  end

  def form_is_invalid?(form)
    keys = TEST_DATA.keys.map(&:to_s)
    inputs = form.find_all('input')
    inputs.each do |input|
    return true if keys.include?(input['name']) && 
      (input.value.nil? || input.value == '')
    end
    # selects = form.find_all('select')
    # selects.each do |select|
    #   return true if keys.include?(select['name']) && 
    #     (select.value.nil? || select.value == '')
    # end
    return false
  end

  def fill_out_input(container, input, value)
    case input['type']
    when 'radio'
      container.choose(input['id'] || input['name']) if input.value == value
    when 'checkbox'
      container.check(input['id'] || input['name']) if input.value == value
    else
      input.set(value)
    end
  end

  def try_select(options, value)
    return nil if options.empty?
    option = options.find {|o| o.value == value } || options.last
    option.select_option
  end

  def fill_out_form(form)
    # Fill out inputs
    inputs = form.find_all('input')
    inputs.each do |input|
      case input['name']
      when 'zip'
        input.set(TEST_DATA[:zip])
      when 'zip1'
        input.set(TEST_DATA[:zip])
      when 'phone'
        input.set(TEST_DATA[:phone])
      when 'phone_home'
        input.set(TEST_DATA[:phone])
      when 'first_name'
        input.set(TEST_DATA[:first_name])
      when 'last_name'
        input.set(TEST_DATA[:last_name])
      when 'email'
        input.set(TEST_DATA[:email])
      when 'property_ownership'
        fill_out_input(form, input, TEST_DATA[:property_ownership])
      when 'street'
        input.set(TEST_DATA[:street])
      when 'address'
        input.set(TEST_DATA[:street])
      when 'city'
        input.set(TEST_DATA[:city])
      when 'state'
        input.set(TEST_DATA[:state])
      else
        # unknown input
      end
    end
    selects = form.find_all('select')
    selects.each do |select|
      key = select['name'] || select['id']
      options = select.all('option')
      case key
      when 'electric_bill'
        try_select(options, TEST_DATA[:electric_bill])
      when 'electric_utility'
        try_select(options, TEST_DATA[:electric_utility])
      when 'electric_utility-CA'
        try_select(options, TEST_DATA[:electric_utility])
      when 'roof_shade'
        try_select(options, TEST_DATA[:roof_shade])
      when 'state'
        try_select(options, TEST_DATA[:state])
      else
        # unknown select input
        options.last.select_option unless options.empty?
      end
    end
  end

  def find_form(page)
    begin
    return page.find(:xpath, FORM_XPATH)
    rescue Capybara::ElementNotFound => e
    # NOTE: this can occur becuase we have a hidden form for Zeus and only display 
    # a form for SFDC, this is in my opinion a bug, and should be removed.
    end
  end

  def find_buttons(form)
    buttons = []
    form.find_all('input[type=submit]').each {|btn| buttons << btn }
    form.find_all('input[type=button]').each {|btn| buttons << btn }
    form.find_all('button').each {|btn| buttons << btn }
    form.find_all('a.btn').each {|btn| buttons << btn }
    form.find_all('a.continue').each {|btn| buttons << btn }
    # TODO: If buttons.size > 1 then we have too many choices...so how do we pick one?
    # TODO: Do we get all of the buttons using this strategy?
    return buttons
  end

  def query_param(url, key)
    uri = URI.parse(url)
    query = Rack::Utils.parse_nested_query(uri.query)
    query[key]
  end

  def pageid_type(page)
    return page.evaluate_script('typeof window.pageid')
  end

end

###
# Shared Examples
###
RSpec.shared_examples 'a landing page' do |url|
  include LandingmanHelpers
  it 'should have a working lead capture form with PageID' do
    visit(url)

    # CHECK: PageId is present
    expect(pageid_type(page)).to eq('object')

    # CHECK: Lead capture form is working correctly
    landing_path = current_path
    form = find_form(page)
    next if form.nil?
    5.times do
      # Jump out if the URL changes, since this means we were redirect
      break if current_path != landing_path

      # Find the buttons
      buttons = find_buttons(form)
      if buttons.size > 0 then
        button = buttons.first

        # Test the error handling when the form is in an invalid state
        if form_is_invalid?(form) then
          prompt = accept_alert do
            button.click
          end
          expect(prompt).to match(/Please correct the following errors/)
        end

        # Fill out form and submit correctly
        fill_out_form(form)
        button.click

        form = find_form(page)
        break if form.nil?
      else
        # In general we shouldn't get to this state ever, but if we do
        # there is no place to go, so let's just out of the loop
        break
      end
    end # if we have multiple screens then keep looping

    # This means its got to be a Thank-You Page
    # So verify that we were redirected with the CSTransitv2 `lid` parameter
    expect(query_param(current_url, 'lid')).to match(uuid_regex)
  end
end