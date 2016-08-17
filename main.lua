local conf = require("config")

if not conf.check() then
    print("config check fail!\n")
    dofile(server)
else
    dofile(button)
end


