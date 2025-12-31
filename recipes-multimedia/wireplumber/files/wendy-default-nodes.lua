-- WendyOS Bluetooth default node switching
-- Prefer Bluetooth audio devices on connect and allow default restoration on disconnect.

log = Log.open_topic ("s-wendy-default-nodes")

local function is_bluetooth_node (props)
  if not props then
    return false
  end

  local api = props ["device.api"]
  if api == "bluez5" or api == "bluez" then
    return true
  end

  local node_name = props ["node.name"]
  if node_name and node_name:match ("^bluez_") then
    return true
  end

  local device_name = props ["device.name"]
  if device_name and device_name:match ("^bluez_") then
    return true
  end

  return false
end

local function parse_metadata_name (value)
  if not value then
    return nil
  end

  local ok, parsed = pcall (function ()
    return Json.Raw (value):parse ()
  end)
  if not ok or not parsed then
    return nil
  end

  return parsed.name
end

local function get_metadata_name (metadata, key)
  local obj = metadata:find (0, key)
  if not obj then
    return nil
  end

  return parse_metadata_name (obj)
end

local function set_metadata_name (metadata, key, name)
  if name and name ~= "" then
    metadata:set (0, key, "Spa:String:JSON",
        Json.Object { ["name"] = name }:to_string ())
  else
    metadata:set (0, key, nil, nil)
  end
end

local function ensure_configured_seed (metadata, def_type)
  local configured_key = "default.configured." .. def_type
  local configured = get_metadata_name (metadata, configured_key)
  if configured then
    return configured
  end

  local current_default = get_metadata_name (metadata, "default." .. def_type)
  if current_default then
    set_metadata_name (metadata, configured_key, current_default)
  end

  return current_default
end

local function default_types_for_media_class (media_class)
  if not media_class then
    return nil
  end

  if media_class == "Audio/Duplex" then
    return { "audio.sink", "audio.source" }
  end

  local types = {}
  if media_class:find ("Sink") then
    table.insert (types, "audio.sink")
  end
  if media_class:find ("Source") then
    table.insert (types, "audio.source")
  end

  if #types == 0 then
    return nil
  end

  return types
end

local function handle_bluetooth_linkable_added (event)
  local si = event:get_subject ()
  if not si then
    return
  end

  local node = si:get_associated_proxy ("node")
  if not node then
    return
  end

  local props = node.properties
  if not props or not is_bluetooth_node (props) then
    return
  end

  local media_class = props ["media.class"]
  if not media_class or not media_class:match ("^Audio/") then
    return
  end

  local types = default_types_for_media_class (media_class)
  if not types then
    return
  end

  local node_name = props ["node.name"]
  if not node_name or node_name == "" then
    return
  end

  local source = event:get_source ()
  local metadata_om = source:call ("get-object-manager", "metadata")
  if not metadata_om then
    return
  end

  local metadata = metadata_om:lookup {
    Constraint { "metadata.name", "=", "default" },
  }
  if not metadata then
    return
  end

  for _, def_type in ipairs (types) do
    ensure_configured_seed (metadata, def_type)

    local configured_key = "default.configured." .. def_type
    local configured = get_metadata_name (metadata, configured_key)
    if configured ~= node_name then
      log:info ("Switching " .. configured_key .. " to " .. node_name)
      set_metadata_name (metadata, configured_key, node_name)
    end
  end
end

SimpleEventHook {
  name = "wendy-default-nodes/bluetooth-added",
  before = "default-nodes/rescan-trigger",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "session-item-added" },
      Constraint { "event.session-item.interface", "=", "linkable" },
      Constraint { "media.class", "#", "Audio/*" },
    },
  },
  execute = handle_bluetooth_linkable_added
}:register ()
