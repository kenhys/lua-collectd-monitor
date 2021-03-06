#!/usr/bin/env lua

local inspect = require('inspect')
local mqtt = require('mqtt')
local lunajson = require('lunajson')
local argparse = require('argparse')

local parser = argparse("send-command", "Send a command to monitor-remote.lua")
parser:argument("config_path", "A path to collectd's config file to send")
parser:option("-h --host", "MQTT Broker", "localhost")
parser:option("-u --user", "MQTT User")
parser:option("-p --password", "Password for the MQTT user")
parser:flag("-s --secure", "Use TLS", false)
parser:option("-q --qos", "QoS for the command", 2)
parser:option("-t --topic", "Topic to send")
parser:option("-r --result-topic", "Topic to receive command result")

local args = parser:parse()

local published = false
local received = false

local file, err = io.open(args.config_path, "rb")
if err then
   print(err)
   os.exit(1)
end
local config = file:read("*a")
file:close()

function new_client()
   local client = mqtt.client {
      uri = args.host,
      username = args.user,
      password = args.password,
      secure = args.secure,
      clean = false,
   }

   client:on {
      connect = function(reply)
         if reply.rc ~= 0 then
            io.stderr:write("Failed to connect to broker: ",
                            reply:reason_string(), "\n")
            return
         end

         subscribe(client)

         if published then
            return
         end

         math.randomseed(os.clock())
         local message = {
            task_id = math.random(1, 2^32),
            timestamp = os.date("!%Y-%m-%dT%TZ"),
            config = config
         }
         local message_json = lunajson.encode(message)

         print("Send config: " .. message_json)

         local publish_options = {
            topic = args.topic,
            payload = message_json,
            qos = tonumber(args.qos),
            callback = function(packet)
               print(inspect(packet))
               if not args.result_topic then
                  assert(client:disconnect())
               end
            end,
         }
         assert(client:publish(publish_options))
         published = true
      end,

      message = function(packet)
         print("Received a result: " .. inspect(packet))
         received = true
         assert(client:acknowledge(packet))
         assert(client:disconnect())
      end,

      error = function(msg)
         io.stderr:write(msg, "\n")
         assert(client:disconnect())
      end,

      close = function(connection)
         print("MQTT connection closed: ", connection.close_reason)
      end,
   }

   function subscribe(client)
      if not args.result_topic then
         return
      end

      local subscribe_options = {
         topic = args.result_topic,
         qos = tonumber(args.qos),
      }
      assert(client:subscribe(subscribe_options))
   end

   return client
end

mqtt.run_ioloop(new_client())
local first_retry_time = os.time()
while args.result_topic and not received do
   -- The connection may be closed by broker when collectd is restarted.
   -- Use a new client to reset the state in this case.
   mqtt.run_ioloop(new_client())
   if os.time() - first_retry_time >= 60 then
      print("Timed out to receive a reply!")
      break
   end
end
