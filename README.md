# google-translate-anime
A script that automatically translates anime with Google Translate. It can generate subtitles and dub (though the audio in the dub does not match with the subtitles). Files that are too large to be uploaded have been replaced by a file named `$REPLACEDFILENAME.reference` that contains a description of where to obtain the file.

# Requirements
This script was developed on Ubuntu 16.04 LTS and works best on Linux. The commands this script requires to run are:
* Standard Linux Utilities (e.g. `bash`, `awk`, `bc`, `getopts`)
* Access to the Google Cloud Platform and access to the `gcloud` command
* `python3`
* `ffmpeg` (Must be version `3.4.x` or higher)
* `youtube-dl` (Must be the most up to date version; Update with `youtube-dl -U`)
* `curl`
* `jq`

# Usage
Make sure all files are in the same directory and able to be executed as programs. The command structure is `path/to/gtr_anime.sh [OPTIONS]`, where `[OPTIONS]` can contain:
* `-o OUTPUT_DIRECTORY`: **(REQUIRED)** Where to output all the files
* `-v VIDEO_LOCARTION`: The url or file location of the video file
* `-s SUB_LOCATION`: The url or file location of the subtitle file
* `-b`: Clean temporary and output files before running
* `-a`: Clean temporary files after running

# Examples
* Attack On Titan Episode 1: `./gtr_anime.sh -o odir -v http://www.crunchyroll.com/attack-on-titan/episode-1-to-you-2000-years-in-the-future-the-fall-of-zhiganshina-1-623251 -s http://www.crunchyroll.com/attack-on-titan/episode-1-to-you-2000-years-in-the-future-the-fall-of-zhiganshina-1-623251`
* Lucky Star Episode 1: `./gtr_anime.sh -o odir -v http://www.crunchyroll.com/lucky-star/episode-1-the-girl-who-dashes-off-751179 -s http://www.crunchyroll.com/lucky-star/episode-1-the-girl-who-dashes-off-751179`

# Compatibility
These lists may be expanded in the future.
##### Video File Types:
* `.mp4`
##### Subtitle File Types:
* `.srt`
##### Websites:
* `crunchyroll.com`: Note that there is no reliable way to download from crunchyroll. This program will try, but it will likely fail.
