


-- Goal:
--   When LTN assigns a schedule, based on settings:
--     Remove directionality from temporary stops
--   OR
--     Remove temporary stops entirely



util = require("util")

local remove_temporary_stops = false
local remove_temporary_directions = false
local remove_temporary_directions_smart = false
local debug_print = false
local mode = "oops"

local function ReloadSettings()
  mode = settings.global["ltn-temp-stop-mode"].value
  remove_temporary_stops = mode == "remove-all"
  remove_temporary_directions = mode == "remove-direction-all"
  remove_temporary_directions_smart = mode == "remove-direction-smart"
  debug_print = settings.global["ltn-opts-debug-print"].value
  
end

local function ProcessSchedule(schedule)
  
  -- Scan schedule for rail_record stops.
  if schedule and schedule.records and #schedule.records>0 then
    local changed = false
    
    if remove_temporary_stops then
      -- Iterate backwards and delete all the temporary stops
      for i = #schedule.records, 1, -1 do
        if not schedule.records[i].station and schedule.records[i].rail then
          local rail = schedule.records[i].rail
          if debug_print then
            game.print("Removing temporary stop at rail ("..tostring(rail.position.x)..","..tostring(rail.position.y)..")")
          end
          table.remove(schedule.records,i)
          changed = true
        end
      end
      
    elseif remove_temporary_directions then
      -- Remove the direction flag from every temporary stop
      for i = 1, #schedule.records, 1 do
        if not schedule.records[i].station and schedule.records[i].rail and schedule.records[i].rail_direction then
          schedule.records[i].rail_direction = nil
          local rail = schedule.records[i].rail
          if debug_print then
            game.print("Removing direction of temporary stop at rail ("..tostring(rail.position.x)..","..tostring(rail.position.y)..")")
          end
          changed = true
        end
      end
    
    elseif remove_temporary_directions_smart then
      -- Remove the direction flag from every temporary stop IF there are TWO stops attached to this rail with the same name
      for i = 1, #schedule.records, 1 do
        if not schedule.records[i].station and schedule.records[i].rail and schedule.records[i].rail_direction then  -- found rail stop
          local rail = schedule.records[i].rail
          if i < #schedule.records and schedule.records[i+1].station then  -- followed by station
            local station = schedule.records[i+1].station
            -- find these stations nearby
            local stops = rail.surface.find_entities_filtered({type="train-stop", position=rail.position, radius=2})
            if stops then
              if debug_print then
                game.print("Found "..#stops.." stops near rail at ("..tostring(rail.position.x)..","..tostring(rail.position.y)..")")
              end
              if #stops == 2 and 
                stops[1].backer_name == station and stops[2].backer_name == station and 
                stops[1].connected_rail == rail and stops[2].connected_rail == rail then
                if debug_print then
                  game.print("Smart removing direction of temporary stop at station "..station)
                end
                schedule.records[i].rail_direction = nil
                changed = true
              end
            end
          end
        end
      end
    end
    
    if changed == true then
      return schedule
    end
    
  end
  
  return nil
end


-- Act on trains that were recently added to the LTN Dispatch list
function OnDispatcherUpdated(event)
  if event.deliveries and table_size(event.deliveries) > 0 then
    local last_tick = global.lastDispatchTick
    for train_id,delivery in pairs(event.deliveries) do
      if delivery.started >= last_tick then
        local schedule = ProcessSchedule(delivery.train.schedule)
        if schedule then
          delivery.train.schedule = schedule
        end
      end
    end
  end
  global.lastDispatchTick = game.tick
end


local function initGlobals()
  global.lastDispatchTick = global.lastDispatchTick or 0
end

local function registerEvents()
  script.on_event(remote.call("logistic-train-network", "on_dispatcher_updated"), OnDispatcherUpdated)
end

script.on_event(defines.events.on_runtime_mod_setting_changed, function()
  ReloadSettings()
end)

script.on_load(function()
  ReloadSettings()
  registerEvents()
  
end)

script.on_init(function()
  initGlobals()
  ReloadSettings()
  registerEvents()
end)

script.on_configuration_changed(function()
  initGlobals()
  ReloadSettings()
  registerEvents()
end)

