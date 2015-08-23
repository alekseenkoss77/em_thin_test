#!/usr/bin/env rackup -s thin
require "thin"
require "eventmachine"
require "em-hiredis"
require "./lib/user"

EM.epoll

class AsyncApp
  
  def initialize
    @users = User.new
    @file = File.read('fixtures/blank.gif')
  end

  def call(env)
    request = Rack::Request.new(env)
    response = Rack::Response.new(@file, 200, { 'Content-Type' => 'image/gif' })

    @users.db = EM::Hiredis.connect
    @users.identify_by_ip(env['REMOTE_ADDR'], env['SERVER_NAME'], response)
    
    # if cookie is empty, then generate user_id end setup cookies
    cookie = if request.cookies["em_user_id"]
               request.cookies["em_user_id"] 
             else
               id = SecureRandom.hex(10)
               response.set_cookie("em_user_id", { value: id, path: "/" })
               id
             end

    @users.identify_by_cookie(cookie, env['SERVER_NAME'], response)
    response.finish
  end
end

run AsyncApp.new
