-- USER CONFIGURATION

local GLOBAL_DIR = "~/Desktop"

local GENERATE_LIST_ON_INPUT_DIR_CUT = true
local GENERATE_LIST_ON_GLOBAL_DIR_CUT = false

local OUTPUT_MP4 = true
local HARDSUBS = false

local ENCODE_CRF = 16
local ENCODE_PRESET = "superfast"

local KEY_TOGGLE_HARDSUBS = "h"
local KEY_TOGGLE_MP4 = "m"

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
	local filename_noext = mp.get_property("filename/no-ext")
	local ext = mp.get_property("filename"):match("^.+(%..+)$") or ".mp4"
	local output_dir = mp.command_native({"expand-path", GLOBAL_DIR})

	if OUTPUT_MP4 then
		ext = ".mp4"
	end

	if location == "input" then
		output_dir = utils.join_path(input_dir, "CUTS")
	end

	local prefix = action == "encode" and "ENCODE_" or "COPY_"
	local output_filename = prefix .. filename_noext .. "_FROM_" .. start_time .. "_TO_" .. end_time .. ext
	local cut_output_path = utils.join_path(output_dir, output_filename)
	local list_output_path = utils.join_path(output_dir, filename_noext .. ".txt")

	mp.msg.info("ACTION: " .. action)
	mp.msg.info("LOCATION: " .. location)
	mp.msg.info("INPUT PATH: " .. input_path)
	mp.msg.info("INPUT DIR: " .. input_dir)
	mp.msg.info("FILENAME: " .. filename_noext)
	mp.msg.info("EXT: " .. ext)
	mp.msg.info("OUTPUT DIR: " .. output_dir)
	mp.msg.info("CUT OUTPUT PATH: " .. cut_output_path)
	mp.msg.info("LIST OUTPUT PATH: " .. list_output_path)

	if action == "copy" or action == "encode" then
		mp.commandv("run", "mkdir", "-p", output_dir)
	end

	if action == "copy" then
		mp.commandv(
			"run",
			"ffmpeg", "-nostdin", "-y",
			"-ss", start_time,
			"-i", input_path,
			"-t", end_time - start_time,
			"-c", "copy",
			cut_output_path
		)
	elseif action == "encode" then
		if HARDSUBS then
			mp.commandv(
				"run",
				"ffmpeg", "-nostdin", "-y",
				"-ss", start_time,
				"-copyts",
				"-i", input_path,
				"-ss", start_time,
				"-vf", "subtitles=\'" .. input_path .. "\'",
				"-t", end_time - start_time,
				"-pix_fmt", "yuv420p",
				"-crf", ENCODE_CRF,
				"-preset", ENCODE_PRESET,
				cut_output_path
			)
		else
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
	end

	local generate_list = false
	if action == "list" then
		generate_list = true
	elseif location == "input" and GENERATE_LIST_ON_INPUT_DIR_CUT then
		generate_list = true
	elseif location == "global" and GENERATE_LIST_ON_GLOBAL_DIR_CUT then
		generate_list = true
	end

	if generate_list then
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
		text_overlay.data = tostring(time) .. "\nHARSUBS: " .. tostring(HARDSUBS) .. "\nOUTPUT_MP4: " .. tostring(OUTPUT_MP4)
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

local function toggle_hardsubs()
	mp.msg.info("HS")
	HARDSUBS = not HARDSUBS
	text_overlay.data = tostring(start_time) .. "\nHARSUBS: " .. tostring(HARDSUBS) .. "\nOUTPUT_MP4: " .. tostring(OUTPUT_MP4)
	text_overlay:update()
end

local function toggle_mp4()
	mp.msg.info("MP4")
	OUTPUT_MP4 = not OUTPUT_MP4
	text_overlay.data = tostring(start_time) .. "\nHARSUBS: " .. tostring(HARDSUBS) .. "\nOUTPUT_MP4: " .. tostring(OUTPUT_MP4)
	text_overlay:update()
end

mp.add_key_binding(KEY_INPUT_DIR_COPY, "input_copy", function() put_time("input", "copy") end)
mp.add_key_binding(KEY_INPUT_DIR_ENCODE, "input_encode", function() put_time("input", "encode") end)
mp.add_key_binding(KEY_INPUT_DIR_LIST, "input_list", function() put_time("input", "list") end)

mp.add_key_binding(KEY_GLOBAL_DIR_COPY, "global_copy", function() put_time("global", "copy") end)
mp.add_key_binding(KEY_GLOBAL_DIR_ENCODE, "global_encode", function() put_time("global", "encode") end)
mp.add_key_binding(KEY_GLOBAL_DIR_LIST, "global_list", function() put_time("global", "list") end)

mp.add_key_binding(KEY_TOGGLE_HARDSUBS, "toggle_hardsubs", toggle_hardsubs)
mp.add_key_binding(KEY_TOGGLE_MP4, "toggle_mp4", toggle_mp4)
