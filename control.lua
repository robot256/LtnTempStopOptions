


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


local function AreConnected(a, b)
  return (a.get_circuit_network(defines.wire_type.red) and b.get_circuit_network(defines.wire_type.red) and 
           (a.get_circuit_network(defines.wire_type.red).network_id == b.get_circuit_network(defines.wire_type.red).network_id)
         ) or
         (a.get_circuit_network(defines.wire_type.green) and b.get_circuit_network(defines.wire_type.green) and 
           (a.get_circuit_network(defines.wire_type.green).network_id == b.get_circuit_network(defines.wire_type.green).network_id)
         )
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
      -- Check if there is a train stop at the other end of this LTN stops' rail segment that is wired to the LTN stop
      for i = 1, #schedule.records, 1 do
        if not schedule.records[i].station and schedule.records[i].rail and schedule.records[i].rail_direction then  -- found rail stop
          if i < #schedule.records and schedule.records[i+1].station then  -- followed by station
            local rail = schedule.records[i].rail
            local front_entity = rail.get_rail_segment_entity(defines.rail_direction.front, false)
            local back_entity = rail.get_rail_segment_entity(defines.rail_direction.back, false)
            if front_entity and front_entity.type == "train-stop" and back_entity and back_entity.type == "train-stop" and AreConnected(front_entity, back_entity) then
              -- block is bounded by train stops
              local station = schedule.records[i+1].station
              local waypoint_rail = nil
              if (front_entity.name == "logistic-train-stop" and front_entity.backer_name == station) then
                waypoint_rail = back_entity.connected_rail
              elseif (back_entity.name == "logistic-train-stop" and back_entity.backer_name == station) then
                waypoint_rail = front_entity.connected_rail
              end
              if waypoint_rail then
                schedule.records[i].rail = waypoint_rail
                schedule.records[i].rail_direction = nil
                if debug_print then
                  game.print("Moved waypoint to new location ("..tostring(waypoint_rail.position.x)..","..tostring(waypoint_rail.position.y)..")")
                end
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

function OnStopsUpdated(event)
  if event.logistic_train_stops then
    global.LogisticTrainStops = event.logistic_train_stops
  end
end


local function initGlobals()
  global.lastDispatchTick = global.lastDispatchTick or 0
  global.LogisticTrainStops = global.LogisticTrainStops or {}
end

local function registerEvents()
  script.on_event(remote.call("logistic-train-network", "on_dispatcher_updated"), OnDispatcherUpdated)
  script.on_event(remote.call("logistic-train-network", "on_stops_updated"), OnStopsUpdated)
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

