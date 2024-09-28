class ScraperController < ApplicationController
  before_action :validate_limit

  def index

    filters = {
      'highlight_latinx' => params[:highlight_latinx] || params[:hispanic_latino_founded],
      'top_company' => params[:top_company],
      'highlight_women' =>  params[:women_founded] || params[:highlight_women],
      'isHiring' => params[:isHiring] || params[:is_hiring],
      'highlight_black' => params[:black_founded] || params[:highlight_black],
      'batch' => params[:batch],
      'industry' => parse_filter(params[:industry]),
      'tag' => parse_filter(params[:tag]),
      'regions' => params[:regions] || params[:region],
      'nonprofit' => params[:nonprofit],
      'team_size' => parse_team_size(params[:team_size]) || parse_team_size(params[:company_size])
    }.compact

    companies = ScraperService.new(params[:n].to_i, filters).call

    if params[:format] == 'csv'
      send_data to_csv(companies), filename: "yc_companies.csv", type: 'text/csv'
    else
      render json: companies.uniq
    end
  end

  private

  def parse_filter(filter_param)
    filter_param&.split(',')&.map(&:strip)
  end

  def parse_team_size(team_size_param)
    return unless team_size_param
    min, max = team_size_param.split('-')
    "[\"#{min}\",\"#{max}\"]"
  end

  def validate_limit
    n = params[:n]
    if n.nil?
      render json: { error: 'Parameter n is required' }, status: :bad_request
    elsif n.to_i <= 0
      render json: { error: 'Parameter n must be a positive integer' }, status: :bad_request
    end
  end

  def to_csv(companies)
    CSV.generate(headers: true) do |csv|
      csv << %w[name location description yc_batch website founder_names linkedin_urls]
      companies.each do |company|
        csv << [
          company[:name],
          company[:location],
          company[:description],
          company[:yc_batch],
          company[:website],
          company[:founder_names].join(', '),
          company[:linkedin_urls].join(', ')
        ]
      end
    end
  end
end
