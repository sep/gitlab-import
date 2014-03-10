class Importer
  attr_accessor :user_hash, :group_hash, :project_hash, :gitlab

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
      .take(3)  # REMOVE THIS AFTER TESTING
      .each_with_index do |u, i|
        email = garble_email(u['email'], i)
        p u
        name = get_username(u['email'])
        puts "creating #{email} - #{name}" if @verbose
        @gitlab.create_user(email, 'password', {username: name, name: name})
      end
  end

  def load_ssh_keys
    @gitlab
      .users
      .drop(3)
      .each do |u|
        puts "loading keys for: #{u.username}" if @verbose
        sudo(u.id) do
          gitorious_user = @user_hash.find{|h| get_username(h['email']) == u.username}
          next unless gitorious_user
          gitorious_user['ssh_keys'].uniq.each do |k|
            title = k.split(' ').last
            key = k
            puts "  adding key: #{title} - #{key}" if @verbose
            @gitlab.create_ssh_key(title, key)
          end
        end
      end
  end

  def create_groups
    #group = create_group(name, path)
    #add_group_member(group.id, user.id, 50 or "Master")
    
  end

  def create_projects
    fallback_user = {username: 'jcfuller', id: 2}
    gitlab_users = @gitlab.users.inject({}){|memo, obj| memo[obj.username] = obj.id; memo}

    @project_hash.each do |project|
      puts "creating project #{project['title']}" if @verbose

      existing_users = project['repositories']
        .map{|r| r['committers']}
        .flatten
        .uniq
        .reject{|p| not_there = !(gitlab_users.has_key?(p)); puts "  ignoring committer #{p}, not in gitlab." if not_there && @verbose; not_there}
        .map{|u| {username: u, id: gitlab_users[u]}}

      first_user = existing_users.first || fallback_user
      other_users = existing_users.drop(1)

      new_project = @gitlab.create_project(project['title'], {description: project['description'], wiki_enabled: true, wall_enabled: true, issues_enabled: true, snippets_enabled: true, merge_requests_enabled: true, public: true, user_id: first_user[:id]})
      other_users.each do |u|
        puts "  adding committer #{u[:username]}"
        @gitlab.add_team_member(new_project.id, u[:id], 50)
      end
    end
    # create projects owned by users
      # add users to project

    # create projects owned by groups
      # transfer
      # add users to project
  end

  def sudo(id)
    Gitlab.sudo, old_sudo = id, Gitlab.sudo
    yield
  ensure
    Gitlab.sudo = old_sudo
  end
end

