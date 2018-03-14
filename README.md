# google-translate-anime
A script that automatically translates anime with Google Translate. It can generate subtitles and dub (though the audio in the dub does not match with the subtitles). Files that are too large to be uploaded have been replaced by a file named `$REPLACEDFILENAME.reference` that contains a description of where to obtain the file.

# Requirements
This script was developed on Ubuntu 16.04 LTS and works best on Linux. The commands this script requires to run are:
* Standard Linux Utilities (e.g. `bash`, `awk`, `bc`, `cp`, `echo`)
* `python3`
* `ffmpeg`
* `youtube-dl`
* `curl`
* `jq`

# Usage
Make sure all files are able to be executed as programs. Run `./gtr_anime.sh $ODIR $VIDLOC $SUBLOC` where `$ODIR` is the directory to output to, `$VIDLOC` is either the location of or the link to the video, and `$SUBLOC` is either the location of or the link to the subtitles file.

# Examples
* Attack On Titan Episode 1: `./gtr_anime.sh odir http://www.crunchyroll.com/attack-on-titan/episode-1-to-you-2000-years-in-the-future-the-fall-of-zhiganshina-1-623251 http://www.crunchyroll.com/attack-on-titan/episode-1-to-you-2000-years-in-the-future-the-fall-of-zhiganshina-1-623251`

# Compatibility
These lists may be expanded in the future.
##### Video File Types:
* `.mp4`
##### Subtitle File Types:
* `.srt`
##### Websites:
* `crunchyroll.com`: Note that there is no reliable way to download from crunchyroll. This program will try, but it will likely fail.
