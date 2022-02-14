-- USER CONFIGURATION

local GLOBAL_DIR = "~/Desktop"

local ACTION = "copy"
local GENERATE_LIST = true
local USE_GLOBAL_DIR = false

local ENCODE_CRF = 16
local ENCODE_PRESET = "superfast"

local DEFAULT_CHANNEL = 0

local CHANNEL_NAMES = {}
CHANNEL_NAMES[0] = "FILE"
CHANNEL_NAMES[1] = "FUNNY"

local KEY_CUT = "c"
local KEY_TOGGLE_ACTION = "a"
local KEY_TOGGLE_USE_GLOBAL_DIR = "g"

local KEY_IM_MARK = "i"
local KEY_IM_LOAD = "o"

local KEY_CHANNEL_INC = "="
local KEY_CHANNEL_DEC = "-"

local KEY_CHANNEL_SET_0 = "0"
local KEY_CHANNEL_SET_1 = "1"
local KEY_CHANNEL_SET_2 = "2"
local KEY_CHANNEL_SET_3 = "3"
local KEY_CHANNEL_SET_4 = "4"
local KEY_CHANNEL_SET_5 = "5"
local KEY_CHANNEL_SET_6 = "6"
local KEY_CHANNEL_SET_7 = "7"
local KEY_CHANNEL_SET_8 = "8"
local KEY_CHANNEL_SET_9 = "9"

-- END USER CONFIGURATION

local channel = DEFAULT_CHANNEL >= 0 and DEFAULT_CHANNEL or 0

local utils = require "mp.utils"

local text_overlay = mp.create_osd_overlay("ass-events")
text_overlay.hidden = true
text_overlay:update()

local start_time = nil

local function refresh_osd()
	text_overlay.data =
		tostring(start_time)
		.. "\nCHANNEL: " .. (CHANNEL_NAMES[channel] or channel)
		.. "\nACTION <" .. KEY_TOGGLE_ACTION .. ">: " .. ACTION
		.. "\nUSE GLOBAL DIR <" .. KEY_TOGGLE_USE_GLOBAL_DIR .. ">: " .. tostring(USE_GLOBAL_DIR)

	text_overlay.hidden = false
	text_overlay:update()
end

local function _print(content)
	if start_time then
		refresh_osd()
	else
		mp.osd_message(content)
	end
end

local function cut(start_time, end_time)

	local input_path = mp.get_property("path")
	local input_dir = utils.split_path(input_path)
	local filename_noext = mp.get_property("filename/no-ext")
	local ext = mp.get_property("filename"):match("^.+(%..+)$") or ".mp4"
	local output_dir = mp.command_native({"expand-path", GLOBAL_DIR})

	if not USE_GLOBAL_DIR then
		output_dir = utils.join_path(input_dir, "CUTS")
	end

	local channel_name = CHANNEL_NAMES[channel] or channel
	local prefix = ACTION == "encode" and "ENCODE_" or "COPY_"
	prefix = prefix .. channel_name .. "_"
	local output_filename = prefix .. filename_noext .. "_FROM_" .. start_time .. "_TO_" .. end_time .. ext
	local cut_output_path = utils.join_path(output_dir, output_filename)
	local list_output_path = utils.join_path(input_dir, "LIST_" .. channel_name .. "_" .. filename_noext .. ".txt")

	mp.msg.info("ACTION: " .. ACTION)
	mp.msg.info("INPUT PATH: " .. input_path)
	mp.msg.info("INPUT DIR: " .. input_dir)
	mp.msg.info("FILENAME: " .. filename_noext)
	mp.msg.info("EXT: " .. ext)
	mp.msg.info("OUTPUT DIR: " .. output_dir)
	mp.msg.info("CUT OUTPUT PATH: " .. cut_output_path)
	mp.msg.info("LIST OUTPUT PATH: " .. list_output_path)

	if ACTION == "copy" or ACTION == "encode" then
		mp.commandv("run", "mkdir", "-p", output_dir)
	end

	if ACTION == "copy" then
		mp.commandv(
			"run",
			"ffmpeg", "-nostdin", "-y",
			"-ss", start_time,
			"-i", input_path,
			"-t", end_time - start_time,
			"-c", "copy",
			cut_output_path
		)
	elseif ACTION == "encode" then
		mp.commandv(
			"run",
			"ffmpeg", "-nostdin", "-y",
			"-ss", start_time,
			"-i", input_path,
			"-t", end_time - start_time,
			"-pix_fmt", "yuv420p",
			"-crf", ENCODE_CRF,
			"-preset", ENCODE_PRESET,
			cut_output_path
		)
	end

	local before = 0
	local after = 0

	if ACTION == "list" or GENERATE_LIST then
		local out_string = "\n" .. mp.get_property("filename") .. ": " .. start_time .. " " .. end_time
		local file = io.open(list_output_path, "a")

		mp.msg.info(list_output_path)
		mp.msg.info(file)

		before = file:seek("end")
		file:write(out_string)
		after = file:seek("end")

		mp.msg.info(before .. " -> " .. after)

		io.close(file)
	end

	text_overlay.hidden = true
	text_overlay:update()
	mp.osd_message("Δ" .. after - before .. ", " .. cut_output_path, 2)

end

local function put_time()
	local time = mp.get_property_number("time-pos")

	if not start_time then
		start_time = time
		refresh_osd()
		return
	end

	if time > start_time then
		cut(start_time, time)
		start_time = nil
	else
		text_overlay.hidden = true
		text_overlay:update()
		mp.osd_message("INVALID")
		start_time = nil
	end

end

local function toggle_use_global_dir()
	USE_GLOBAL_DIR = not USE_GLOBAL_DIR
	_print("USE GLOBAL DIR: " .. tostring(USE_GLOBAL_DIR))
end

local function toggle_action()
	if ACTION == "copy" then
		ACTION = "encode"
	elseif ACTION == "encode" then
		ACTION = "list"
	else
		ACTION = "copy"
	end
	_print("ACTION: " .. ACTION)
end

local function im_load()
	local input_path = mp.get_property("path")
	local input_dir = utils.split_path(input_path)
	local filename = mp.get_property("filename")
	local filename_noext = mp.get_property("filename/no-ext")

	local channel_name = CHANNEL_NAMES[channel] or channel
	local prefix = "IM_" .. channel_name .. "_"

	local im_file = io.open(utils.join_path(input_dir, prefix .. filename_noext .. ".txt"), "r")
	if not im_file then return end
	local arr = {}
	for line in im_file:lines() do
		if tonumber(line) then
			table.insert(arr, {
				time = tonumber(line),
				title = "chapter_" .. line
			})
		end
	end
	im_file:close()
	table.sort(arr, function(a, b) return a.time < b.time end)

	mp.set_property_native("chapter-list", arr)
end

local function im_mark()

	local input_path = mp.get_property("path")
	local input_dir = utils.split_path(input_path)
	local filename = mp.get_property("filename")
	local filename_noext = mp.get_property("filename/no-ext")
	local channel_name = CHANNEL_NAMES[channel] or channel
	local prefix = "IM_" .. channel_name .. "_"

	local output_path = utils.join_path(input_dir, prefix .. filename_noext .. ".txt")
	local out_string = "\n" .. mp.get_property_number("time-pos")

	local file = io.open(output_path, "a")
	local before = file:seek("end")
	file:write(out_string)
	local after = file:seek("end")
	io.close(file)

	im_load()

	mp.msg.info(before .. " -> " .. after)
	mp.osd_message(channel_name .. " Δ " .. after - before, 1)

end

local function channel_inc()
	channel = channel + 1
	im_load()
	_print(CHANNEL_NAMES[channel] or channel)
end

local function channel_dec()
	if channel > 0 then
		channel = channel - 1
	end
	im_load()
	_print(CHANNEL_NAMES[channel] or channel)
end

local function channel_set(digit)
	channel = digit
	im_load()
	_print(CHANNEL_NAMES[channel] or channel)
end

mp.add_key_binding(KEY_CUT, "cut", put_time)
mp.add_key_binding(KEY_TOGGLE_ACTION, "toggle_action", toggle_action)
mp.add_key_binding(KEY_TOGGLE_USE_GLOBAL_DIR, "toggle_use_global_dir", toggle_use_global_dir)

mp.add_key_binding(KEY_IM_MARK, "im_mark", im_mark)
mp.add_key_binding(KEY_IM_LOAD, "im_load", im_load)

mp.add_key_binding(KEY_CHANNEL_INC, "channel_inc", channel_inc)
mp.add_key_binding(KEY_CHANNEL_DEC, "channel_dec", channel_dec)

mp.add_key_binding(KEY_CHANNEL_SET_0, "channel_set_0", function() channel_set(0) end)
mp.add_key_binding(KEY_CHANNEL_SET_1, "channel_set_1", function() channel_set(1) end)
mp.add_key_binding(KEY_CHANNEL_SET_2, "channel_set_2", function() channel_set(2) end)
mp.add_key_binding(KEY_CHANNEL_SET_3, "channel_set_3", function() channel_set(3) end)
mp.add_key_binding(KEY_CHANNEL_SET_4, "channel_set_4", function() channel_set(4) end)
mp.add_key_binding(KEY_CHANNEL_SET_5, "channel_set_5", function() channel_set(5) end)
mp.add_key_binding(KEY_CHANNEL_SET_6, "channel_set_6", function() channel_set(6) end)
mp.add_key_binding(KEY_CHANNEL_SET_7, "channel_set_7", function() channel_set(7) end)
mp.add_key_binding(KEY_CHANNEL_SET_8, "channel_set_8", function() channel_set(8) end)
mp.add_key_binding(KEY_CHANNEL_SET_9, "channel_set_9", function() channel_set(9) end)
