local conf = require("config")
local button = require("button")

if not conf.check() then
    print("config check fail!\n")
end


