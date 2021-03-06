print("\n")
print("Car Box Started")

local files = {
    "main",
    "button",
    "config",
    "server",
    "server-error",
    "server-basicauth",
    "server-conf",
    "server-static",
    "server-header",
    "server-connection",
    "server-request",
    "server-b64decode",
    "client",
    "indicator"
}
local luafile = nil
local exefile = "main"

for i, f in ipairs(files) do
    luafile = f..".lua"
    if file.open(luafile) then
        file.close()
        print("Compile File:"..luafile)
        node.compile(luafile)
        print("Remove File:"..luafile)
        file.remove(luafile)
    end
end

if file.open(exefile..".lc") then
    dofile(exefile..".lc")
else
    print(exefile..".lc not exist")
end

files = nil
luafile = nil
exefile = nil
collectgarbage()
