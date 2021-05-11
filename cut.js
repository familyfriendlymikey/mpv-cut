var start_time = null

function put_time() {
	var time = mp.get_property_number("time-pos")
	if (!start_time) {
		mp.osd_message("START ENCODE")
		start_time = time
	} else {
		if(time > start_time){
			cut(start_time, time)
			start_time = null
		} else {
			mp.osd_message("END TIME INVALID")
			start_time = null
		}
	}
}

function cut(start_time, end_time) {
	var input_dir = mp.get_property("working-directory")
	var input_file = mp.get_property("filename")
	var input_file_noext = mp.get_property("filename/no-ext")
	var input_path = input_dir + "/" + input_file

	var output_file = input_file_noext + "_" + (start_time|0) + "_TO_" + (end_time|0) + ".mkv"
	var output_path = input_dir + "/" + output_file

	mp.osd_message("END ENCODE\n" + output_path, 5)

	mp.commandv(
		"run",
		"ffmpeg", "-nostdin",
		"-loglevel", "error",
		"-ss", start_time,
		"-to", end_time,
		"-i", input_path,
		"-c", "copy",
		"-avoid_negative_ts", "make_zero",
		output_path
	)
}

mp.add_key_binding("c", "put_time", put_time)
