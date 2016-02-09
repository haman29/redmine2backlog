require "redmine2backlog/version"

require 'faraday'
require 'json'

module Redmine2backlog
  def initialize opts
    @opts = opts.except(:redmine, :backlog)
    @redmine = Redmine.new(opts[:redmine])
  end

  def export
    @opts[:redmine][:projects]
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
