#!/usr/bin/env ruby
require 'faye/websocket'
require 'eventmachine'

EM.run {
  ws = Faye::WebSocket::Client.new('ws://172.20.0.1:3000/actions')

  ws.on :open do |event|
    ws.send("bind(#{ENV['MAC']})")
  end

  ws.on :message do |event|
    # p [:message, event.data]
    cmd, args = event.data.chop.split '('
    args = args.split ','

    case cmd
    when 'reboot'
      if args[0] == ENV['id']
        log = "job #{ENV['id']} will be canceled"
        ws.send("log(#{log})")
        `reboot`
      end
    end
  end

  ws.on :close do |event|
    ws = nil
  end
}
