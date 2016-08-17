local indicator = require("indicator")

-- httpserver
-- Author: Marcos Kirsch

-- Starts web server in the specified port.
local wifiConfig = {}

-- wifi.STATION         -- station: join a WiFi network
-- wifi.SOFTAP          -- access point: create a WiFi network
-- wifi.wifi.STATIONAP  -- both station and access point
wifiConfig.mode = wifi.SOFTAP  -- both station and access point

wifiConfig.accessPointConfig = {}
wifiConfig.accessPointConfig.ssid = "CARBOX-"..node.chipid()   -- Name of the SSID you want to create
wifiConfig.accessPointConfig.pwd = "CARBOX-"..node.chipid()    -- WiFi password - at least 8 characters

wifiConfig.accessPointIpConfig = {}
wifiConfig.accessPointIpConfig.ip = "192.168.100.1"
wifiConfig.accessPointIpConfig.netmask = "255.255.255.0"
wifiConfig.accessPointIpConfig.gateway = "192.168.100.1"

wifi.setmode(wifiConfig.mode)
print('set (mode='..wifi.getmode()..')')
print('AP MAC: ',wifi.ap.getmac())

wifi.ap.config(wifiConfig.accessPointConfig)
wifi.ap.setip(wifiConfig.accessPointIpConfig)

wifiConfig = nil
collectgarbage()

return function (port)
    indicator.flash(indicator.NORMAL)

    local s = net.createServer(net.TCP, 10) -- 10 seconds client timeout
    s:listen(port, function (connection)
        -- This variable holds the thread (actually a Lua coroutine) used for sending data back to the user.
        -- We do it in a separate thread because we need to send in little chunks and wait for the onSent event
        -- before we can send more, or we risk overflowing the mcu's buffer.
        local connectionThread

        local allowStatic = {GET=true, HEAD=true, POST=false, PUT=false, DELETE=false, TRACE=false, OPTIONS=false, CONNECT=false, PATCH=false}

        local function startServing(fileServeFunction, connection, req, args)
            connectionThread = coroutine.create(function(fileServeFunction, bufferedConnection, req, args)
                fileServeFunction(bufferedConnection, req, args)
                -- The bufferedConnection may still hold some data that hasn't been sent. Flush it before closing.
                if not bufferedConnection:flush() then
                    connection:close()
                    connectionThread = nil
                end
            end)

            local BufferedConnectionClass = dofile("server-connection.lc")
            local bufferedConnection = BufferedConnectionClass:new(connection)
            local status, err = coroutine.resume(connectionThread, fileServeFunction, bufferedConnection, req, args)
            if not status then
                print("Error: ", err)
            end
        end

        local function handleRequest(connection, req)
            collectgarbage()
            local method = req.method
            local uri = req.uri
            local fileServeFunction = nil

            if #(uri.file) > 32 then
                -- nodemcu-firmware cannot handle long filenames.
                uri.args = {code = 400, errorString = "Bad Request"}
                fileServeFunction = dofile("server-error.lc")
            else
                print(uri.file)
                local fileExists = file.open(uri.file, "r")
                file.close()

                if not fileExists then
                    -- gzip check
                    fileExists = file.open(uri.file .. ".gz", "r")
                    file.close()

                    if fileExists then
                        --print("gzip variant exists, serving that one")
                        uri.file = uri.file .. ".gz"
                        uri.isGzipped = true
                    end
                end

                if not fileExists then
                    uri.args = {code = 404, errorString = "Not Found"}
                    fileServeFunction = dofile("server-error.lc")
                elseif uri.isScript then
                    fileServeFunction = dofile(uri.file)
                else
                    if allowStatic[method] then
                        uri.args = {file = uri.file, ext = uri.ext, isGzipped = uri.isGzipped}
                        fileServeFunction = dofile("server-static.lc")
                    else
                        uri.args = {code = 405, errorString = "Method not supported"}
                        fileServeFunction = dofile("server-error.lc")
                    end
                end
            end
            startServing(fileServeFunction, connection, req, uri.args)
        end

        local function onReceive(connection, payload)
            collectgarbage()
            local conf = dofile("server-conf.lc")
            local auth
            local user = "Anonymous"

            -- as suggest by anyn99 (https://github.com/marcoskirsch/nodemcu-httpserver/issues/36#issuecomment-167442461)
            -- Some browsers send the POST data in multiple chunks.
            -- Collect data packets until the size of HTTP body meets the Content-Length stated in header
            if payload:find("Content%-Length:") or bBodyMissing then
                if fullPayload then fullPayload = fullPayload .. payload else fullPayload = payload end
                if (tonumber(string.match(fullPayload, "%d+", fullPayload:find("Content%-Length:")+16)) > #fullPayload:sub(fullPayload:find("\r\n\r\n", 1, true)+4, #fullPayload)) then
                    bBodyMissing = true
                    return
                else
                    --print("HTTP packet assembled! size: "..#fullPayload)
                    payload = fullPayload
                    fullPayload, bBodyMissing = nil
                end
            end
            collectgarbage()

            -- parse payload and decide what to serve.
            local req = dofile("server-request.lc")(payload)
            print(req.method .. ": " .. req.request)
            if conf.auth.enabled then
                auth = dofile("server-basicauth.lc")
                user = auth.authenticate(payload) -- authenticate returns nil on failed auth
            end

            if user and req.methodIsValid and (req.method == "GET" or req.method == "POST" or req.method == "PUT") then
                handleRequest(connection, req)
            else
                local args = {}
                local fileServeFunction = dofile("server-error.lc")
                if not user then
                    args = {code = 401, errorString = "Not Authorized", headers = {auth.authErrorHeader()}}
                elseif req.methodIsValid then
                    args = {code = 501, errorString = "Not Implemented"}
                else
                    args = {code = 400, errorString = "Bad Request"}
                end
                startServing(fileServeFunction, connection, req, args)
            end
        end

        local function onSent(connection, payload)
            collectgarbage()
            if connectionThread then
                local connectionThreadStatus = coroutine.status(connectionThread)
                if connectionThreadStatus == "suspended" then
                    -- Not finished sending file, resume.
                    local status, err = coroutine.resume(connectionThread)
                    if not status then
                        print(err)
                    end
                elseif connectionThreadStatus == "dead" then
                    -- We're done sending file.
                    connection:close()
                    connectionThread = nil
                end
            end
        end

        local function onDisconnect(connection, payload)
            if connectionThread then
                connectionThread = nil
                collectgarbage()
            end
        end

        connection:on("receive", onReceive)
        connection:on("sent", onSent)
        connection:on("disconnection", onDisconnect)
    end)
    -- false and nil evaluate as false
    local ip = wifi.sta.getip()
    if not ip then ip = wifi.ap.getip() end
    if not ip then ip = "unknown IP" end
    print("server running at http://" .. ip .. ":" ..  port)
    return s
end

