# run 'bundle exec rake -T' to see a list of tasks
# run 'bundle exec rake <task name>' to run a task
# run 'bundle exec <anything>' always ;-)

require 'rubygems'
require 'rake'
require 'rake/packagetask'
require 'rubygems/package_task'
require 'rspec'
require "rspec/core/rake_task"

Dir["#{File.dirname(__FILE__)}/tasks/rake/*.rake"].each { |f| load(f) }

# Rake::PackageTask.new("puppet", Puppet::PUPPETVERSION) do |pkg|
#     pkg.package_dir = 'pkg'
#     pkg.need_tar_gz = true
#     pkg.package_files = FILES.to_a
# end

task :default => :spec

# desc "Create the tarball and the gem - use when releasing"
# task :puppetpackages => [:create_gem, :package]

RSpec::Core::RakeTask.new do |t|
    t.pattern ='spec/editfile/**/*.rb'
    t.fail_on_error = true
end


task :apply_example do
  sh %{puppet apply --modulepath=/etc/puppet/modules --debug --trace doc/example_manifest.pp}
end
