require 'bundler'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

task default: :spec

desc 'Run specs'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
end

RuboCop::RakeTask.new do |task|
  task.options << '--display-cop-names'
end

desc 'Runs rubocop and rspec'
task :test do
  Rake::Task[:rubocop].invoke
  Rake::Task[:spec].invoke
end
