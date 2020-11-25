local luaunit = require("luaunit")
local utils = require("collectd/monitor/utils")

TestUtils = {}

function TestUtils:test_merge_table()
   local table1 = { key1 = 1 }
   local table2 = { key2 = 2 }
   luaunit.assert_equals({ key1 = 1, key2 = 2 }, utils.merge_table(table1, table2))
end

function TestUtils:test_override_table()
   local table1 = { key1 = 1 }
   local table2 = { key1 = 2 }
   luaunit.assert_equals({ key1 = 2 }, utils.merge_table(table1, table2))
end

function TestUtils:test_copy_table()
   local table = { key1 = 1 }
   local actual = utils.copy_table(table)
   table.key1 = 2
   luaunit.assert_equals({ key1 = 1 }, actual)
end

function TestUtils:test_load_config()
   local conf, err_msg = utils.load_config('test/fixtures/test-config.json')
   local expected = {
      conf = {
         User = "user1",
         Password = "password",
      },
      err_msg = nil,
   }
   local actual = {
      conf = conf,
      err_msg = err_msg,
   }
   luaunit.assert_equals(expected, actual)
end

function TestUtils:test_broken_config()
   local path = 'test/fixtures/test-broken-config.json'
   local conf, err_msg = utils.load_config(path)
   local expected = {
      conf = {},
      err_msg = "Failed to load " .. path,
   }
   local actual = {
      conf = conf,
      err_msg = err_msg,
   }
   luaunit.assert_equals(expected, actual)
end