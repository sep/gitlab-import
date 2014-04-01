require 'rubygems'
require 'bundler'

Bundler.require
Dotenv.load

require './importer'

def setup
  Gitlab.configure do |config|
    config.endpoint = ENV['GITLAB_URL']
    config.private_token = ENV['GITLAB_TOKEN']
    config.user_agent = 'importer'
  end

  test_email = ENV['IMPORT_TEST_EMAIL']
  verbose = !!ENV['VERBOSE']
  data_dir = ENV['IMPORT_DATA_DIR']

  puts "Verbose mode: #{verbose}"
  puts "Test email address: #{test_email}" if verbose
  puts

  Importer.new(
    JSON.parse(File.read(File.join(ENV['IMPORT_DATA_DIR'], 'users.json'))),
    JSON.parse(File.read(File.join(ENV['IMPORT_DATA_DIR'], 'groups.json'))),
    JSON.parse(File.read(File.join(ENV['IMPORT_DATA_DIR'], 'export.json'))),
    File.join(ENV['IMPORT_DATA_DIR']),
    Gitlab,
    (ENV['IMPORT_DONT_PUSH'] || "").split(',').map{|s| s.strip},
    {verbose: verbose, test_email: test_email})
end

@importer = setup

desc 'list exported users'
task :exported_users do
  @importer.user_hash.each{|u| puts "#{u['email']} #{u['ad_guid']}"}
end

desc 'list exported projects'
task :exported_projects do
  @importer.project_hash.each{|p| puts p['title']; p['repositories'].each{|r| puts "  #{r['name']}"}}
end

namespace :gitlab do
  desc 'list gitlab users'
  task :list_users do
    p @importer.gitlab.users
  end

  desc 'create gitlab users from exported data'
  task :import_users do
    @importer.create_users
  end

  desc 'delete ssh keys from gitlab users'
  task :delete_ssh_keys do
    @importer.delete_ssh_keys
  end

  desc 'load ssh keys from exported data'
  task :load_ssh_keys do
    @importer.load_ssh_keys
  end

  desc 'create projects from exported data'
  task :import_projects do
    @importer.create_projects
  end

  desc 'remove users from gitlab'
  task :remove_users do
    @importer.get_users
      .reject{|u| u.email == "admin@local.host"}
      .each do |u|
        puts "deleting #{u.email} (#{u.id})"
        `curl --header "PRIVATE-TOKEN: #{ENV['GITLAB_TOKEN']}" -X DELETE #{ENV['GITLAB_URL']}/users/#{u.id}`
        puts
      end
  end

  desc 'remove groups from gitlab'
  task :remove_groups do
    @importer.get_groups
      .each do |g|
        puts "deleting #{g.name} (#{g.id})"
        `curl --header "PRIVATE-TOKEN: #{ENV['GITLAB_TOKEN']}" -X DELETE #{ENV['GITLAB_URL']}/groups/#{g.id}`
        puts
      end
  end

  desc 'remove user projects from gitlab'
  task :remove_user_projects do
    @importer.get_users.each do |u|
      @importer.get_user_projects(u).each do |p|
        puts "deleting project #{p.name} (#{p.id})"
        `curl --header "PRIVATE-TOKEN: #{ENV['GITLAB_TOKEN']}" -X DELETE #{ENV['GITLAB_URL']}/projects/#{p.id}`
      end
    end
  end
end
  
desc 'an irb console with export data and the gitlab api available.'
task :console do
  require 'irb'
  ARGV.clear
  puts "The importer is available here: @importer"
  puts "The gitlab instance is available here: @importer.gitlab"
  IRB.start
end
