let { readFileSync, statSync } = require 'fs'
let { spawnSync } = require 'child_process'
let path = require "path"

let p = console.log
let red = "\x1b[31m"
let plain = "\x1b[0m"
let green = "\x1b[32m"
let purple = "\x1b[34m"

p "IN MAKE_CUTS"

def quit s
	p "{red}{s}, quitting.{plain}\n"
	process.exit!

def is_dir s
	try
		return yes if statSync(s).isDirectory!
	catch
		return no

def parse_json data
	let failed = new Set!
	let succeeded = new Set!

	for line in data.split '\n'
		line = line.trim!
		continue if line.length < 1
		try
			JSON.parse line
			succeeded.add line
		catch
			failed.add line

	failed = [...failed]
	succeeded = [...succeeded]

	failed.length > 0 and p "\n{red}Failed to load JSON for lines:{plain} {failed}"
	succeeded.length > 0 and p "\n{green}Cut list:{plain} {succeeded}\n"

	succeeded.map! do |x| JSON.parse(x)

def to_hms secs
	[
		Math.floor secs / 3600
		Math.floor (secs % 3600) / 60
		Math.round((secs % 3600 % 60) * 1000) / 1000
	].map(do String($1).padStart(2,0)).join("-")

def main

	let argv = process.argv.slice(2)
	p "ARGS:"
	p argv
	let json = argv.pop!
	let indir
	let outdir
	switch argv.length
		when 0
			indir = outdir = "."
		when 1
			indir = outdir = argv.pop!
		when 2
			[indir, outdir] = argv
		else
			quit "Invalid args: {process.argv}"

	let cut_list = parse_json json
	quit "No valid cuts" if cut_list.length < 1

	quit "Input directory is invalid" if not is_dir indir
	quit "Output directory is invalid" if not is_dir outdir

	for cut, index in cut_list

		let { filename, action, channel, start_time, end_time } = cut
		let { name: filename_noext, ext } = path.parse(filename)
		let duration = parseFloat(end_time) - parseFloat(start_time)

		cut_name = "{action}_{channel}_{filename_noext}_FROM_{to_hms(start_time)}_TO_{to_hms(end_time)}{ext}"

		let inpath = path.join(indir, filename)
		let outpath = path.join(outdir, cut_name)

		let cmd = "ffmpeg"
		let args = [
			"-nostdin", "-y"
			"-loglevel", "error"
			"-ss", start_time
			"-t", duration
			"-i", inpath
			"-pix_fmt", "yuv420p"
		]

		if action == "ENCODE"
			args.push(
				"-crf", "16"
				"-preset", "superfast"
			)
		else
			args.push(
				"-c", "copy"
				"-avoid_negative_ts", "make_zero"
			)

		args.push(outpath)

		let progress = "({index + 1}/{cut_list.length})"
		let cmd_str = "{cmd} {args.join(" ")}"

		p "{green}{progress}{plain} {inpath} {green}->{plain}"
		p "{outpath}\n"
		p "{purple}{cmd_str}{plain}\n"

		spawnSync cmd, args, { stdio: 'inherit' }

	p "Done.\n"

main!
