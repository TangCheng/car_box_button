local conf = require("config")
local indicator = require("indicator")

indicator.init()

if not conf.check() then
    print("config check fail!\n")
    dofile("server.lc")(80)
else
    dofile("button.lc")
end


