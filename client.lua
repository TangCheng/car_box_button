local config = require("config")

local ALARM = 1
local parameter = config.read()
local joinCounter = 0
local joinMaxAttempts = 5

function post_data()
    ok, json = pcall(cjson.encode, {test="value"})
    if ok then
        print(json)
    else
        print("failed to encode!")
    end
    http.post("http://" .. parameter[config.URI] .. "/post",
        'Content-Type: application/json\r\n',
        json,
        function(code, data)
            if (code < 0) then
                print("HTTP request failed")
            else
                print(code, data)
            end
        end
    )
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
        wifi.sta.disconnect()
    end
end)


