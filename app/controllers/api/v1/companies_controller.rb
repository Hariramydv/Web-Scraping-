class Api::V1::CompaniesController < ApplicationController
  before_action :validate_limit, only: [:index]
  def index
    file_path = Rails.root.join('public', 'companies_data.csv')
    base_url = 'https://www.ycombinator.com/companies'
    limit = params[:limit].to_i if params[:limit]
    filters = {
      'top_company' => params[:top_company],
      'highlight_women' => params[:highlight_women],
      'highlight_black' => params[:highlight_black],
      'batch' => parse_filter(params[:batch]),
      'industry' => parse_filter(params[:industry]),
      'tag' => parse_filter(params[:tag]),
      'regions' => parse_filter(params[:regions]),
      'team_size' => parse_team_size(params[:team_size])
    }.compact
    uri = URI(base_url)
    if filters.any?
      query_string = build_query_string(filters)
      uri.query = query_string
    end
    new_url_base = uri.to_s
    begin
      scraper = YCombinatorScraper.new(new_url_base, base_url, limit)
      scraper.scrape
    rescue RuntimeError => e
      return render json: { error: e.message }, status: :not_found
    rescue => e
      return render json: { error: e.message }, status: :unprocessable_entity
    end
    if File.exist?(file_path)
      @csv_data = CSV.read(file_path, headers: true)
    else
      @csv_data = []
    end
    render json: @csv_data
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

  def build_query_string(filters)
    filters.flat_map { |k, v|
      Array(v).map { |value| "#{CGI.escape(k)}=#{CGI.escape(value)}" }
    }.join('&').gsub('+', '%20')
  end

  def validate_limit
    limit = params[:limit]
    if limit.nil?
      render json: { error: 'Limit parameter is required' }, status: :bad_request
    elsif limit.to_i <= 0
      render json: { error: 'Limit parameter must be a positive integer' }, status: :bad_request
    end
  end
end
