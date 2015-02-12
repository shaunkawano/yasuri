#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Author::    TAC (tac@tac42.net)

require 'mechanize'
require 'pp'
require 'time'

Trigger = Struct.new("Trigger", :url, :xpath, :cond)

@agent = Mechanize.new

###########
# trigger #
###########
def trigger(trigger, agent = @agent)
  page = @agent.get(trigger.url)
  node = page.search(trigger.xpath).text
  trigger.cond.(node.to_s)
end

module Cond
  True       = lambda{|node| true }
  False      = lambda{|node| false }

  module_function
  def NewerThen(time = Time.now); lambda{|node| Time.parse(node) > time }; end
  def OlderThen(time = Time.now); lambda{|node| Time.parse(node) < time }; end
  def Modify(last); lambda{|node| node != last }; end
  def Match(pattern); lambda{|node| node =~ pattern }; end

  def and(*cond)
    lambda{|node| cond.all?{|c| c.(node)}}
  end
  def or(*cond)
    lambda{|node| cond.any?{|c| c.(node)}}
  end
  def not(cond)
    lambda{|node| not cond.(node) }
  end
end
# c = Cond::and( Cond::Match(/\d/), Cond::NewerThen() )
c = Cond::Modify("2月11日 19時04分")
t = Trigger.new("http://www3.nhk.or.jp/news/", "//*[@id='topttl']/a/span", c)

begin
  puts trigger(t)
rescue => e
  puts e.message
  pp e
end

########
# Node #
########
class Node
  attr_reader :url, :xpath, :name

  def initialize(xpath, name, children = [])
    @xpath, @name, @children = xpath, name, children
  end

  def inject(agent, page)
    raise "Not implemented method."
  end
end

class ContentNode < Node
  def inject(agent, page)
    node = page.search(@xpath)
    node.text.to_s
  end
end

class LinksNode < Node
  def inject(agent, page)
    links = page.search(@xpath) # links expected
    links.map do |link|
      link_button = Mechanize::Page::Link.new(link, agent, page)
      child_page = link_button.click

      child_results_kv = @children.map do |child_node|
        [child_node.name, child_node.inject(agent, child_page)]
      end

      Hash[child_results_kv]
    end # each named child node
  end
end

root = LinksNode.new('//*[@id="menu"]/ul/li/a', "root", [
         ContentNode.new('//*[@id="contents"]/h2', "title"),
         ContentNode.new('//*[@id="contents"]/p[1]', "content"),
       ]
)

root_page = @agent.get("http://www.tac42.net/")
result = root.inject(@agent, root_page)
result.each.with_index do |l, idx|
  puts l["title"]
  puts l["content"]
  puts "--" * 10
end
