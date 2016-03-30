source 'https://rubygems.org'

branch = ENV.fetch('SOLIDUS_BRANCH', 'master')
gem "solidus", github: "solidusio/solidus", branch: branch

gem 'sqlite3'
gem 'mysql2'
gem 'pg'

group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'poltergeist'
end

gem 'rubocop'

gemspec
