require 'rake/testtask'

task :default => [:test]

task :test do
  Rake::TestTask.new do |t|
    t.libs << "test"
    t.options = "-v"
    t.test_files = FileList['test/tc*.rb']
    t.verbose = true
  end
end