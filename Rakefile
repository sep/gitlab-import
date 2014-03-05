require 'rubygems'
require 'bundler'

Bundler.require

Dotenv.load

task :default => [:start]

task :load_data do
  @importer = Importer.new(
    JSON.parse(File.read(File.join('output', 'users.json'))),
    JSON.parse(File.read(File.join('output', 'groups.json'))),
    JSON.parse(File.read(File.join('output', 'export.json'))),
    'output')
end

task :configure_gitlab do
  Gitlab.configure do |config|
    config.endpoint = ENV['GITLAB_URL']
    config.private_token = ENV['GITLAB_TOKEN']
    config.user_agent = 'importer'
  end
  @gitlab = Gitlab.client
end

task :exported_users => :load_data do
  @importer.user_hash.each{|u| puts u['email']}
end

namespace :gitlab do
  task :list_users => :configure_gitlab do
    p @gitlab.users
  end
end
  
class Importer

  attr_accessor :user_hash

  def initialize(user_hash, group_hash, project_hash, repo_dir)
    @user_hash = user_hash
    @group_hash = group_hash
    @project_hash = project_hash
    @repo_dir = repo_dir
  end

end
