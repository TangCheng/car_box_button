local indicator = require("indicator")

local INPUT = 6

pulse_input = 0
duration = 0

gpio.mode(INPUT, gpio.INT)

function pin_input_cb(level)
    if level == gpio.HIGH then 
        indicator.on()
        pulse_input = tmr.now()
        gpio.trig(INPUT, "down")
    else 
        duration = tmr.now() - pulse_input
        --print(duration / 1000000)
        if duration > 3000000 then
            print("trig to configuration.")
            gpio.mode(INPUT, gpio.INPUT)
            dofile("server.lc")(80)
        elseif duration > 500000 then
            print("trig to post data.")
            dofile("client.lc")
            indicator.off()
            gpio.trig(INPUT, "up")
        else
            indicator.off()
            gpio.trig(INPUT, "up")
        end
    end
end

gpio.trig(INPUT, "up", pin_input_cb)
