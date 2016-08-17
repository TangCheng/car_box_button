indicator = {}

local LED = 5
local ALARM = 0

indicator.FAST = "0"
indicator.NORMAL = "1"
indicator.SLOW = "2"

local SPEED = {
    indicator.FAST = 500,
    indicator.NORMAL = 1000,
    indicator.SLOW = 2000
}

function indicator.init()
    gpio.mode(LED, gpio.OUTPUT)
    gpio.write(LED, gpio.LOW)
    tmr.stop(ALARM)
end

function indicator.on()
    tmr.stop(ALARM)
    gpio.write(LED, gpio.LOW)
end

function indicator.off()
    tmr.stop(ALARM)
    gpio.write(LED, gpio.HIGH)
end

flash_flag = true

function indicator.flash(speed)
    if SPEED[speed] ~= nil then
        tmr.stop(ALARM)
        tmr.alarm(ALARM, SPEED[speed], 1, function()
            tmr.wdclr()
            if flash_flag then
                flash_flag = false
                gpio.write(LED, gpio.LOW)
            else
                flash_flag = true
                gpio.write(LED, gpio.HIGH)
            end
        end)
    end
end

return indicator
