# lua-collectd-monitor

collectd plugins which provides fault recovery feature written in Lua.
Following 2 plugins are included:

* collectd/monitor/remote.lua
  * Receives pre-defined recovery commands from a remote host via MQTT and execute them. In addition it can replace collectd's config file with a new config received via MQTT.
  * This plugin itself doesn't have the feature to detect system faults.
  * It aims to detect system faults by another host which receives metrics data via collectd's network plugin, and send recovery commands from the host to this plugin.
* collectd/monitor/local.lua
  * Detects system faults according to metrics data collected by local collectd daemon and executes recovery commands. Trigger conditions are written in Lua code.


## Prerequisites

* Lua or LuaJIT
  * LuaJIT 2.1.0-beta3 is verified
* LuaRocks
* Forked version of collectd
  * You need to install customized version of collectd:
    https://github.com/clear-code/collectd/releases/tag/5.12.0.16.g6e9604f
  * Additional required callback functions are implemented in this branch.
* MQTT Broker
  * [VerneMQ](https://vernemq.com/) is verified
  * At least 2 topics should be accessible
    * For sending commands from a server
    * For replying command results from collectd


## Install

* Download and install lua-collectd-monitor:
```console
$ git clone https://github.com/clear-code/lua-collectd-monitor
$ sudo luarocks make
```
* Add settings like the following example to your collectd.conf (see [conf/collectd/collectd.conf.monitor-remote-example](conf/collectd/collectd.conf.monitor-remote-example) for more options of remote monitoring feature):
```xml
<LoadPlugin lua>
  Globals true
</LoadPlugin>

<Plugin lua>
  BasePath "/usr/local/share/lua/5.1"

  # Use remote monitoring feature.
  Script "collectd/monitor/remote.lua"
  <Module "collectd/monitor/remote.lua">
    MonitorConfigPath "/etc/collectd/monitor/config.json"
  </Module>

  # Use local monitoring feature.
  Script "collectd/monitor/local.lua"
  <Module "collectd/monitor/local">
    MonitorConfigPath "/etc/collectd/monitor/config.json"
    LocalMonitorConfigDir "/etc/collectd/monitor/local/"
  </Module>
</Plugin>
```
* Configure available recovery commands and connection settings at /etc/collectd/monitor/config.json
  * Copy [conf/collectd/monitor/config.json](conf/collectd/monitor/config.json) to /etc/collectd/monitor/config.json
  * Set permission of the file because it may include credentials
    `chmod 600 /etc/collectd/monitor/config.json`
  * Edit it to define available recovery commands and to connect to MQTT broker (if you use remote monitoring feature)
* If you use local monitoring feature, put additional config files written in Lua to /etc/collectd/monitor/local/ with the extension ".lua". See [conf/collectd/monitor/local/example.lua](conf/collectd/monitor/local/example.lua) for examples.


## Remote command feature

### Steps to test remote command feature

* Enable collectd/monitor/remote.lua in your collectd.conf
* Start collectd daemon
* Execute send-command.lua like the following example. It will send a command and receive a result:
```console
$ luajit /usr/local/share/lua/5.1/collectd/monitor/send-command.lua \
  hello \
  exec \
  --host 192.168.xxx.xxx \
  --user test-sender \
  --password test-sender \
  --topic test-topic \
  --result-topic test-result-topic
Send command: {"timestamp":"2020-11-26T00:41:19Z","service":"hello","task_id":3126260400,"command":"exec"}
{ -- PUBREC{type=5, packet_id=2}
  packet_id = 2,
  type = 5,
  <metatable> = {
    __tostring = <function 1>
  }
}
Received a result: { -- PUBLISH{qos=2, packet_id=1, dup=false, type=3, payload="{\\"timestamp\\":\\"2020-11-26T00:41:19Z\\",\\"message\\":\\"Hello World!\\",\\"task_id\\":3126260400,\\"code\\":0}", topic="test-result-topic", retain=false}
  dup = false,
  packet_id = 1,
  payload = '{"timestamp":"2020-11-26T00:41:19Z","message":"Hello World!","task_id":3126260400,"code":0}',
  qos = 2,
  retain = false,
  topic = "test-result-topic",
  type = 3,
  <metatable> = {
    __tostring = <function 1>
  }
}
```
* See `luajit ./collectd/monitor/send-command.lua --help` and its source code for more details

### Setting items of config.json

See [conf/collectd/monitor/config.json](conf/collectd/monitor/config.json) for an example.

|         Key        |  Type   | Contents |
|--------------------|---------|----------|
| Host               | string  | Host name and port of MQTT broker (e.g. `host` or `host:1883`) |
| User               | string  | Username for authorization on MQTT broker |
| Password           | string  | Password for authorization on MQTT broker |
| Secure             | boolean | Use TLS or not to connect to MQTT broker |
| CleanSession       | boolean | MQTT's [Clean Session flag](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html#_Ref362965194) |
| QoS                | number  | MQTT's [QoS level](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html#_Toc442180912) (`0`, `1`, `2`) |
| CommandTopic       | string  | MQTT topic name for sending commands |
| CommandResultTopic | string  | MQTT topic name for sending command results |
| Services           | object  | List of services to define recovery commands (See below) |
| LogDevice          | string  | Device to outout log (`stdout` or `syslog`) |
| LogLevel           | string  | Log level (`fatal`, `error`, `warn`, `info`, `debug`) |

Each key of `Services` is a service name and value is a following object:

|   Key    |  Type  | Contents |
|----------|--------|----------|
| Commands | Object | List of recovery commands: Each key is a command name and value is a recovery command |

### The message format of a remote command

Remote command & command result messages are formated in JSON.
Here is an example and member definitions of these messages:

#### Command message:

An example:

```json
{
  "task_id": 3126260400,
  "timestamp": "2020-11-26T00:41:19Z",
  "service": "hello",
  "command": "exec"
}
```

Members:

|   Field    |  Type  | Content |
|------------|--------|---------|
| task_id    | number | An unique task ID assigned by a command sender |
| timestamp  | string | Timestamp of a command (ISO8601 UTC) |
| service    | string | A service name defined in the config file specified by `MonitorConfigPath` |
| command    | string | A command name defined in the config file specified by `MonitorConfigPath` |

#### Command result message:

An example:

```json
{
  "task_id":3126260400,
  "timestamp": "2020-11-26T00:41:19Z",
  "message": "Hello World!",
  "code": 0
}
```

Members:

|   Field    |  Type  | Content |
|------------|--------|---------|
| task_id    | number | An unique task ID assigned by a command sender |
| timestamp  | string | Timestamp of a command result (ISO8601 UTC) |
| message    | string | Message of a command (STDOUT) |
| code       | number | Exit status of a command |


## Sending collectd.conf feature

### Steps to test sending collectd.conf feature

* Enable collectd/monitor/remote.lua in your collectd.conf
* Start collectd daemon
* Execute send-config.lua like the following example. It will send a config and receive a result:
```console
$ ./test-send-config.sh \
  path/to/new/collectd.conf \
  --host 192.168.xxx.xxx \
  --user test-sender \
  --password test-sender \
  --topic test-topic \
  --result-topic test-result-topic
Send config: {"timestamp":"2021-01-03T04:45:09Z","task_id":3689797623,"config":"LoadPlugin cpu\n<LoadPlugin lua>\n\tGlobals true\n</LoadPlugin>\n..."}
{ -- PUBREC{type=5, packet_id=2}
  packet_id = 2,
  type = 5,
  <metatable> = {
    __tostring = <function 1>
  }
}
Received a result: { -- PUBLISH{qos=2, packet_id=1, dup=false, type=3, payload="{\\"timestamp\\":\\"2021-01-03T04:45:09Z\\",\\"message\\":\\"Succeeded to replace config.\\",\\"task_id\\":3689797623,\\"code\\":0}", topic="test-result-topic", retain=false}
  dup = false,
  packet_id = 1,
  payload = '{"timestamp":"2021-01-03T04:45:09Z","message":"Succeeded to replace config.","task_id":3689797623,"code":0}',
  qos = 2,
  retain = false,
  topic = "test-result-topic",
  type = 3,
  <metatable> = {
    __tostring = <function 1>
  }
}
```
* See `luajit ./collectd/monitor/send-config.lua --help` and its source code for more details

### Configuring collectd.conf path

The path of collectd.conf can be configured by adding like the following setting to your [config.json](conf/collectd/monitor/config.json). If this setting isn't exist, lua-collectd-monitor tryies to find it automatically, but it may fail depending environment.

```json
  "Services": {
    ...
    "collectd": {
      "ConfigPath" : "/path/to/collectd.conf"
    },
    ...
  }
```

### The message format of sending collectd.conf

Message to sending collectd.conf & results are formated in JSON.
Here is an example and member definitions of these messages:

#### A message to send collectd.conf

An example:

```json
{
  "task_id": 3126260401,
  "timestamp": "2020-12-26T00:41:19Z",
  "config": "<Plugin>\ncpu</Plugin>..."
}
```

Members:

|   Field    |  Type  | Content |
|------------|--------|---------|
| task_id    | number | An unique task ID assigned by a sender |
| timestamp  | string | Timestamp of a message (ISO8601 UTC) |
| config     | string | Content of new collectd.conf |

#### Result message of sending collectd.conf:

An example:

```json
{
  "task_id":3126260401,
  "timestamp": "2020-12-26T00:41:19Z",
  "message": "Succeeded to replace config.",
  "code": 0
}
```

Members:

|   Field    |  Type  | Content |
|------------|--------|---------|
| task_id    | number | An unique task ID assigned by a sender |
| timestamp  | string | Timestamp of a result (ISO8601 UTC) |
| message    | string | A result message |
| code       | number | A result code (See below) |

Here is the defined result codes:

|     Code      | Content |
|---------------|---------|
| 0             | Succeeded |
| 8192 (0x2000) | Another task is already running |
| 8193 (0x2001) | Failed to write new config |
| 8194 (0x2002) | New config is broken |
| 8195 (0x2003) | Cannot stop collectd |
| 8196 (0x2004) | pid file of collectd isn't removed |
| 8197 (0x2005) | Failed to backup old collectd.conf |
| 8198 (0x2006) | Failed to replace collectd.conf |
| 8199 (0x2007) | Recovered by the old collectd.conf due to failing restart |
| 8200 (0x2008) | Failed to restart and failed to recover by the old collect.conf |
| 8201 (0x2009) | Cannot get new pid |


## Local monitoring feature

### Steps to test local monitoring feature

* Use [conf/collectd/collectd.conf.monitor-local-example](conf/collectd/collectd.conf.monitor-local-example) as your collectd.conf
* Copy [conf/collectd/monitor/config.json](conf/collectd/monitor/config.json) to /etc/collectd/monitor/config.json
  * Check the file to confirm pre-defined recovery commands and edit it if needed
* Copy [conf/collectd/monitor/local/example.lua](conf/collectd/monitor/local/example.lua) to /etc/collectd/monitor/local/
  * Check the file to confirm recovery conditions and edit it if needed
* Start collectd daemon
* See your syslog to confirm that a collectd's notification is emitted like this:
```
Notification: severity = OKAY, host = localhost, plugin = lua-collectd-monitor-local, type = /etc/collectd/monitor/local/example.lua::write::memory_free_is_under_10GB, message = {"message":"Hello World!","task_id":244078840,"code":0}
```

### Configuration of recovery commands and trigger conditions

* Recovery commands are pre-defined in config.json as same as remote.lua plugin. Please see [conf/collectd/monitor/config.json](conf/collectd/monitor/config.json) for an example.
* Trigger conditions are written in Lua. Please see [conf/collectd/monitor/local/example.lua](conf/collectd/monitor/local/example.lua) for an example.

### Notification of command resutls

Results of commands are notified by collectd's [Notification](https://collectd.org/wiki/index.php/Notification_t) feature. You can receive them at remote hosts too by using collectd's network plugin.

The values of each fields in Notification is following:

|      Field      | Content |
|-----------------|---------|
| severity        | `4` (`NOTIF_OKAY`): Success, `1` (`NOTIF_FAILURE`): Fail |
| host            | Host name |
| plugin          | `lua-collectd-moitor-local` (Fixed) |
| plugin_instance | None (Empty string) |
| type            | A call back name which executed the command |
| type_instance   | None (Empty string) |
| time            | Timestamp (UNIX time) |
| message         | Detail of the result (JSON format) |

The contents of the `message`:

|   Field    |  Type  | Content |
|------------|--------|------|
| task_id    | number | An unique task ID |
| message    | string | Message of a command (STDOUT) |
| code       | number | Exit status of a command |

Note that `message` will be omitted if it's too long because max length of `message` field of Notificatoin is 128.
