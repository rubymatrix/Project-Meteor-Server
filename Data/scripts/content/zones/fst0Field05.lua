--[[
South Shroud zone script: hears every event in the zone nobody else handled. Here it logs
how Camp Tranquil's caravan runs end.
--]]

local Shroud = Zone.define("fst0Field05")

function Shroud:onLoad(area)
    self.area = area
end

function Shroud:onEncounterEnded(ev)
    if ev.name == "CaravanGuardTranquil" then
        log('info', 'Camp Tranquil caravan ' .. tostring(ev.data))
    end
end

return Shroud
