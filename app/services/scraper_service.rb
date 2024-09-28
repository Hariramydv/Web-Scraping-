require 'selenium-webdriver'
require 'nokogiri'
require 'csv'

class ScraperService
  BASE_URL = "https://www.ycombinator.com/companies"

  def initialize(n, filters)
    @n = n
    @filters = filters
    @companies = []
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--disable-gpu')
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    @driver = Selenium::WebDriver.for :chrome, options: options
  end

  def call
    page = 1

    while @companies.size < @n
      url = apply_filters("#{BASE_URL}?page=#{page}")
      scrape_companies(url)

      break if @companies.size.zero?

      page += 1
    end

    @companies = @companies.first(@n)
    @companies.each do |company|
      scrape_company_details(company)
    end

    save_to_csv(@companies)
    @companies
  end

  private

  def apply_filters(url)
    filter_params = @filters.map { |key, value| "#{key}=#{value}" }.join('&')
    "#{url}&#{filter_params}"
  end

  def scrape_companies(url)
    @driver.navigate.to(url)
    wait_for_page_load
    wait_for_content_to_load

    doc = Nokogiri::HTML(@driver.page_source)
    count = 0
    doc.css('div._section_86jzd_146._results_86jzd_326 a').each do |company_html|
      break if count >= @n
      next unless company_html.css('span._coName_86jzd_453').text.strip.present?

      company = {
        name: company_html.css('span._coName_86jzd_453').text.strip,
        location: company_html.css('span._coLocation_86jzd_469').text.strip,
        description: company_html.css('span._coDescription_86jzd_478').text.strip,
        yc_batch: company_html.css('div._pillWrapper_86jzd_33 a span.pill').first.text.strip,
        url: company_html['href'],
        founder_names: [],
        linkedin_urls: []
      }

      @companies << company
      count += 1
    end
  end

  def wait_for_page_load(timeout = 60)
    Selenium::WebDriver::Wait.new(timeout: timeout).until do
      @driver.execute_script('return document.readyState') == 'complete'
    end
  end

  def wait_for_content_to_load(timeout = 60)
    Selenium::WebDriver::Wait.new(timeout: timeout).until do
      loading_elements = @driver.find_elements(css: 'div._status_86jzd_510')
      loading_elements.empty?
    end
  end

  def scrape_company_details(company)
    @driver.navigate.to(URI.join(BASE_URL, company[:url]).to_s)
    wait_for_page_load

    doc = Nokogiri::HTML(@driver.page_source)
    company[:website] = doc.css('div.group a').first['href'] rescue "N/A"

    founders_divs = doc.css('section.relative.isolate.z-0 div.flex.flex-row.flex-col.items-start.gap-3.md\\:flex-row, div.space-y-5 > div, div.space-y-4 > div')

    company[:founder_names] = founders_divs.map do |founder_div|
      founder_div.at_css('div.leading-snug div.font-bold')&.text&.strip
    end.compact

    company[:linkedin_urls] = founders_divs.map do |founder_div|
      founder_div.at_css('div.leading-snug a.bg-image-linkedin')&.[](:href)
    end.compact
  end

  def save_to_csv(companies)
    file_path = 'public/companies_data.csv'
    CSV.open(file_path, "w") do |csv|
      csv << ["Company Name", "Location", "Description", "Company Yc Batch", "Website URL", "Founder Names", "LinkedIn URLs"]
      companies.each do |company|
        founder_names = company[:founder_names].join(", ")
        linkedin_urls = company[:linkedin_urls].join(", ")
        csv << [
          company[:name] || "",
          company[:location] || "",
          company[:description] || "",
          company[:yc_batch] || "",
          company[:website] || "N/A",
          founder_names,
          linkedin_urls
        ]
      end
    end
  end
end
