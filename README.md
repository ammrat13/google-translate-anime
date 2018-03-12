# google-translate-anime
A script that automatically translates anime with Google Translate. Right now it only generates subtitles. Dubbing capability may be added in the future. Files that are too large to be uploaded have been replaces by a file named `$REPLACEDFILENAME.reference` that contains a description of where to obtain the file.

# Requirements
This script was developed on a Linux system and works best on Linux. The commands this script requires to run are:
* `bash`
* `python3`
* `ffmpeg`
* `youtube-dl`
* `curl`
* `jq`

# Usage
Make sure all files are able to be executed as programs. Run `./gtr_anime.sh $ODIR $VIDLOC $SUBLOC` where `$ODIR` is the directory to output to, `$VIDLOC` is either the location of or the link to the video, and `$SUBLOC` is either the location of or the link to the subtitles file.

# Compatibility
These lists may be expanded in the future.
##### Video File Types:
* `.mp4`
##### Subtitle File Types:
* `.srt`
##### Websites:
* `crunchyroll.com`
