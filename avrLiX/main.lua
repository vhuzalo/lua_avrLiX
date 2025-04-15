local Voltage_Filtered  = 0

local translations = {en="avrLiX", de="avrLiX"}

local function name(widget)
    local locale = system.getLocale()
    return translations[locale] or translations["en"]
 
end

local function create()
    return {source=1, min=-1024, max=1024, value=0}
    --can be accessed with e.g. widget.souce
end

local function nullSafeGet(value) 
    if value == nil then return 0 end

    return value
end

local function CalcPercent(Voltage_Source, Cell_Count)

   Voltage_Source = nullSafeGet(Voltage_Source)
    
    -- the following table of percentages has 121 percentage values ,
    -- starting from 3.0 V to 4.2 V , in steps of 0.01 V 
   Voltage_Filtered = Voltage_Filtered * 0.9  +  Voltage_Source * 0.1

   local Percent_Table = 
   {0  , 1  , 1  ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 ,  1 , 
    2  , 2  , 2  ,  2 ,  2 ,  2 ,  2 ,  2 ,  2 ,  2 ,  3 ,  3 ,  3 ,  3 ,  3 ,  3 ,  3 ,  3 ,  3 ,  3 , 
    4  , 4  , 4  ,  4 ,  4 ,  4 ,  4 ,  4 ,  5 ,  5 ,  5 ,  5 ,  5 ,  5 ,  6 ,  6 ,  6 ,  6 ,  6 ,  6 , 
    7  , 7  , 7  ,  7 ,  8 ,  8 ,  9 ,  9 , 10 , 12 , 13 , 14 , 17 , 19 , 20 , 22 , 23 , 26 , 28 , 30 , 
    33 , 36 , 39 , 42 , 45 , 48 , 51 , 54 , 57 , 58 , 60 , 62 , 64 , 66 , 67 , 69 , 70 , 72 , 74 , 75 , 
    77 , 78 , 80 , 81 , 82 , 84 , 85 , 86 , 86 , 87 , 88 , 89 , 91 , 92 , 94 , 95 , 96 , 97 , 97 , 99 , 100  }
    
   if Cell_Count > 0 then 

     local Voltage_Cell    = 3
     local Battery_Percent = 0
     local Table_Index     = 1
     
     Voltage_Source = Voltage_Source * 100
     
     Voltage_Cell      = Voltage_Source / Cell_Count 
     Table_Index       = math.floor(Voltage_Cell - 298 )
     Battery_Connected = 1     

     if Table_Index    > 120 then  Table_Index = 120 end  --## check for index bounds
     if Table_Index    <   1 then  Table_Index =   1 end

     Battery_Percent   = Percent_Table[Table_Index]  
     
     return Battery_Percent
   end
 
end

local function round(num, dp)
    --[[
    round a number to so-many decimal of places, which can be negative, 
    e.g. -1 places rounds to 10's,  a]]--
    local mult = 10^(dp or 0)
    return math.floor(nullSafeGet(num) * mult + 0.5)/mult
end
local function paint(widget)

    local w, h = lcd.getWindowSize()

    if widget.voltageSource == nil then
        return
    end

    -- Define positions
    if h < 50 then
        lcd.font(FONT_S)
    elseif h < 80 then
        lcd.font(FONT_L)
    elseif h > 170 then
        lcd.font(FONT_XL)
    else
        lcd.font(FONT_STD)
    end

    local text_w, text_h = lcd.getTextSize("")
    local box_top, box_height = text_h, h - text_h - 4
    local box_left, box_width = 4, w - 8

    -- Source name and value
    lcd.drawText(box_left, 0, widget.voltageSource:name()..": "..widget.numberCells.."S")
    lcd.drawText(box_left + box_width, 0, round(widget.voltageSource:value(),2).." v", RIGHT)    
   
    --Calculate remaining percentage
    local remainingPercentage = CalcPercent(widget.voltageSource:value(), widget.numberCells)

    -- background
    lcd.color(lcd.RGB(200, 200, 200))
    lcd.drawFilledRectangle(box_left, box_top, box_width, box_height)
    
    --Voltage bar with color-changing according voltage
    if widget.lowAlarmVoltage then;

        widget.avgCellVoltage = nullSafeGet(widget.avgCellVoltage) 

        if (widget.avgCellVoltage >=widget.lowAlarmVoltage) then
            lcd.color(GREEN)
        else
            if (widget.avgCellVoltage<widget.lowAlarmVoltage and widget.avgCellVoltage>=widget.criticalAlarmVoltage) then
                lcd.color(YELLOW)
            else
                lcd.color(RED)
            end
        end
    end
    local gauge_width = (((box_width - 2)) * (remainingPercentage/100)) + 2
    lcd.drawFilledRectangle(box_left, box_top, gauge_width, box_height)

    --average Voltage Text
    lcd.color(BLACK)
    lcd.font(FONT_L)
    
    local voltageUnit =""

    local barText = round(widget.avgCellVoltage,2).."v   "..math.abs(remainingPercentage).."%"

    lcd.drawText(box_left + box_width / 2, box_top + (box_height - text_h) / 2, barText, CENTERED)
end

local function wakeup(widget)
    local switch = widget.calloutSwitch
    local numCell = widget.numberCells
    local secondsToRepeatAlarm = 6

    --First init of values (to prevent nil-Errors)
    if widget.sourceValue == nil then
        widget.sourceValue = 0
    end

    if widget.timeReadout == nil then
        widget.timeReadout = os.time()
    end
    if widget.timeLowAlarmReadout == nil then
        widget.timeLowAlarmReadout = os.time()
    end
    if widget.timeCriticalAlarmReadout == nil then
        widget.timeCriticalAlarmReadout = os.time()
    end

    if widget.timeAlarmRepeat == nil then
        widget.timeAlarmRepeat = os.time()
    end

    if widget.repeatReading == nil then
        widget.repeatReading = false
    end
    if widget.lowAlarmCallout == nil then
        widget.lowAlarmCallout = false
    end
    if widget.criticalAlarmCallout ==nil then
        widget.criticalAlarmCallout = false
    end
    if widget.lastTimeAlarmCheck == nil then
        widget.lastTimeAlarmCheck = os.time()
    end

    --trigger Refresh screen and value if voltageSource changes
    if widget.voltageSource then
        local newValue = widget.voltageSource:value()
        if widget.sourceValue ~= newValue then
            widget.sourceValue = newValue
            lcd.invalidate()
        end
    end
    --Calcualte avg Voltage
    
    widget.avgCellVoltage =  nullSafeGet(widget.sourceValue) / numCell

    --Play Voltage when switch is triggered and repeat
    if switch then
        if switch:state()  then
            if widget.repeatReading == true then
                system.playNumber(widget.avgCellVoltage,UNIT_VOLT,2)
                widget.repeatReading=false
            end
            --Repeate only every x seconds
            if (os.time()-widget.timeReadout)>widget.repeatSeconds then
                widget.timeReadout=os.time()
                widget.repeatReading=true    
            end
        else
            widget.repeatReading = true
            widget.timeReadout=os.time()
        end
    end
    
    -- Repeat alarm 
    if (os.time() - widget.lastTimeAlarmCheck) >= secondsToRepeatAlarm then
        widget.lowAlarmCallout = false;
        widget.criticalAlarmCallout = false;
    end 

    -- Skip reading when model not connected yet
    if widget.sourceValue == 0 then return end

    --AlarmVoltage Readout
    if widget.lowAlarmVoltage and widget.criticalAlarmVoltage and nullSafeGet(widget.avgCellVoltage) > 1 then 
        if (widget.avgCellVoltage <= widget.lowAlarmVoltage 
                    and widget.avgCellVoltage > widget.criticalAlarmVoltage
                    and widget.lowAlarmCallout == false
        ) then
        --Play alarm only when avg Voltage only x seconds under thresshold
        if (os.time() - widget.timeLowAlarmReadout) >= widget.waitSecondsLowAlarm then
            system.playFile("AUDIO:/vollow.wav")
            system.playHaptic("- . -")
            widget.lowAlarmCallout = true
            widget.lastTimeAlarmCheck = os.time()
        end
        elseif widget.avgCellVoltage > widget.lowAlarmVoltage then
            widget.lowAlarmCallout = false
            widget.timeLowAlarmReadout = os.time()
        end

        if widget.avgCellVoltage <= widget.criticalAlarmVoltage and widget.criticalAlarmCallout == false then
            --Play alarm only when avg Voltage only x seconds under thresshold
            if (os.time() - widget.timeCriticalAlarmReadout) >= widget.waitSecondsCriticalAlarm then
                system.playFile("AUDIO:/volCrit.wav")
                system.playHaptic("- . -")
                widget.criticalAlarmCallout = true
                widget.lastTimeAlarmCheck = os.time()
            end
        elseif widget.avgCellVoltage > widget.criticalAlarmVoltage then
            widget.criticalAlarmCallout = false
            widget.timeCriticalAlarmReadout = os.time()
        end
    end 

end --function

local function configure(widget)
    line = form.addLine("Source")
    form.addSourceField(line, nil, function() return widget.voltageSource end, function(value) widget.voltageSource = value end)
    line = form.addLine("Callout Switch / Repeat")
    local r  = form.getFieldSlots(line,{0,0})
    form.addSwitchField(line, r[1], function() return widget.calloutSwitch end, function(value) widget.calloutSwitch = value end)
    local field = form.addNumberField(line, r[2],0, 60, function() return widget.repeatSeconds end, function(value) widget.repeatSeconds = value end)
    field:suffix(" s")
    field:default(30)
    line = form.addLine("Number Cell's")
    local field = form.addNumberField(line, nil,1, 20, function() return widget.numberCells end, function(value) widget.numberCells = value end)
    field:suffix(" Cells")
    field:default(1)
    line = form.addLine("min/max Voltage")
    local r  = form.getFieldSlots(line,{0,0})
    local field = form.addNumberField(line, r[1],1, 50, function() return widget.minCellVoltage*10 end, function(value) widget.minCellVoltage = value/10 end)
    field:suffix(" V")
    field:decimals(1)
    field:default(30)
    local field = form.addNumberField(line, r[2],1, 50, function() return widget.maxCellVoltage*10 end, function(value) widget.maxCellVoltage = value/10 end)
    field:suffix(" V")
    field:decimals(1)
    field:default(30)
    line = form.addLine("low Alarm V/delay")
    local r  = form.getFieldSlots(line,{0,0})
    local field = form.addNumberField(line, r[1],1, 50, function() return widget.lowAlarmVoltage*10 end, function(value) widget.lowAlarmVoltage = value/10 end)
    field:suffix(" V")
    field:decimals(1)
    field:default(30)
    local field = form.addNumberField(line, r[2],0, 20, function() return widget.waitSecondsLowAlarm end, function(value) widget.waitSecondsLowAlarm = value end)
    field:suffix(" s")
    field:default(1)
    line = form.addLine("critical Alarm V/delay")
    local r  = form.getFieldSlots(line,{0,0})
    local field = form.addNumberField(line, r[1],1, 50, function() return widget.criticalAlarmVoltage*10 end, function(value) widget.criticalAlarmVoltage = value/10 end)
    field:suffix(" V")
    field:decimals(1)
    field:default(30)
    local field = form.addNumberField(line, r[2],0, 20, function() return widget.waitSecondsCriticalAlarm end, function(value) widget.waitSecondsCriticalAlarm = value end)
    field:suffix(" s")
    field:default(1)

end --function

local function read(widget)
    widget.calloutSwitch = storage.read("calloutswitch")
    widget.numberCells = storage.read("numbercells")
    widget.minCellVoltage = storage.read("mincellvoltage")
    widget.maxCellVoltage = storage.read("maxcellvoltage")
    widget.voltageSource = storage.read("voltagesource")
    widget.repeatSeconds = storage.read("repatseconds")
    widget.lowAlarmVoltage = storage.read("lowalarmvoltage")
    widget.criticalAlarmVoltage = storage.read("criticalalarmvoltage")
    widget.waitSecondsLowAlarm = storage.read("waitsecondslowalarm")
    widget.waitSecondsCriticalAlarm = storage.read("waitsecondscriticalalarm")
end

local function write(widget)
    storage.write("calloutswitch",widget.calloutSwitch)
    storage.write("numberCells",widget.numberCells)
    storage.write("mincellvoltage",widget.minCellVoltage)
    storage.write("maxcellvoltage",widget.maxCellVoltage)
    storage.write("voltagesource",widget.voltageSource)
    storage.write("repatseconds",widget.repeatSeconds)
    storage.write("lowalarmvoltage",widget.lowAlarmVoltage)
    storage.write("criticalalarmvoltage",widget.criticalAlarmVoltage)
    storage.write("waitSecondsLowAlarm",widget.waitSecondsLowAlarm)
    storage.write("waitsecondscriticalalarm",widget.waitSecondsCriticalAlarm)
end

local function init()
    system.registerWidget({key="avrvolt", name=name, create=create, paint=paint, wakeup=wakeup, configure=configure, read=read, write=write})
end

return {init=init}