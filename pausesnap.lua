-- PauseSnap - Auto screenshot on pause
-- Created because I got tired of manually taking screenshots every time I paused!

local mp = require 'mp'
local utils = require 'mp.utils'
--local os = require 'os'
local options = require 'mp.options'

--[[ 
Configuration options - these get loaded from script-opts/pausesnap.conf 
Took me ages to debug this path thing, but utils.join_path finally works properly
]]--
local opts = {
    enabled = "true",
    toggle_key = "Ctrl+'",
    osd_color = "f4c504",
    screenshot_method = "subtitles",
    screenshot_dir = "",
    screenshot_template = "%{filename/no-ext:untitled}-%p"
}


options.read_options(opts, 'pausesnap')


local function string_to_bool(str)
    if type(str) == "boolean" then
        return str
    end
    local s = tostring(str):lower():gsub("%s+", "")
    return s == "true" or s == "yes" or s == "1" or s == "on"
end


local is_enabled = string_to_bool(opts.enabled)
local original_screenshot_dir = nil
local original_screenshot_template = nil

--converting hex to ASS
local function hex_to_ass_color(hex_color)
    
    hex_color = hex_color:gsub("^#", "")
    
    if not hex_color:match("^%x%x%x%x%x%x$") then
        mp.msg.warn("Invalid hex color '" .. hex_color .. "', falling back to white")
        return "FFFFFF"  -- White fallback
    end
    
    -- Convert RGB to BGR for ASS
    local r = hex_color:sub(1, 2)
    local g = hex_color:sub(3, 4) 
    local b = hex_color:sub(5, 6)
    
    return b .. g .. r  -- BGR format for ASS
end

local function validate_screenshot_dir(dir)
    if not dir or dir == "" then
        return nil  
    end
    
    -- (mp.utils.file_info returns nil if not found)
    local info = utils.file_info(dir)
    if not info or not info.is_dir then
        mp.msg.warn("Screenshot directory '" .. dir .. "' doesn't exist or isn't accessible, using MPV default")
        return nil
    end
    
    return dir
end


local function show_osd_message(text, duration)
    duration = duration or 2000

    local ass_color = hex_to_ass_color(opts.osd_color)
    local ass_text = string.format("{\\an8\\1a&H00&\\b1\\bord1\\shad0\\1c&H%s&}%s", ass_color, text) 

    mp.set_osd_ass(1280, 720, ass_text)  -- (1280x720)

    mp.add_timeout(duration / 1000, function()
        mp.set_osd_ass(1280, 720, "")  
    end)
end


local function setup_screenshot_settings()

    if not original_screenshot_dir then
        original_screenshot_dir = mp.get_property("screenshot-directory") or ""
    end
    if not original_screenshot_template then
        original_screenshot_template = mp.get_property("screenshot-template") or ""
    end
    

    local custom_dir = validate_screenshot_dir(opts.screenshot_dir)
    if custom_dir then
        mp.set_property("screenshot-directory", custom_dir)
    end
    
    if opts.screenshot_template and opts.screenshot_template ~= "" then
        mp.set_property("screenshot-template", opts.screenshot_template)
    end
end

local function restore_screenshot_settings()
    if original_screenshot_dir then
        mp.set_property("screenshot-directory", original_screenshot_dir)
    end
    if original_screenshot_template then
        mp.set_property("screenshot-template", original_screenshot_template)
    end
end

-- Main function
local function take_screenshot()
    if not is_enabled then
        return  -- Disabled, do nothing
    end
    

    local method = opts.screenshot_method
    if method ~= "subtitles" and method ~= "video" and method ~= "window" then
        mp.msg.warn("Invalid screenshot method '" .. method .. "', using 'subtitles'")
        method = "subtitles"
    end
    
    setup_screenshot_settings()
    mp.commandv("screenshot", method)
    show_osd_message("PauseSnap: Screenshot taken!", 1500)
    restore_screenshot_settings()
end


local function on_pause_change(name, paused)
    mp.msg.debug("Pause state changed to: " .. tostring(paused))
    
    if paused and is_enabled and mp.get_property("duration") then
        mp.msg.debug("Taking screenshot due to pause")
        take_screenshot()  
    end
end

local function toggle_pausesnap()
    is_enabled = not is_enabled
    
    local status = is_enabled and "enabled" or "disabled"
    show_osd_message("PauseSnap: " .. status, 2000)
    
    mp.msg.info("PauseSnap " .. status)
end

-- Initialize the script
local function init_pausesnap()

    original_screenshot_dir = mp.get_property("screenshot-directory") or ""
    original_screenshot_template = mp.get_property("screenshot-template") or ""
    

    mp.observe_property("pause", "bool", on_pause_change)
    

    mp.add_key_binding(opts.toggle_key, "toggle-pausesnap", toggle_pausesnap)
    
    mp.msg.info("PauseSnap loaded - " .. (is_enabled and "enabled" or "disabled"))
    mp.msg.info("Toggle with: " .. opts.toggle_key)
    


	--    Extra debug info (remove this comment block if you want less spam in logs)
    mp.msg.debug("Screenshot method: " .. opts.screenshot_method)
    mp.msg.debug("OSD color: " .. opts.osd_color)
    if opts.screenshot_dir ~= "" then
        mp.msg.debug("Custom directory: " .. opts.screenshot_dir)
    end
    if opts.screenshot_template ~= "" then
        mp.msg.debug("Custom template: " .. opts.screenshot_template)
    end
end

init_pausesnap()
