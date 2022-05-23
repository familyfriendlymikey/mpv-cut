utils = require "mp.utils"
pcall(require, "config")

if USE_GLOBAL_DIR == nil then USE_GLOBAL_DIR = true end
if GLOBAL_DIR == nil then GLOBAL_DIR = "~/Desktop" end
if USE_CUT_LIST == nil then USE_CUT_LIST = false end
if ACTIONS == nil then ACTIONS = { "COPY", "ENCODE" } end
if CHANNEL_NAMES == nil then CHANNEL_NAMES = {} end
if CHANNEL == nil then CHANNEL = 1 end

KEY_CUT = KEY_CUT or "c"
KEY_MAKE_CUTS = KEY_MAKE_CUTS or "0"
KEY_CYCLE_ACTION = KEY_CYCLE_ACTION or "a"
KEY_TOGGLE_USE_GLOBAL_DIR = KEY_TOGGLE_USE_GLOBAL_DIR or "g"
KEY_TOGGLE_USE_CUT_LIST = KEY_TOGGLE_USE_CUT_LIST or "l"
KEY_BOOKMARK_ADD = KEY_BOOKMARK_ADD or "i"
KEY_CHANNEL_INC = KEY_CHANNEL_INC or "="
KEY_CHANNEL_DEC = KEY_CHANNEL_DEC or "-"

GLOBAL_DIR = mp.command_native({"expand-path", GLOBAL_DIR})
ACTION = ACTIONS[1]
MAKE_CUTS_SCRIPT_PATH = utils.join_path(mp.get_script_directory(), "make_cuts")
START_TIME = nil

local function print(s)
	mp.msg.info(s)
	mp.osd_message(s)
end

text_overlay = mp.create_osd_overlay("ass-events")
text_overlay.hidden = true
text_overlay:update()

local function text_overlay_off()
	-- https://github.com/mpv-player/mpv/issues/10227
	text_overlay:update()
	text_overlay.hidden = true
	text_overlay:update()
end

local function get_current_channel_name()
	return CHANNEL_NAMES[CHANNEL] or CHANNEL
end

local function text_overlay_on()
	local channel = get_current_channel_name()
	if USE_CUT_LIST then
		text_overlay.data = string.format("LIST %s in %s from %s", ACTION, channel, START_TIME)
	else
		text_overlay.data = (USE_GLOBAL_DIR and "GLOBAL " or "")
			.. string.format("%s in %s from %s", ACTION, channel, START_TIME)
	end
	text_overlay.hidden = false
	text_overlay:update()
end

local function print_or_update_text_overlay(content)
	if START_TIME then text_overlay_on() else print(content) end
end

local function toggle_use_cut_list()
	USE_CUT_LIST = not USE_CUT_LIST
	print_or_update_text_overlay("USE CUT LIST: " .. tostring(USE_CUT_LIST))
end

local function toggle_use_global_dir()
	USE_GLOBAL_DIR = not USE_GLOBAL_DIR
	print_or_update_text_overlay("USE GLOBAL DIR: " .. tostring(USE_GLOBAL_DIR))
end

local function index_of(list, string)
	local index = 1
	while index < #list do
		if list[index] == string then return index end
		index = index + 1
	end
	return 0
end

local function cycle_action()
	ACTION = ACTIONS[index_of(ACTIONS, ACTION) + 1]
	print_or_update_text_overlay("ACTION: " .. ACTION)
end

local function get_file_info()
	local inpath = mp.get_property("path")
	local filename = mp.get_property("filename")
	local channel_name = get_current_channel_name()
	return inpath, filename, channel_name
end

local function get_bookmark_file_path()
	local inpath, filename, channel_name = get_file_info()
	local indir = utils.split_path(inpath)
	local outfile = string.format("%s_%s.book", channel_name, filename)
	return utils.join_path(indir, outfile)
end

local function bookmarks_load()
	local inpath, filename, channel_name = get_file_info()
	local inpath = get_bookmark_file_path()
	local file = io.open(inpath, "r")
	if not file then
		mp.set_property_native("chapter-list", {})
		return
	end
	local arr = {}
	for line in file:lines() do
		if tonumber(line) then
			table.insert(arr, {
				time = tonumber(line),
				title = "chapter_" .. line
			})
		end
	end
	file:close()
	table.sort(arr, function(a, b) return a.time < b.time end)
	mp.set_property_native("chapter-list", arr)
end

local function bookmark_add()
	local inpath, filename, channel_name = get_file_info()
	local outpath = get_bookmark_file_path()
	local file = io.open(outpath, "a")
	if not file then print("Failed to open bookmark file for writing") return end
	local out_string = mp.get_property_number("time-pos") .. "\n"
	local filesize = file:seek("end")
	file:write(out_string)
	local delta = file:seek("end") - filesize
	io.close(file)
	bookmarks_load()
	print(string.format("Δ %s, %s", delta, channel_name))
end

local function channel_inc()
	CHANNEL = CHANNEL + 1
	bookmarks_load()
	print_or_update_text_overlay(get_current_channel_name())
end

local function channel_dec()
	if CHANNEL >= 2 then CHANNEL = CHANNEL - 1 end
	bookmarks_load()
	print_or_update_text_overlay(get_current_channel_name())
end

local function print_async_result(success, result, error)
	print("Done")
end

local function make_cuts()
	local inpath, filename, channel_name = get_file_info()
	local indir = utils.split_path(inpath)
	local file = io.open(inpath .. ".list", "r")
	local args = { MAKE_CUTS_SCRIPT_PATH, indir }
	if USE_GLOBAL_DIR then table.insert(args, GLOBAL_DIR) end
	if file ~= nil then
		print("Making cuts")
		local json_string = file:read("*all")
		mp.command_native_async({
				name = "subprocess",
				playback_only = false,
				args = args,
				stdin_data = json_string
		}, print_async_result)
	else
		print("Failed to load cut list")
	end
end

local function make_cut(json_string)
	local inpath, filename, channel_name = get_file_info()
	local indir = utils.split_path(inpath)
	local args = { MAKE_CUTS_SCRIPT_PATH, indir }
	if USE_GLOBAL_DIR then table.insert(args, GLOBAL_DIR) end
	print("Making cut")
	mp.command_native_async({
			name = "subprocess",
			playback_only = false,
			args = args,
			stdin_data = json_string
	}, print_async_result)
end

local function write_cut_list(json_string)
		local inpath, filename, channel_name = get_file_info()
		local outpath = inpath .. ".list"
		local file = io.open(outpath, "a")
		if not file then print("Error writing to cut list") return end
		local filesize = file:seek("end")
		file:write(json_string)
		local delta = file:seek("end") - filesize
		io.close(file)
		print("Δ " .. delta)
end

local function cut(start_time, end_time)
	local inpath, filename, channel_name = get_file_info()
	local json_string = "{ "
		.. string.format("%q: %q", "filename", filename)
		.. string.format(", %q: %q", "action", ACTION)
		.. string.format(", %q: %q", "channel", channel_name)
		.. string.format(", %q: %q", "start_time", start_time)
		.. string.format(", %q: %q", "end_time", end_time)
		.. " }\n"
	if USE_CUT_LIST then
		write_cut_list(json_string)
	else
		make_cut(json_string)
	end
end

local function put_time()
	local time = mp.get_property_number("time-pos")
	if not START_TIME then
		START_TIME = time
		text_overlay_on()
		return
	end
	text_overlay_off()
	if time > START_TIME then
		cut(START_TIME, time)
		START_TIME = nil
	else
		print("INVALID")
		START_TIME = nil
	end
end

mp.add_key_binding(KEY_MAKE_CUTS, "make_cuts", make_cuts)
mp.add_key_binding(KEY_CUT, "cut", put_time)
mp.add_key_binding(KEY_BOOKMARK_ADD, "bookmark_add", bookmark_add)
mp.add_key_binding(KEY_CHANNEL_INC, "channel_inc", channel_inc)
mp.add_key_binding(KEY_CHANNEL_DEC, "channel_dec", channel_dec)
mp.add_key_binding(KEY_CYCLE_ACTION, "cycle_action", cycle_action)
mp.add_key_binding(KEY_TOGGLE_USE_GLOBAL_DIR, "toggle_use_global_dir", toggle_use_global_dir)
mp.add_key_binding(KEY_TOGGLE_USE_CUT_LIST, "toggle_use_cut_list", toggle_use_cut_list)
