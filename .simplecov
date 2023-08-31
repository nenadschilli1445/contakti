if ENV['CI_BUILD']
  require 'simplecov-rcov'
  formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::RcovFormatter
  ]
  if ENV['CODECLIMATE_REPO_TOKEN']
    require 'codeclimate-test-reporter'
    formatters << ::CodeClimate::TestReporter::Formatter
  end
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[*formatters]
end
SimpleCov.start 'rails' do
  add_group "Workers", "app/workers"
  add_group "Services", "app/services"
  add_group "Decorators", "app/decorators"
  add_group "Serializers", "app/serializers"
end
