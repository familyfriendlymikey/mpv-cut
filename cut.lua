-- USER CONFIGURATION

local GLOBAL_DIR = "~/Desktop/CUTS"

local CUT_LIST_FILENAME = "cut_list.txt"
local GENERATE_LIST_ON_CUT = true

local ENCODE_CRF = 16
local ENCODE_PRESET = "superfast"

local KEY_INPUT_DIR_COPY = "c"
local KEY_INPUT_DIR_ENCODE = "e"
local KEY_INPUT_DIR_LIST = "l"

local KEY_GLOBAL_DIR_COPY = "C"
local KEY_GLOBAL_DIR_ENCODE = "E"
local KEY_GLOBAL_DIR_LIST = "L"

-- END USER CONFIGURATION

local utils = require "mp.utils"

local text_overlay = mp.create_osd_overlay("ass-events")
text_overlay.hidden = true
text_overlay:update()

local start_time = nil

local function cut(location, action, start_time, end_time)

	local input_path = mp.get_property("path")
	local input_dir = utils.split_path(input_path)
	local cut_output_dir = mp.command_native({"expand-path", GLOBAL_DIR})
	local list_output_dir = cut_output_dir

	if location == "input" then
		cut_output_dir = utils.join_path(input_dir, "CUTS")
		list_output_dir = input_dir
	end

	if action == "copy" or action == "encode" then
		mp.commandv("run", "mkdir", "-p", cut_output_dir)
	end

	if action == "list" or GENERATE_LIST_ON_CUT then
		mp.commandv("run", "mkdir", "-p", list_output_dir)
	end

	local prefix = action == "encode" and "ENCODE_" or "COPY_"
	local output_filename = prefix .. mp.get_property("filename/no-ext") .. "_FROM_" .. start_time .. "_TO_" .. end_time .. ".mkv"
	local cut_output_path = utils.join_path(cut_output_dir, output_filename)
	local list_output_path = utils.join_path(list_output_dir, CUT_LIST_FILENAME)

	mp.msg.info("ACTION: " .. action)
	mp.msg.info("LOCATION: " .. location)
	mp.msg.info("INPUT PATH: " .. input_path)
	mp.msg.info("INPUT DIR: " .. input_dir)
	mp.msg.info("CUT OUTPUT DIR: " .. cut_output_dir)
	mp.msg.info("CUT OUTPUT PATH: " .. cut_output_path)
	mp.msg.info("LIST OUTPUT DIR: " .. list_output_dir)
	mp.msg.info("LIST OUTPUT PATH: " .. list_output_path)

	if action == "copy" then
		mp.commandv(
			"run",
			"ffmpeg", "-nostdin", "-y",
			"-ss", start_time,
			"-to", end_time,
			"-i", input_path,
			"-c", "copy",
			"-avoid_negative_ts", "make_zero",
			cut_output_path
		)
	elseif action == "encode" then
		mp.commandv(
			"run",
			"ffmpeg", "-nostdin", "-y",
			"-ss", start_time,
			"-to", end_time,
			"-i", input_path,
			"-crf", ENCODE_CRF,
			"-preset", ENCODE_PRESET,
			cut_output_path
		)
	end
	if action == "list" or GENERATE_LIST_ON_CUT then
		local out_string = "\n" .. mp.get_property("filename") .. ": " .. start_time .. " " .. end_time
		local file = io.open(list_output_path, "a")
		file:write(out_string)
		io.close(file)
	end

	text_overlay.hidden = true
	text_overlay:update()
	mp.osd_message(cut_output_path, 0.5)

end

local function put_time(location, action)
	local time = mp.get_property_number("time-pos")

	if not start_time then
		text_overlay.hidden = false
		text_overlay.data = tostring(time)
		text_overlay:update()
		start_time = time
		return
	end

	if time > start_time then
		cut(location, action, start_time, time)
		start_time = nil
	else
		text_overlay.hidden = true
		text_overlay:update()
		mp.osd_message("INVALID")
		start_time = nil
	end

end

mp.add_key_binding(KEY_INPUT_DIR_COPY, "input_copy", function() put_time("input", "copy") end)
mp.add_key_binding(KEY_INPUT_DIR_ENCODE, "input_encode", function() put_time("input", "encode") end)
mp.add_key_binding(KEY_INPUT_DIR_LIST, "input_list", function() put_time("input", "list") end)

mp.add_key_binding(KEY_GLOBAL_DIR_COPY, "global_copy", function() put_time("global", "copy") end)
mp.add_key_binding(KEY_GLOBAL_DIR_ENCODE, "global_encode", function() put_time("global", "encode") end)
mp.add_key_binding(KEY_GLOBAL_DIR_LIST, "global_list", function() put_time("global", "list") end)
