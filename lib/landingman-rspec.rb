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
    first_name: 'SYNTHETICS',
    last_name: 'TESTER',
    email: 'SyntheticsTest@SynthTest.com',
    electric_bill: '$301-400',
    property_ownership: 'OWN',
    property_ownership_select: 'single',
    home_type: 'single',
    electric_utility: 'Los Angeles Dept Water & Power (LADWP)',
    roof_shade: 'No Shade',
    street: '1601 N. SEPULVEDA BLVD, #227',
    city: 'MANHATTAN BEACH',
    state: 'CA'
  }

  ###
  # Javascript to override setTimeout so it returns immediately so our tests
  # don't have to wait for any potential animation on the page to run.
  # @see http://stackoverflow.com/a/17676303
  ###
  WINDOW_TIMEOUT_JS_OVERRIDE = <<EOT
window.oldSetTimeout = window.setTimeout;
window.setTimeout = function(func, delay) {
  return window.oldSetTimeout(function() {
    try {
      func();
    } catch (exception) {
      // Swallow the JS error
    }
  }, 0);
};
EOT

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

  def fill_out_input(container, input, value, retries = 3)
    case input['type']
    when 'radio'
      container.choose(input['id'] || input['name']) if input.value == value
    when 'checkbox'
      container.check(input['id'] || input['name']) if input.value == value
    else
      input.set(value)
    end
  rescue Capybara::Webkit::ClickFailed => e
    # Hide the overlapping element and then do a regular click
    if retries > 0 && m = e.message.match(/overlapping element (.*) at position/) then
      overlapping_xpath = m.captures.first.strip
      overlapping_script = <<EOT
var elem = document.evaluate("#{overlapping_xpath}", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
if (elem)
  elem.parentNode.removeChild(elem);
EOT
      page.execute_script(overlapping_script)
      fill_out_input(container, input, value, retries - 1)
    else
      raise e
    end
  end

  def try_select(options, value1, value2 = nil)
    return nil if options.empty?
    option   = options.find {|o| o.value == value1 }
    option ||= options.find {|o| o.value == value2 } unless value2.nil?
    option ||= options.last
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
      when 'ownHouse' # Deprecated parameter for backwards compatibility only
        fill_out_input(form, input, 'YES')
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
      when 'property_ownership'
        try_select(options, TEST_DATA[:property_ownership_select], TEST_DATA[:property_ownership])
      when 'home_type'
        try_select(options, TEST_DATA[:home_type])
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

  def host(url)
    uri = URI.parse(url)
    uri.host
  end

  def pageid_type(page)
    return page.evaluate_script('typeof window.pageid')
  end

  def click_button(page, button)
    button.click
  rescue Capybara::Webkit::ClickFailed => e
    # Hide the overlapping element and then do a regular click
    if m = e.message.match(/overlapping element (.*) at position/) then
      overlapping_xpath = m.captures.first.strip
      overlapping_script = <<EOT
var elem = document.evaluate("#{overlapping_xpath}", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
if (elem)
  elem.parentNode.removeChild(elem);
EOT
      page.execute_script(overlapping_script)
      click_button(page, button)
    else
      raise e
    end
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

    #should not have certain warnings (font load, etc)
    messages = page.driver.console_messages.select
    failure_messages = []

    #if a console message contains one of the following substrings, then fail!
    warning_text_to_fail = ["pixel","font"]

    messages.each do |msg|
      unless msg[:message].nil?
        message_text = msg[:message].to_s.downcase 
        should_fail = warning_text_to_fail.any? {|fail_text| message_text.include? fail_text}
          if should_fail
            failure_messages.push(msg)
          end
       end
    end

    #if any console messages contain our "fail text", then fail the build and print the info
    expect(failure_messages).to be_empty, "expected no critical warnings, got #{failure_messages.inspect}"

    # Should not have any JavaScript errors in the console (only look at errors from the same host for now)
    current_host = host(current_url)
    errors = page.driver.error_messages.select {|err| host(err[:source]) == current_host }
    expect(errors).to be_empty, "expected no JavaScript errors, got #{errors.inspect}"

    # Should have element "pageid-tcpa" on the page
    expect(page).to have_css(".pageid-tcpa", minimum: 1, :visible => false), "Missing element with '.pageid-tcpa' class"

    # Inject a custom setTimeout onto the page that only waits 10 ms (we don't want to wait while testing)
    page.execute_script(LandingmanHelpers::WINDOW_TIMEOUT_JS_OVERRIDE)

    # CHECK: Lead capture form is working correctly
    landing_path = current_path.to_s
    form = find_form(page)
    next if form.nil?
    8.times do
      # Jump out if the URL changes, since this means we were redirect
      break if current_path != landing_path

      # Find the buttons
      buttons = find_buttons(form)
      if buttons.size > 0 then
        button = buttons.first

        # Test the error handling when the form is in an invalid state
        if form_is_invalid?(form) then
          prompt = accept_alert do
            click_button(page, button)
          end
          expect(prompt).to match(/Please correct the following errors/)
        end

        # Fill out form and submit correctly
        fill_out_form(form)
        click_button(page, button)

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
    lid = query_param(current_url, 'lid')
    expect(lid).to match(uuid_regex), "expected UUID lid query parameter on thanks page, got #{lid.inspect} on URL: #{current_url}"
  end
end