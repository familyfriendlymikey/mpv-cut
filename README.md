# mpv-cut
Instantly cut videos directly inside of the fantastic media player [mpv](https://mpv.io/installation/), losslessly with ffmpeg.

Optionally record the timestamps of cuts in a backup text file `cut_list.txt` to be processed later by the python script `make_cuts`.

Requires `ffmpeg` in your path.

## Installation
Place `cut.lua` into the specified directories:

#### Linux/MacOS
```
~/.config/mpv/scripts/
```

#### Windows
```
C:\Users\user\AppData\Roaming\mpv\scripts\
```

That's all you have to do, next time you run `mpv` the script will be automatically loaded.

If you intend to use `make_cuts`, the fastest workflow would be:
- Add a custom folder to your PATH such as `~/bin`.
- Place the `make_cuts` script in that folder.
- Run it anywhere with bash simply by running the command `make_cuts`.

## Usage

You have 3 options with this script:

### Copy
- Press `c` to begin a cut.
- Seek to a later time in the video.
- Press `c` again to make a copy cut.
- The resulting video file will be placed in a `CUTS` folder next to the source file.
- To place in a global custom directory instead (`~/Desktop/cuts`), use capital `C` on the final cut.

It does not matter what hotkey you pressed for the first cut.
This applies to other options as well, not just copy.

This cuts the video copying the input stream.
For laymen, this just means that the video won't be re-encoded,
so the cut will be lossless,
meaning it retains 100% of the original quality,
and it is almost instantaneous to cut.
The main drawback is that the cut may have some extra video at the beginning and end.

### Encode
- This uses the hotkeys `e` and `E` in the same manner as `copy`.

Encode does the same thing as `copy` but with re-encoding, so the cuts will be nearly frame perfect,
but it may take some time and processing power depending on the source footage.
For convenience, I put two variables at the top of `cut.lua` which you can modify to your liking:
```
local ENCODE_CRF = 16
local ENCODE_PRESET = "superfast"
```
The `CRF` is the quality, with lower being better, and `18` being agreed upon as somewhat perceptually lossless.
The `preset` is the speed, with faster presets resulting in larger files or potentially worse quality.
If you want to re-encode cuts but want them to be very effeciently compressed,
it probably makes more sense to use the `list` option which I will explain now.

### List
- This uses the hotkeys `l` and `L` in the same manner as `copy`.

This does not actually cut any videos,
it just records the cuts in a human readable text file which is by default named `cut_list.txt`.
The accompanying `make_cuts` script accepts a filepath as argument or defaults to `cut_list.txt` in the current directory.
If the path exists, it generates a `make_cuts.sh` file which runs ffmpeg for each cut.
This way, you can remove any cuts you don't want from the temporary file `make_cuts.sh`,
without tampering with your `cut_list.txt` file.

The purpose of this `list` option is to have a backup file listing all of the cuts you have made,
so if you ever delete source footage for storage or something,
you will still be able to recover all your hard work.

## Config
For convenience I provided several configuration variables at the top of `cut.lua`,
most of which are probably self explanatory with the exception of `GENERATE_LIST_ON_CUT`.
All this option does is additionally generate `cut_list.txt` when you make a cut with `copy` or `encode`.
If you don't want that functionality, just set it to false.

```lua
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
```

## Concatenation
If you want to concatenate cuts into one video, you can do that with ffmpeg.
To concatenate videos in ffmpeg, you need to create a file with content like this:
```
file 'video1.mp4'
file 'video2.mp4'
file 'video3.mp4'
file 'video4.mp4'
```
And then run the command
```
ffmpeg -f concat -safe 0 -i concat.txt -c copy out.mp4
```
You can name the file whatever you want, here I named it `concat.txt`.

Creating this file is trivial with bash
```
for f in CUTS/*; do echo "file '$f'" >> concat.txt; done
```

But honestly I prefer to do it in vim,
since I can just pipe `ls` to vim and delete/rearrange any lines I want modified.
```
ls | vim -
:%s/.*/file '&'
:wq concat.txt
```

## Recommendations

This is my `input.conf` file, and it is optimized for both normal playback and quickly editing videos.
```
RIGHT seek 0.5 exact
LEFT seek -0.5 exact
UP seek 1
DOWN seek -1
{ add speed -0.25
} add speed 0.25
[ add speed -1
] add speed 1
SPACE cycle pause; set speed 1
```
I will give some insight on these options in the next section.

You may also want to change your key repeat delay and rate
by tweaking `input-ar-delay` and `input-ar-rate` to your liking in `mpv.conf`.

## Decoding Performance In MPV

Depending on the encoding of the video file being played, the following may be quite slow:
- The use of `exact` in `input.conf`.
- The use of the `.` and `,` keys to go frame by frame.
- The holding down of the `,` key to play the video in reverse.

Long story short, if the video uses an encoding that is difficult for mpv to decode,
exact seeking and backwards playback won't be smooth, which for normal playback is not a problem at all,
since by default mpv very quickly seeks keyframe-wise when you press `left arrow` or `right arrow`.

However if we are very intensively cutting a video,
it may be useful to be able to quickly seek to an exact time, and to quickly play in reverse.
In this case, it is useful to first make a proxy of the original video which is very easy to decode,
generate a cut list using this script with the proxy, and then apply the cut list to the original video.

To create a proxy which will be very easy to decode, you can use this ffmpeg command:
```
ffmpeg -noautorotate -i input.mp4 -pix_fmt yuv420p -g 1 -sn -an -vf colormatrix=bt601:bt709,scale=w=1280:h=1280:force_original_aspect_ratio=decrease:force_divisible_by=2 -c:v libx264 -crf 16 -preset superfast -tune fastdecode proxy.mp4
```
The important options here are the `-g 1` and the scale filter.
The other options have minimal or no effect.
The resulting video file should seek extremely quickly and play backwards just fine.

You can then generate a cut list for the video with this script using the `l` or `L` hotkeys assuming you have not changed them,
and once you are done simply open the `cut_list.txt` file, substitute the proxy file name for the original file name,
and `make_cuts`.
