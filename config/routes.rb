Rails.application.routes.draw do
  get 'scrapes', to: 'scraper#index'
end
