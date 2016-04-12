source "https://rubygems.org"

gem "unicorn", "5.1.0"

# We have been experiencing `ActiveSupport::Deprecation::MethodWrapper` errors
# when deploying versions of this app with activesupport 4.0.13. Pin to this
# version for now until we've upgraded other apps and fixed the issue.
gem "activesupport", "3.2.12"

gem "sinatra", "1.4.7"
gem "rake", "~> 10.5"
gem "rack", "~> 1.6"
gem "rest-client", "1.8.0"
gem "logging", "2.1.0"
gem "nokogiri", "1.6.7.2"
gem "whenever", "~> 0.9.4"
gem "slop", "3.4.5"

gem "sidekiq", "3.5.4"
gem "sidekiq-statsd", "0.1.5"
gem "redis-namespace", "~> 1.5.2"

gem "statsd-ruby", "~> 1.3.0"

gem "plek", "1.12.0"
gem "gds-api-adapters", "~> 30.0"
gem "rack-logstasher", "0.0.3"
gem "airbrake", "~> 4.3.6"
gem "unf", "0.1.4"
gem "aws-sdk", "~> 2.2.29"
gem "elasticsearch", "~> 1.0.15"

gem "govuk_message_queue_consumer", "~> 2.1.0"
gem "govuk-lint", "~> 1.0.0"

group :test do
  gem "shoulda-context", "~> 1.2.1"
  gem "simplecov", "~> 0.10.0"
  gem "simplecov-rcov", "~> 0.2.3"
  gem "turn", "~> 0.9.7" # Pretty printed test output
  gem "ci_reporter", "1.7.1"
  gem "minitest", "4.6.1"
  gem "rack-test", "~> 0.6.3"
  gem "mocha", "~> 1.1.0"
  gem "webmock", "~> 1.24"
  gem "timecop", "0.8.0"
end

group :development do
  # (Intelligent) reloading server in development
  gem "mr-sparkle", "0.3.0"
end
