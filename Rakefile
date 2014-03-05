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

  Importer.new(
    JSON.parse(File.read(File.join('output', 'users.json'))),
    JSON.parse(File.read(File.join('output', 'groups.json'))),
    JSON.parse(File.read(File.join('output', 'export.json'))),
    'output',
    Gitlab.client)
end

@importer = setup

task :exported_users do
  @importer.user_hash.each{|u| puts "#{u['email']} #{u['ad_guid']}"}
end

namespace :gitlab do
  task :list_users do
    p @importer.gitlab.users
  end

  task :create_users do
    @importer.create_users
  end
end
  
