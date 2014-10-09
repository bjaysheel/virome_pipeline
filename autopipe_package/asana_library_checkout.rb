#!/usr/bin/env ruby
require 'asana'
require 'curb'

api_key = '6y4EU8O.gjmExiqeVgWR8SzwADKxVwEx'

Asana.configure do |client|
  client.api_key = api_key
end

## Globals
virome_queue_proid = ''
queue_tags = Hash.new

## Workspace information
workspaces = Asana::Workspace.all

## Project information
projects = Asana::Project.all
projects.each do |pro|
  if pro.name == "VIROME Queue"
    virome_queue_proid = pro
  end
end

## Get all tags from VIROME workspace and slam into queue_tags hash
tags = workspaces[0].tags
tags.each do |tag|
  queue_tags[tag.name] = tag.id
end

## Run through all libraries in the VIROME queue
tasks = virome_queue_proid.tasks
tasks.each do |task|
  c = Curl.get("https://app.asana.com/api/1.0/tasks/#{task.id}?opt_fields=tags,completed,notes")
  c.http_auth_types = :basic
  c.username = api_key
  c.password = ''
  c.perform
  if /"completed":false/.match(c.body_str)
    unless /#{queue_tags["RUNNING"]}/.match(c.body_str)
      unless /#{queue_tags["discrepancy"]}/.match(c.body_str)
        user    = task.name.split(" ::")[0]
        library = task.name.split(" ::")[1]
        library = library.sub(/./, '')
        file = c.body_str.split(",")[1].split(/"/)[3].split('\n')[0]
        asm = c.body_str.split(",")[1].split(/"/)[3].split('\n')[1]
        ## PASS INFO TO PERL ##
        # add_run_tag = `curl -u #{api_key}: https://app.asana.com/api/1.0/tasks/#{task.id}/addTag -d "tag=#{queue_tags["RUNNING"]}" > /dev/null 2> /dev/null`
        # puts "User = #{user}"
        # puts "Library = #{library}"
        # puts "File = #{file}"
        # puts "Asm = #{asm}"
        break
      end
    end
  end
end

print "\n"
exit 0
