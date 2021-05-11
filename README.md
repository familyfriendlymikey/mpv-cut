# mpv-cut
Cut videos directly inside of [mpv](https://mpv.io/installation/).

## Installation
#### Linux/MacOS
```
wget -P ~/.config/mpv/scripts/ "https://raw.githubusercontent.com/familyfriendlymikey/mpv-cut/main/cut.js"
```
#### Windows
Download [cut_windows.js](https://raw.githubusercontent.com/familyfriendlymikey/mpv-cut/main/cut_windows.js) to `C:\Users\user\AppData\Roaming\mpv\scripts\cut_windows.js`.

## Usage
1. Open a video file with `mpv`.
1. Press `c` at the start time, and `c` again at the end time.
2. The cut file will appear in the same folder with the name `original-filename_start-time_TO_end-time.mkv`.

## Note
- Working on Linux with `mpv` launched from the commandline.
- Working on MacOS with `mpv` launched from the commandline.
- Working on Windows with `mpv` launched from Explorer, CMD, and PowerShell.
- Not working on MacOS with `mpv` launched from Finder.
