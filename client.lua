local config = require("config")

local ALARM = 1
local parameter = config.read()
local joinCounter = 0
local joinMaxAttempts = 5

function post_data()
    --{
        --"button": num,
        --"geo": {
            --"lat": 22.9999922,
            --"lng": 114.0000000
        --}
    --}
    latitude = math.random(89) + math.random()
    latitude = tonumber(string.format("%.7f", latitude))
    longitude = math.random(179) + math.random()
    longitude = tonumber(string.format("%.7f", longitude))
    ok, json = pcall(cjson.encode, {button = 1, geo = {lat = latitude, lng = longitude}})
    if ok then
        print(json)
    else
        print("failed to encode!")
    end
    local url = 'http://' .. parameter[config.URI]
    print(url)
    http.post(url,
        'Content-Type: application/json\r\n',
        json,
        function(code, data)
            if (code < 0) then
                print("HTTP request failed")
            else
                print(code, data)
            end
            wifi.sta.disconnect()
        end
    )
    --sk = net.createConnection(net.TCP, 0)
    --sk:on("receive", function(sck, c) print(c) end)
    --sk:on("connection", function(sck, c)
        --sck:send("POST / HTTP/1.1\r\nHost: " .. url .. "\r\nContent-Type: application/json\r\n{\"test\":\"value\"}\r\n\r\n")
    --end)
    --local address, port = parameter[URI]:match("([^:]+):([^:]+)")
    --if port == nil then port = 80 end
    --print(address .. port)
    --sk:connect(#port, address)
end

wifi.setmode(wifi.STATION)
wifi.sta.config(parameter[config.SSID], parameter[config.PWD])
wifi.sta.connect()

tmr.alarm(ALARM, 3000, 1, function()
    local ip = wifi.sta.getip()
    if ip == nil and joinCounter < joinMaxAttempts then
        print('Connecting to WiFi Access Point ...')
        joinCounter = joinCounter +1
    else
        if joinCounter == joinMaxAttempts then
            print('Failed to connect to WiFi Access Point.')
        else
            print('IP: ',ip)
            post_data()
        end
        tmr.stop(ALARM)
        joinCounter = nil
        joinMaxAttempts = nil
        collectgarbage()
    end
end)


