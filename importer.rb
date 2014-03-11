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

  def create_projects
    fallback_user = {username: 'root', id: 1}
    gitlab_users = @gitlab.users.inject({}){|memo, obj| memo[obj.username] = obj.id; memo}

    @project_hash.each do |project|
      puts "creating group #{project['title']}" if @verbose

      existing_users = project['repositories']
        .map{|r| r['committers']}
        .flatten
        .uniq
        .reject{|p| not_there = !(gitlab_users.has_key?(p)); puts "  ignoring committer #{p}, not in gitlab." if not_there && @verbose; not_there}
        .map{|u| {username: u, id: gitlab_users[u]}}

      group = @gitlab.create_group(project['title'], project['slug'])
      (existing_users + [fallback_user]).each do |u|
        puts "  adding user to group - #{u[:username]}" if @verbose
        @gitlab.add_group_member(group.id, u[:id], 50)
      end
      project['repositories'].map do |repo|
        puts "  adding project/repo to group - #{repo['name']}" if @verbose

        new_project = @gitlab.create_project(repo['name'], {description: repo['description'], wiki_enabled: true, wall_enabled: true, issues_enabled: true, snippets_enabled: true, merge_requests_enabled: true, public: true, user_id: fallback_user[:id]})
        @gitlab.transfer_project_to_group(group.id, new_project.id)
      end

    end

    @gitlab.projects.each do |project|
      old_repo = project_hash
        .map{|p| p['repositories'].map{|r| {project: p['title'], repo: r['name'], p: p}}}
        .flatten
        .find{|p| p[:repo] == project.name && p[:project] == project.namespace.name}

      dir = File.join(@repo_dir, old_repo[:p]['slug'], old_repo[:repo])
      puts "going to push repo for project #{project.name} (#{old_repo[:project]} = #{old_repo[:repo]})" if @verbose
      puts "local repo: #{dir} - exists: #{Dir.exist?(dir)}" if @verbose
      puts "remote repo: #{project.ssh_url_to_repo}"
      Dir.chdir(dir) do
        url = project.ssh_url_to_repo.gsub('gitlab-vm', '172.16.6.111') # REMOVE THIS!
        puts "pushing to #{url}" if @verbose
        `git remote rm gitlab`
        `git remote add gitlab #{url}`
        `git push gitlab --all`
      end
      puts "*"*80 if @verbose
    end
  end

  def sudo(id)
    Gitlab.sudo, old_sudo = id, Gitlab.sudo
    yield
  ensure
    Gitlab.sudo = old_sudo
  end
end

