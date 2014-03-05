require 'rubygems'
require 'bundler'

Bundler.require

Dotenv.load

task :default => [:start]

class Importer

  attr_accessor :user_hash, :gitlab

  def initialize(user_hash, group_hash, project_hash, repo_dir, gitlab)
    @user_hash = user_hash
    @group_hash = group_hash
    @project_hash = project_hash
    @repo_dir = repo_dir
    @gitlab = gitlab
  end

  def alums
    @alums ||= %w{maburke ajpanozzo kamarcum pclivengood ctcotten ndroe emshaw jdlowe tettestuser soward djkelley smsatchwill bmbotti edsage lgmiller dkshah jaseewer}.map{|u| "#{u}@sep.com"}.inject({}){|memo, obj| memo[obj]; memo}
  end

  def create_users
    @user_hash
      .reject{|u| alums.has_key?(u['email'])}
      .reject{|u| u['email'] == nil}
      .reject{|u| u['email'] == 'cruisecontrol@sep.com'}
      .each{|u| puts "create #{u['email']}"}
  end
end

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
  
