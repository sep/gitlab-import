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
      .each do |u|
        #{|u| puts "create #{u['email']}"}
        @gitlab.users.create_user(u['email'], 'password', {projects_limit: 1000})
      end
  end

  def load_ssh_keys
    @gitlab.users.each do |u|
      sudo(u.id) do
        old_user = @user_hash.find{|h| h['email'] == u.email}
        next unless old_user
        old_user['ssh_keys'].each do |k|
          puts "  #{k.split(' ').last} #{k}"
          #@gitlab.users.create_ssh_key(k.split(' ').last, k)
        end
      end
    end
  end

  def sudo(id)
    Gitlab.sudo = id
    yield
  ensure
    Gitlab.sudo = nil
  end
end

