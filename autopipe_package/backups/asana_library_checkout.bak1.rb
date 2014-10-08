#!/usr/bin/env ruby
require 'asana'
require 'curb'

Asana.configure do |client|
  client.api_key = '6y4EU8O.gjmExiqeVgWR8SzwADKxVwEx'
end

virome_queue_proid = ''
queue_tags = Hash.new

## User Information
user = Asana::User.me
user_name = user.name
# puts "Looks like #{user_name} is using the Asana API today!"

## Workspace information
workspaces = Asana::Workspace.all
# puts "Here's the first workspace: #{workspaces[0].name}"

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
  # puts "#{tag}\t#{tag.id}"
end
# puts "RUNNING: #{queue_tags["RUNNING"]}"
# puts "discrepancy #{queue_tags["discrepancy"]}"
# queue_tags.each do |key, value|
#   puts "#{key}\t#{value}\n"
# end

#c = Curl.get("https://app.asana.com/api/1.0/tasks/17100859824992?opt_fields=tags")
c = Curl.get("https://app.asana.com/api/1.0/tasks/15856091692812?opt_fields=tags")
c.http_auth_types = :basic
c.username = '6y4EU8O.gjmExiqeVgWR8SzwADKxVwEx'
c.password = ''
c.perform
unless /#{queue_tags["RUNNING"]}/.match(c.body_str)
  puts "Ready to roll with it."
end
## Get all libraries in the VIROME queue
# tasks = virome_queue_proid.tasks
# tasks.each do |task|
#   puts "#{task}\t#{task.name}"
# end

print "\n"
exit 0
