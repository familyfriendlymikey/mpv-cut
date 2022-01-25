-- USER CONFIGURATION

local GLOBAL_DIR = "~/Desktop"

local ACTION = "copy"
local GENERATE_LIST = true
local USE_GLOBAL_DIR = false
local OUTPUT_MP4 = true
local HARDSUBS = false

local ENCODE_CRF = 16
local ENCODE_PRESET = "superfast"

local KEY_CUT = "c"
local KEY_TOGGLE_ACTION = "a"
local KEY_TOGGLE_GENERATE_LIST = "l"
local KEY_TOGGLE_HARDSUBS = "h"
local KEY_TOGGLE_MP4 = "m"
local KEY_TOGGLE_USE_GLOBAL_DIR = "g"

-- END USER CONFIGURATION

local utils = require "mp.utils"

local text_overlay = mp.create_osd_overlay("ass-events")
text_overlay.hidden = true
text_overlay:update()

local start_time = nil

local function cut(start_time, end_time)

	local input_path = mp.get_property("path")
	local input_dir = utils.split_path(input_path)
	local filename_noext = mp.get_property("filename/no-ext")
	local ext = mp.get_property("filename"):match("^.+(%..+)$") or ".mp4"
	local output_dir = mp.command_native({"expand-path", GLOBAL_DIR})

	if OUTPUT_MP4 then
		ext = ".mp4"
	end

	if not USE_GLOBAL_DIR then
		output_dir = utils.join_path(input_dir, "CUTS")
	end

	local prefix = ACTION == "encode" and "ENCODE_" or "COPY_"
	local output_filename = prefix .. filename_noext .. "_FROM_" .. start_time .. "_TO_" .. end_time .. ext
	local cut_output_path = utils.join_path(output_dir, output_filename)
	local list_output_path = utils.join_path(output_dir, filename_noext .. ".txt")

	mp.msg.info("ACTION: " .. ACTION)
	mp.msg.info("INPUT PATH: " .. input_path)
	mp.msg.info("INPUT DIR: " .. input_dir)
	mp.msg.info("FILENAME: " .. filename_noext)
	mp.msg.info("EXT: " .. ext)
	mp.msg.info("OUTPUT DIR: " .. output_dir)
	mp.msg.info("CUT OUTPUT PATH: " .. cut_output_path)
	mp.msg.info("LIST OUTPUT PATH: " .. list_output_path)

	mp.commandv("run", "mkdir", "-p", output_dir)

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

	if ACTION == "list" or GENERATE_LIST then
		local out_string = "\n" .. mp.get_property("filename") .. ": " .. start_time .. " " .. end_time
		local file = io.open(list_output_path, "a")
		file:write(out_string)
		io.close(file)
	end

	text_overlay.hidden = true
	text_overlay:update()
	mp.osd_message(cut_output_path, 0.5)

end

local function refresh_osd()
	text_overlay.data =
		tostring(start_time)
		.. "\nACTION <" .. KEY_TOGGLE_ACTION .. ">: " .. ACTION
		.. "\nUSE GLOBAL DIR <" .. KEY_TOGGLE_USE_GLOBAL_DIR .. ">: " .. tostring(USE_GLOBAL_DIR)

	if ACTION == "copy" or ACTION == "encode" then
		text_overlay.data = text_overlay.data
			.. "\nGENERATE LIST <" .. KEY_TOGGLE_GENERATE_LIST .. ">: " .. tostring(GENERATE_LIST)
			.. "\nOUTPUT MP4 <" .. KEY_TOGGLE_MP4 .. ">: " .. tostring(OUTPUT_MP4)
	end

	if ACTION == "encode" then
		text_overlay.data = text_overlay.data
			.. "\nHARSUBS <" .. KEY_TOGGLE_HARDSUBS .. ">: " .. tostring(HARDSUBS)
	end

	text_overlay.hidden = false
	text_overlay:update()
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

local function toggle_hardsubs()
	HARDSUBS = not HARDSUBS
	refresh_osd()
end

local function toggle_mp4()
	OUTPUT_MP4 = not OUTPUT_MP4
	refresh_osd()
end

local function toggle_generate_list()
	GENERATE_LIST = not GENERATE_LIST
	refresh_osd()
end

local function toggle_use_global_dir()
	USE_GLOBAL_DIR = not USE_GLOBAL_DIR
	refresh_osd()
end

local function toggle_action()
	if ACTION == "copy" then
		ACTION = "encode"
	elseif ACTION == "encode" then
		ACTION = "list"
	else
		ACTION = "copy"
	end
	refresh_osd()
end

mp.add_key_binding(KEY_CUT, "cut", put_time)
mp.add_key_binding(KEY_TOGGLE_HARDSUBS, "toggle_hardsubs", toggle_hardsubs)
mp.add_key_binding(KEY_TOGGLE_MP4, "toggle_mp4", toggle_mp4)
mp.add_key_binding(KEY_TOGGLE_GENERATE_LIST, "toggle_generate_list", toggle_generate_list)
mp.add_key_binding(KEY_TOGGLE_ACTION, "toggle_action", toggle_action)
mp.add_key_binding(KEY_TOGGLE_USE_GLOBAL_DIR, "toggle_use_global_dir", toggle_use_global_dir)
