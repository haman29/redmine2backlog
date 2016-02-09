require "redmine2backlog/version"

require 'faraday'
require 'json'

require 'backlog_kit'
require 'pandoc-ruby'

class Redmine2backlog
  attr_reader :opts, :redmine, :backlog

  def initialize opts
    @opts = opts
    @redmine = Redmine.new(opts[:redmine])
    @backlog = Backlog.new(opts[:backlog])
  end

  def redmine_wikis
    @redmine_wikis ||= redmine.projects.map do |project|
      project.wikis["wiki_pages"].map do |wiki|
        project.wikis(wiki["title"])
      end
    end.flatten
  end

  def import_wikis
    redmine_wikis.each do |wiki|
      import_wiki(wiki["wiki_page"]['title'], wiki["wiki_page"]['text'])
    end
  end

  private

  def import_wiki title, content
    backlog.client.post('wikis', {
      projectId: backlog.project_id,
      name: title,
      content: convert(content)
    })
  rescue => e
    puts "rename '#{title}' --> '#{title} : dup'"
    if e.message.match(/Name already exist/)
      import_wiki "#{title} : dup", content
    end
  end

  def convert text
    PandocRuby.convert(text, {:f => :textile, :to => :markdown}).gsub(/\\\[\\\[(.*)\\\]\\\]/, '[[\1]]')
  end
end

class Redmine
  attr_reader :opts, :key

  def key; @key ||= opts[:key]; end

  def initialize opts
    @opts = opts

    @conn = Faraday.new(:url => opts[:host]) do |conn|
      conn.request  :url_encoded
      conn.response :logger
      conn.adapter  Faraday.default_adapter
    end
  end

  def get action, params, &block
    Response.new @conn.get action, params, block
  end

  def projects name = nil
    return opts[:projects].map{|p| Project.new(self, p)}  if name.nil?
  end


  class Project < Struct.new(:redmine, :name)
    def wikis wiki_name = nil
      if wiki_name
        redmine.get("/projects/#{self.name}/wiki/#{URI.encode(wiki_name)}.json", {key: redmine.key}).body
      else
        redmine.get("/projects/#{self.name}/wiki/index.json", {key: redmine.key}).body
      end
    end
  end

  class Response
    attr_accessor :raw, :body
    def initialize raw
      @raw = raw
      @body = JSON.parse(raw.body)
    end
  end
end

class Backlog
  attr_reader :opts, :client

  def initialize opts
    @opts = opts

    @client = BacklogKit::Client.new(space_id: opts[:space_id], api_key: opts[:key])
  end

  def project
    @project ||= client.get_project(opts[:project])
  end

  def project_id
    @project_id ||= project.body.id
  end

  def delete_all_wikis
    client.get_wikis(project_id).body.map do |w|
      client.delete_wiki(w.id) if w.name != 'Home'
    end
  end
end
