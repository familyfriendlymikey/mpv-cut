# mpv-cut

This extension allows you to:

- Quickly cut videos both losslessly and re-encoded-ly.

- Specify custom actions in a `config.lua` file to support your own use cases
	without having to modify the script itself or write your own extension.

- Bookmark timestamps to a `.book` file and load them as chapters.

- Save cut information to a `.list` file for backup and make cuts later.

- Choose meaningful channel names to organize the aforementioned actions.

All directly in the fantastic media player [mpv](https://mpv.io/installation/).

## Requirements

Besides mpv, you must have `ffmpeg` in your PATH.

## Installation

#### Linux/MacOS

```
git clone -b release --single-branch "https://github.com/familyfriendlymikey/mpv-cut.git" ~/.config/mpv/scripts/mpv-cut
```

#### Windows

In
`%AppData%\Roaming\mpv\scripts` or `Users\user\scoop\persist\mpv\scripts` run:

```
git clone -b release --single-branch "https://github.com/familyfriendlymikey/mpv-cut.git"
```

That's all you have to do, next time you run mpv the script will be automatically loaded.

## Usage

### Cutting A Video Losslessly

- Press `c` to begin a cut.

- Seek to a later time in the video.

- Press `c` again to make the cut.

The resulting cut will be placed in the same directory as the source file.

You can press `C` to cancel a cut.

### Actions

You can press `a` to cycle between three default actions:

- Copy (lossless cut, rounds to keyframes).

- Encode (re-encoded cut, exact).

- List (simply add the timestamps for the cut to a `.list` file).

More details in [Custom Actions](#custom-actions).

### Bookmarking

Press `i` to append the current timestamp to a `.book` file. This
automatically reloads the timestamps as chapters in mpv. You can navigate
between these chapters with the default mpv bindings, `!` and `@`.

### Channels

The resulting cuts and bookmark files will be prefixed a channel number. This
is to help you categorize cuts and bookmarks. You can press `-` to decrement
the channel and `=` to increment the channel.

You can configure a name for each channel as shown in [config](#config).

### Utils

This plugin includes a `utils` script that you can source in your shell's
startup file. In my `~/.zshrc` I have this line:

```
source ~/.config/mpv/scripts/mpv-cut/utils
```

Now when you open new terminals, you'll have access to the functions inside of
the `utils` script, which are used as follows:

#### Making Cuts

The `make_cuts` function takes a `.list` file and ffmpeg output options except
for an output filename. To make cuts without reencoding:

```
make_cuts some_video.mp4.list -c copy
```

#### Concatenate, Merge, Combine, Join Cuts

The `concat` function takes a prefix and ffmpeg output options. Any file in the current directory
starting with the prefix will be included. For example, to concatenate all
files in the current directory whose filename starts with `CUT` without
reencoding:

```
concat CUT -c copy output.mp4
```

## Config

You can configure settings by creating a `config.lua` file in
`~/.config/mpv-cut` or in the same directory as `main.lua`.

You can include or omit any of the following:

```lua
-- Key config
KEY_CUT = "c"
KEY_CANCEL_CUT = "C"
KEY_CYCLE_ACTION = "a"
KEY_BOOKMARK_ADD = "i"
KEY_CHANNEL_INC = "="
KEY_CHANNEL_DEC = "-"

-- The list of channel names, you can choose whatever you want.
CHANNEL_NAMES[1] = "FUNNY"

-- The default channel
CHANNEL = 1

-- The default action
ACTION = "COPY"

-- Delete a default action
ACTIONS.LIST = nil
```

### Custom Actions

In the config file you can also specify custom actions. Even if you don't know
Lua, it should be pretty straightforward to take the following example and tune
it to your needs. I think this is a very powerful abstraction. All of the
default actions are implemented the same way you'd implement custom actions.

You can essentially define an arbitrary callback to run whenever an action is
invoked (the second time you press `c` in mpv). The callback function gets
passed a table with the following properties:

```
inpath, indir, infile, infile_noext, ext
channel
start_time, end_time, duration
start_time_hms, end_time_hms, duration_hms
```

Here is an example overwriting the default `ENCODE` action:

```lua
ACTIONS.ENCODE = function(d)
	local args = {
		"ffmpeg",
		"-nostdin", "-y",
		"-loglevel", "error",
		"-i", d.inpath,
		"-ss", d.start_time,
		"-t", d.duration,
		"-pix_fmt", "yuv420p",
		"-crf", "16",
		"-preset", "superfast",
		utils.join_path(d.indir, "ENCODE_" .. d.channel .. "_" .. d.infile_noext .. "_FROM_" .. d.start_time_hms .. "_TO_" .. d.end_time_hms .. d.ext)
	}
	mp.command_native_async({
		name = "subprocess",
		args = args,
		playback_only = false,
	}, function() print("Done") end)
end
```

## Optimized MPV Input Config

This is my `input.conf` file, and it is optimized for both normal playback and
quickly editing videos.

```
RIGHT seek 2 exact
LEFT seek -2 exact
UP seek 2 keyframes
DOWN seek -2 keyframes

] add speed 0.5
[ add speed -0.5
} add speed 0.25
{ add speed -0.25
\ set speed 1

BS script-binding osc/visibility

Alt+= add video-zoom 0.1
```

You may also want to change your key repeat delay and rate by tweaking
`input-ar-delay` and `input-ar-rate` to your liking in `mpv.conf`.

## FAQ

### What Is The Point Of A Cut List?

There are plenty of reasons, but to give some examples:

- In my opinion, video is extremely complex and tools around video can be
	unreliable. One video file may cause certain issues, and another may not,
	which makes writing an ffmpeg command that accounts for all scenarios
	difficult. If you spend a ton of time making many cuts in a long movie only
	to find that the colors look off because of some 10-bit h265 dolby mega
	surround whatever the fuck, with a cut list it's trivial to edit the ffmpeg
	command and re-make the cuts.

- Maybe you forget that the foreign language video you're cutting has softsubs
	rather than hardsubs, and you make a bunch of encode cuts resulting in cuts
	that have no subtitles.

- You might move the source video to somewhere else for storage but still want
	to have a back up of the cut timestamps in the event you need to remake the
	cuts from source quality.

### Why Would I Bookmark Instead Of Cutting?

Suppose you're watching a movie or show for your own enjoyment, but you also
want to compile funny moments to post online or send to your friends. It would
ruin your viewing experience to wait for a funny moment to be over in order to
make a cut. Instead, you can quickly make a bookmark whenever you laugh, and
once you're done watching you can go back and make actual cuts.

### Why Would I Re-Encode A Video?

- As mentioned above, copying the input stream is very fast and lossless but
	the cuts are not exact. Sometimes you want a cut to be exact.

- If you want to change the framerate.

- If you want to encode hardsubs.

- If the video's compression isn't efficient enough to upload to a messaging
	platform or something, you may want to compress it more.

### Can I Make Seeking And Reverse Playback Faster?

Depending on the encoding of the video file being played, the following may be
quite slow:

- The use of `exact` in `input.conf`.

- The use of the `.` and `,` keys to go frame by frame.

- The holding down of the `,` key to play the video in reverse.

Long story short, if the video uses an encoding that is difficult for mpv to
decode, exact seeking and backwards playback won't be smooth, which for normal
playback is not a problem at all, since by default mpv very quickly seeks
keyframe-wise when you press `left arrow` or `right arrow`.

However if we are very intensively cutting a video, it may be useful to be able
to quickly seek to an exact time, and to quickly play in reverse. In this case,
it is useful to first make a proxy of the original video which is very easy to
decode, generate a cut list with the proxy, and then apply the cut list to the
original video.

To create a proxy which will be very easy to decode, you can use this ffmpeg command:

```
ffmpeg -noautorotate -i input.mp4 -pix_fmt yuv420p -g 1 -sn -an -vf colormatrix=bt601:bt709,scale=w=1280:h=1280:force_original_aspect_ratio=decrease:force_divisible_by=2 -c:v libx264 -crf 16 -preset superfast -tune fastdecode proxy.mp4
```

The important options here are the `-g 1` and the scale filter. The other
options are more or less irrelevant. The resulting video file should seek
extremely quickly and play backwards just fine.

Once you are done generating the cut list, simply open the `cut_list.txt` file,
substitute the proxy file name for the original file name, and run `make_cuts`
on it.

### Why Is Lossless Cutting Called "Copy"?

This refers to ffmpeg's `-copy` flag which copies the input stream instead of
re-encoding it, meaning that the cut will process extremely quickly and the
resulting video will retain 100% of the original quality. The main drawback is
that the cut may have some extra video at the beginning and end, and as a
result of that there may be some slightly wonky behavior with video players and
editors.
