# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

desc 'Run RSpec tests'
RSpec::Core::RakeTask.new(:spec)

desc 'Run RuboCop'
RuboCop::RakeTask.new

desc 'Run all checks'
task default: %i[rubocop spec]

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].invoke
end
