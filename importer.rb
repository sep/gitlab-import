class Importer
  attr_accessor :user_hash, :group_hash, :project_hash, :gitlab

  def initialize(user_hash, group_hash, project_hash, repo_dir, gitlab, dont_push_list, opts)
    @user_hash = user_hash
    @group_hash = group_hash
    @project_hash = project_hash
    @dont_push_list = dont_push_list
    @repo_dir = repo_dir
    @gitlab = gitlab
    @verbose = opts[:verbose] || false
    @test_email = opts[:test_email]
    @root_id = (ENV['GITLAB_ROOT_ID'] || 1).to_i
  end

  def get_email(email, index)
    return email unless @test_email
    return @test_email if index == 0
    "test-#{email}"
  end

  def get_username(email)
    return '' unless email
    email.split('@').first
  end

  def get_filtered_users
    filename = 'filtered.txt'
    return {} unless File.exists?(filename)

    File.read(filename)
      .lines
      .map{|l| l.strip}
      .reject{|l| l.empty?}
      .inject({}){|memo, obj| memo[obj] = obj; memo}
  end

  def create_users
    to_filter = get_filtered_users
    @user_hash
      .reject{|u| to_filter.has_key?(u['email'])}
      .reject{|u| u['email'] == nil}
      .each_with_index do |u, i|
        email = get_email(u['email'], i)
        name = get_username(u['email'])
        puts "creating #{email} - #{name}" if @verbose
        @gitlab.create_user(email, 'password', {username: name, name: name, projects_limit: 9999})
      end
  end

  def delete_ssh_keys
    get_users
      .each do |u|
        puts "deleting keys for: #{u.username}" if @verbose
        sudo(u.id) do
          @gitlab.ssh_keys({per_page: 9999}).each do |key|
            @gitlab.delete_ssh_key(key.id)
          end
        end
      end
  end

  def load_ssh_keys
    @gitlab
      .users
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

  def sanitize(name)
    name
      .gsub('!', '')
      .gsub('&', '-')
  end

  def get_groups(per_page=9999)
    @gitlab.groups({per_page: per_page})
  end

  def get_users(per_page=9999)
    @gitlab.users({per_page: per_page})
  end

  def get_user_projects(user, per_page=9999)
    sudo(user.id) do
      @gitlab.projects({scope: 'owned', per_page: per_page})
    end
  end

  def get_projects(per_page=9999)
    @gitlab.projects({scope: 'all', per_page: per_page})
  end

  def create_projects
    gitlab_users = get_users.inject({}){|memo, obj| memo[obj.username] = obj; memo}

    @project_hash
      .reject{|p| gitlab_users[p['title']]}
      .each do |gitorious_project|
        title = sanitize(gitorious_project['title'])
        puts "creating group for #{title}" if @verbose

        group = @gitlab.create_group(title, gitorious_project['slug'])
        add_users_to_group(group, gitorious_project)
        add_repos(group, gitorious_project, @root_id)
      end

    @project_hash
      .find_all{|p| gitlab_users[p['title']]}
      .each do |gitorious_project|
        puts "creating user repos for #{gitorious_project['title']} - (#{gitlab_users[gitorious_project['title']].username})" if @verbose
        add_repos(nil, gitorious_project, gitlab_users[gitorious_project['title']].id)
      end
  end

  def add_users_to_project(gitlab_project, gitorious_repo)
    gitlab_users = get_users.inject({}){|memo, obj| memo[obj.username] = obj.id; memo}

    existing_users = gitorious_repo['committers']
      .reject{|p| not_there = !(gitlab_users.has_key?(p)); puts "    ignoring committer #{p}, not in gitlab." if not_there && @verbose; not_there}
      .map{|u| {username: u, id: gitlab_users[u]}}

    existing_users.each do |u|
      puts "    adding user to project - #{u[:username]}" if @verbose
      @gitlab.add_team_member(gitlab_project.id, u[:id], 50)
    end
  end

  def add_users_to_group(gitlab_group, gitorious_project)
    gitlab_users = get_users.inject({}){|memo, obj| memo[obj.username] = obj.id; memo}

    existing_users = gitorious_project['repositories']
      .map{|r| r['committers']}
      .flatten
      .uniq
      .reject{|p| not_there = !(gitlab_users.has_key?(p)); puts "  ignoring committer #{p}, not in gitlab." if not_there && @verbose; not_there}
      .map{|u| {username: u, id: gitlab_users[u]}}

    existing_users.each do |u|
      puts "  adding user to group - #{u[:username]}" if @verbose
      @gitlab.add_group_member(gitlab_group.id, u[:id], 50)
    end
  end

  def add_repos(gitlab_group = nil, gitorious_project, owner_id)
    gitorious_project['repositories'].each do |repo|
      gitorious_repo_dir = File.join(@repo_dir, gitorious_project['slug'], "#{repo['name']}.git")
  
      if !Dir.exists?(gitorious_repo_dir)
       puts "skipping bogus repo #{repo['name']}" if @verbose
       next
      end

      rugged_repo = Rugged::Repository.new(gitorious_repo_dir)
      if rugged_repo.empty?
       puts "skipping empty repo #{repo['name']}" if @verbose
       next
      end
  
      name = sanitize(repo['name'] == 'production' ? 'something' : repo['name'])
      description = (repo['description'] || '').empty? ? name : repo['description']

      puts "  adding project/repo to group - #{name}" if @verbose

      new_project = @gitlab.create_project(
        name,
        {description: description, wiki_enabled: true, wall_enabled: true, issues_enabled: true, snippets_enabled: true, merge_requests_enabled: true, public: true, user_id: owner_id})
  
      if gitlab_group
        [1, 2, 3].each do |i|
          begin
            @gitlab.transfer_project_to_group(gitlab_group.id, new_project.id)
            break
          rescue
            "  transfer failed on try #{i}, waiting a little and then retrying (maybe)"
           sleep(0.2)
          end
        end
        new_project = @gitlab.project(new_project.id)
      end
  
      add_users_to_project(new_project, repo)
      push_repo(new_project, rugged_repo)
    end
  end

  def push_repo(gitlab_project, repo)
    Dir.chdir(repo.path) do
      url = gitlab_project.ssh_url_to_repo

      Rugged::Remote.add(repo, 'gitlab', url) if repo.remotes.none?{|remote| remote.name == 'gitlab'}
   
      if @dont_push_list.none?{|i| i == gitlab_project.name}
        puts "    pushing to #{url}" if @verbose
        `git push gitlab --mirror`
      else
        puts "  ** not pushing #{gitlab_project.name}, it's in the ignore list"
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

