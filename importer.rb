class Importer
  attr_accessor :user_hash, :gitlab

  def initialize(user_hash, group_hash, project_hash, repo_dir, gitlab)
    @user_hash = user_hash
    @group_hash = group_hash
    @project_hash = project_hash
    @repo_dir = repo_dir
    @gitlab = gitlab
    @verbose = true
  end

  def alums
    @alums ||= %w{maburke ajpanozzo kamarcum pclivengood ctcotten ndroe emshaw jdlowe tettestuser soward djkelley smsatchwill bmbotti edsage lgmiller dkshah jaseewer}.map{|u| "#{u}@sep.com"}.inject({}){|memo, obj| memo[obj] = obj; memo}
  end

  def garble_email(email, index)
    return "jon@sep.com" if index == 0
    "test-#{email}"
  end

  def get_username(email)
    return '' unless email
    email.split('@').first
  end

  def create_users
    @user_hash
      .reject{|u| alums.has_key?(u['email'])}
      .reject{|u| u['email'] == nil}
      .reject{|u| u['email'] == 'cruisecontrol@sep.com'}
      .take(3)
      .each_with_index do |u, i|
        email = garble_email(u['email'], i)
        p u
        name = get_username(u['email'])
        puts "creating #{email} - #{name}" if @verbose
        @gitlab.create_user(email, 'password', {username: name, name: name})
      end
  end

  def load_ssh_keys
    @gitlab.users.drop(3).each do |u|
      puts "loading keys for: #{u.username}" if @verbose
      sudo(u.id) do
        gitorious_user = @user_hash.find{|h| get_username(h['email']) == u.username}
        next unless gitorious_user
        gitorious_user['ssh_keys'].uniq.each do |k|
          #key = k.split(' ')[0...-1].join(' ')
          #title = "whatever#{rand.to_s[2..8]}"
          title = k.split(' ').last
          key = k
          puts "  adding key: #{title} - #{key}" if @verbose
          @gitlab.create_ssh_key(title, key)
        end
      end
    end
  end

  def sudo(id)
    Gitlab.sudo, old_sudo = id, Gitlab.sudo
    yield
  ensure
    Gitlab.sudo = old_sudo
  end
end

