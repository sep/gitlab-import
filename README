# Gitlab Import

## What can it do?

It can import an export that was created by `gitorious-export`.

Supports the following things:

* Display exported users
* Display exported projects
* Gitlab:
    * Users - import, delete, list, load ssh keys
    * Projects - import, delete user projects, delete groups
    * Console - for interactive mode

## Running it

1. clone it
1. `bundle install`
1. `rake -T`

My recommended workflow:

1. setup `.env` file (see below)
1. `rake gitlab:import_users`
1. `rake gitlab:load_ssh_keys`
1. `rake gitlab:import_projects`

## Environment

    GITLAB_URL=http://your-url/api/v3
    GITLAB_TOKEN=your-root-api-token
    GITLAB_ROOT_ID=your-root-userid (probably 1)
    
    IMPORT_TEST_EMAIL=jon@sep.com
    IMPORT_DATA_DIR=../path-to-export
    IMPORT_DONT_PUSH=project1,project2
    
    VERBOSE=true

Note:

* `GITLAB_ROOT_ID` - __[optional]:__ probably `1`
* `IMPORT_TEST_EMAIL` - set this if you're testing.  if this is set:
  * the first user that the system creates will get this email address, and not whatever is on file for the import.  that way you can confirm the account and what-not.
  * all other email addresses will be prepended with `test-`
* `IMPORT_DATA_DIR` - this should be outside of the current directory.  I use `../output`
* `IMPORT_DONT_PUSH` - a comma separated list of project names to __not__ push.  Make sure and push these later!

## Filtering users

Create a `filtered.txt` file.  One email address per line.

This is useful for folks that might have accounts in the old system but should not have accounts in the new system.  All of their code will still be pushed.  It will be owned by __root__.

## SSH, during the import

The root user needs a key for all the pushing you're going to do during this import.

Now, it's likely that you're already a git user.  So your key may already be associated with your newly created user in gitlab.  Your key can't be associated with more than one account (your user, and the root user).  So, create yourself another key, and use an ssh config file to point at a different key, temporarily, while you're doing the import.

The config file goes in `~/.ssh/config` and looks something like:

    Host <git-host>
      HostName <git-host>
      User git
      IdentityFile ~/.ssh/<keyfile>

