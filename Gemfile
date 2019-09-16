source 'https://rubygems.org'

gem 'sqlite3'
gem 'mysql2'
gem 'pg'

group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'poltergeist'
end

group :test, :development do
  gem 'rubocop'

  platforms :mri do
    gem 'byebug'
  end
end

gemspec
