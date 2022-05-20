# mpv-cut

## What Is This

The core functionality of this script is to very
quickly cut videos both losslessly and re-encoded-ly
with the help of the fantastic media player
[mpv](https://mpv.io/installation/).

There is also the added functionality of logging
the timestamps of all cuts you have made to
a text file referred to as a "cut list".
This serves as a backup in the event you make many cuts on a long video.

Lastly, I have added a bookmarking functionality of sorts,
which appends the current timestamp to a text file and then
reloads those timestamps as chapters in mpv.
This is useful when watching shows or movies
where you might want to compile funny or cool moments
but don't want to ruin your watching
experience by making cuts as you watch.

More details in [usage](#usage).

## Installation
Place `cut.lua` into one of the following directories:

#### Linux/MacOS
```
~/.config/mpv/scripts/
```

#### Windows
```
%AppData%\Roaming\mpv\scripts\
```

That's all you have to do, next time you run mpv the script will be automatically loaded.

## Usage

### Cutting A Video Losslessly

- Press `c` to begin a cut.
- Seek to a later time in the video.
- Press `c` again to make the cut.

The resulting video file will be placed in a
`CUTS` folder in the same directory as the source file.

### Other Actions

You can press `a` to cycle between the three available actions:

- Copy (lossless cut, rounds to keyframes)
- Encode (re-encoded cut, exact)
- List (generate the cut list file only, does not cut the video)

### Cutting To Global Dir

You can press `g` to toggle saving to the
configured global directory as opposed to
the same directory as the source file.

### Bookmarking

Press `i` to append the current timestamp to a bookmark text file.
This automatically reloads the timestamps as chapters in mpv.
You can navigate between these chapters with the default mpv bindings,
`!` and `@`.

### Channels

The resulting cut list and bookmark files will
be prefixed with one of ten channel names.
This is to help you categorize cuts and bookmarks.
You can press `0` through `9` to select a channel,
or press `-` to decrement the channel and `+` to increment the channel.
If there is no configured name for a channel,
the channel number will be used instead.

### make_cuts

When using the "list" action,
you can use the `make_cuts` helper script,
which will generate a temporary file named `make_cuts.sh`,
which can be edited to your liking and then executed.
See [rationale](#why-does-make-cuts-generate-another-file-instead-of-just-cutting) for more.

If you use make_cuts often, to make things more convenient
you can add the script to your path:

- Add a custom folder to your PATH such as `~/bin`.
- Place the `make_cuts` script in that folder.
- Run it anywhere with bash simply by running the command `make_cuts`.

## Config

You can configure settings by editing `cut.lua`:
```lua
local GLOBAL_DIR = "~/Desktop"

local ACTION = "copy"
local GENERATE_CUT_LIST = true
local USE_GLOBAL_DIR = false

local ENCODE_CRF = 16
local ENCODE_PRESET = "superfast"

local DEFAULT_CHANNEL = 0

CHANNEL_NAMES[0] = "FUNNY"
CHANNEL_NAMES[1] = "COOL"
CHANNEL_NAMES[2] = "SEXY"
```
You can also configure all of the key mappings.

## Optimized MPV Input Config

This is my `input.conf` file, and it is optimized
for both normal playback and quickly editing videos.
```
RIGHT seek 2 exact
LEFT seek -2 exact

] add speed 0.5
[ add speed -0.5
} add speed 0.25
{ add speed -0.25

SPACE cycle pause; set speed 1    # Reset speed whenever pausing.
BS script-binding osc/visibility  # Make progress bar stay visible.
UP seek 0.01 keyframes            # Seek by keyframes only.
DOWN seek -0.01 keyframes         # Seek by keyframes only.
```

You may also want to change your key repeat delay and rate
by tweaking `input-ar-delay` and `input-ar-rate`
to your liking in `mpv.conf`.

## Rationale And Other Helpful Information

### Why Is Cut List On By Default?

There are plenty of reasons, but to give some examples:

- Video seems to be pretty complex, at least to me.
One video file may cause certain issues,
and another may not, which makes writing
an ffmpeg command that accounts for all scenarios difficult.
If you spend a ton of time making many cuts in a long movie
only to find that the colors look off because of some
10-bit h265 dolby mega surround whatever the fuck,
with a cut list it's trivial to edit
the ffmpeg command and re-make the cuts.

- Maybe you forget that the foreign language video you're cutting has
softsubs rather than hardsubs,
and you make a bunch of encode cuts
resulting in cuts that have no subtitles.

- You delete the source video for storage reasons,
but still want to have a back up of the cut timestamps
in the event you need to remake the cuts.

If you'd like to turn it off by default,
you can do so by setting `GENERATE_CUT_LIST = false` in the config.

### Why Would I Bookmark Instead Of Cutting?

Suppose you're watching a movie or show for your own enjoyment,
but you also want to compile funny moments to post online
or send to your friends.
It would ruin your viewing experience to wait for a funny
moment to be over in order to make a cut.
Instead, you can quickly make a bookmark whenever you laugh,
and once you're done watching you can go back and make actual cuts.

### Why Is Lossless Cutting Called "Copy"?
This refers to ffmpeg's `-copy` flag which copies the input stream
instead of re-encoding it, meaning that the cut will process
extremely quickly and the resulting video will retain
100% of the original quality.
The main drawback is that the cut may have some extra
video at the beginning and end,
and as a result of that there may be some slightly wonky behavior
with video players and editors.

### Why Would I Re-Encode A Video?
- As mentioned above, copying the input stream is very fast and lossless
but the cuts are not exact. Sometimes you want a cut to be exact.
- If you want to change the framerate.
- If you want to encode hardsubs.
- If the video's compression isn't efficient enough to upload
to a messaging platform or something, you may want to compress it more.

For convenience, I put two variables at the top of `cut.lua` which you can modify to your liking:
```
local ENCODE_CRF = 16
local ENCODE_PRESET = "superfast"
```
The `CRF` is the quality, with `0` being lossless,
`51` being horrible quality,
and `18` being agreed upon as mostly perceptually lossless.

The `preset` is how fast you want to compress the video,
with faster presets resulting in
potentially larger files/potentially worse quality.

### How Can I Merge (Concatenate) The Resulting Cuts Into One File?

To concatenate videos with ffmpeg,
you need to create a file with content like this:
```
file cut_1.mp4
file cut_2.mp4
file cut_3.mp4
file cut_4.mp4
```
You can name the file whatever you want, here I named it `concat.txt`.

Then run the command:
```
ffmpeg -f concat -safe 0 -i concat.txt -c copy out.mp4
```

That's annoying though, so you can skip
manually creating the file by using bash.
This command will concatenate all files in the current directory
that begin with "COPY_":
```
ffmpeg -f concat -safe 0 -i <(printf 'file %q\n' "$PWD"/COPY_*) -c copy lol.mp4
```
- You need to escape apostrophes which is why
we are using `printf %q "$string"`.
- Instead of actually creating a file we just
use process substitution `<(whatever)` to create a temporary file,
which is why we need the `$PWD` in there for the absolute path.

You can also do it in vim, among other things.
```
ls | vim -
:%s/'/\\'/g
:%norm Ifile 
:wq concat.txt
```
This substitution might not cover all cases, but whatever,
if you're concatenating a file named `[{}1;']["!.mp4`
you can figure it out yourself.

### Can I Make Seeking And Reverse Playback Faster?

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
generate a cut list with the proxy, and then apply the cut list to the original video.

To create a proxy which will be very easy to decode, you can use this ffmpeg command:
```
ffmpeg -noautorotate -i input.mp4 -pix_fmt yuv420p -g 1 -sn -an -vf colormatrix=bt601:bt709,scale=w=1280:h=1280:force_original_aspect_ratio=decrease:force_divisible_by=2 -c:v libx264 -crf 16 -preset superfast -tune fastdecode proxy.mp4
```
The important options here are the `-g 1` and the scale filter.
The other options are more or less irrelevant.
The resulting video file should seek extremely quickly
and play backwards just fine.

Once you are done generating the cut list,
simply open the `cut_list.txt` file,
substitute the proxy file name for the original file name,
and run `make_cuts` on it.
