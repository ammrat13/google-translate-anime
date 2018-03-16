#!/bin/bash
################################################################################
# google-translate-anime.sh
# By: Ammar Ratnani
#
# This program will take in an output directory, the location of the video 
# file, and the location of the audio file. If the locations are urls, the it 
# will download from that url. It will then put the subtitles through google 
# translate. It will output a "translated" subtitle file and dubbed video.
################################################################################


echo ""

# Download subroutine. Downloads the video from the url specified
function download_vid_url () {
	# Rename parameters to make things more clear
	URL=$1
	# Check each possible site
	# Crunchyroll
	if [[ $URL =~ http[s]?:\/\/www.crunchyroll\.com[^\s]* ]]; then
		youtube-dl -o "$ODIR/old.mp4" -f worst $URL
	fi
}

# Download subroutine. Downloads the subtitles from the url specified
function download_sub_url () {
	# Rename parameters to make things more clear
	URL=$1
	# Check each possible site
	# Crunchyroll
	if [[ $URL =~ http[s]?:\/\/www.crunchyroll\.com[^\s]* ]]; then
		youtube-dl -o "$ODIR/old.srt" --write-sub --sub-format srt \
			--sub-lang enUS --skip-download $URL
		mv $ODIR/old.enUS.srt $ODIR/old.srt
	fi
}

# Takes in a number n and a string and writes the string to stdout with line 
# breaks so no line is longer than n characters
function break_on_n () {
	IFS=" "
	count=0
	line=""
	for word in $2; do
		if (( count + ${#word} + 1 > $1 )); then
			echo $line
			count=0
			line=""
		fi
		line="$line$word "
		count=$((count + ${#word} + 1))
	done

	if [[ ! -z $line ]]; then
		echo $line
	fi
	IFS=$' \t\n'
}

# Takes an srt formatted time and returns the time in seconds
function srt_to_sec () {
	IFS=":," ss=($1)
	IFS=$' \t\n'
	echo $(echo "${ss[0]} * 3600 + ${ss[1]} * 60 + ${ss[2]} + ${ss[3]} * 0.01" | bc | awk '{printf "%.2f\n", $0}')
}

# Takes an srt file and returns the time intervals in the file, one per line
function srt_time_ints () {
	IFS=$'\n'
	for line in $(cat $1 | grep " --> "); do
		ts=($(echo $line | sed "s/ --> /\n/g"))
		echo "$(srt_to_sec ${ts[0]}),$(srt_to_sec ${ts[1]})"
	done
	IFS=$' \t\n'
}


# Parse command line options
APIKEY=""			# API Key for Google Cloud
ODIR=""				# Output directory
VIDLOC=""			# Location or url of the video
SUBLOC=""			# Location or url of the subtitles
CLEAN_START=false	# Clear temporary and output files on start?
CLEAN_END=false		# Clear temporary files on end?
while getopts ":o:k:v:s:ba" opt; do
	case $opt in 
		o) 
			ODIR=$OPTARG
			;;
		k)
			APIKEY=$OPTARG
			;;
		v)
			VIDLOC=$OPTARG
			;;
		s)
			SUBLOC=$OPTARG
			;;
		b)
			CLEAN_START=true
			;;
		a)
			CLEAN_END=true
			;;
		\?)
			echo "Error: Invalid option encountered -$OPTARG"
			exit
			;;
		:)
			true # Do nothing
			;;
	esac
done
# Make sure output directory and key were set
if [[ -z "$ODIR" ]]; then
	echo "Error: Output directory is required"
	exit
fi
if [[ -z "$APIKEY" ]]; then
	echo "Error: Google Cloud API key is required"
	exit
fi

# Clean if we have to
if $CLEAN_START; then
	echo "Cleaning temporary and output files ..."
	echo ""
	rm -rf "$ODIR/tmp"
	rm -f "$ODIR/new.mp4"
	rm -f "$ODIR/new.srt"
fi

# Create the output directories if they do not exist
if [[ ! -d $ODIR ]]; then
	mkdir $ODIR
fi
if [[ ! -d "$ODIR/tmp" ]]; then
	mkdir $ODIR/tmp
fi


# Only try to obtain the video file if it is not already present
if [[ ! -f "$ODIR/old.mp4" ]] || [[ ! -s "$ODIR/old.mp4" ]]; then
	# If the video file exists and is mp4, copy it as is
	if [[ -f $VIDLOC ]] && [[ $VIDLOC =~ .*\.mp4 ]]; then
		echo "The file $VIDLOC is already mp4. Copying to $ODIR/old.mp4 ..."
		cp $VIDLOC $ODIR/old.mp4
	# If the file exists but is not an mp4, then convert with ffmpeg
	elif [[ -f $VIDLOC ]]; then
		echo "The file $VIDLOC exists but is not mp4. Converting and outputing to $ODIR/old.mp4 ..."
		ffmpeg -y -i $VIDLOC "$ODIR/old.mp4" &> /dev/null
	# If the location is a valid url, download it
	elif [[ $VIDLOC =~ http[^\s]* ]]; then
		echo "The string $VIDLOC is a url. Downloading video (this may take a while) ..."
		download_vid_url $VIDLOC &> /dev/null
	fi

	# Make sure the file exists now
	if [[ ! -f "$ODIR/old.mp4" ]] || [[ ! -s "$ODIR/old.mp4" ]]; then
		echo "Failed to obtain video file. Terminating."
		exit
	fi
else
	echo "The file $ODIR/old.mp4 already exists. No need to obtain it."
fi

echo ""


# Only try to obtain the subtitles file if it is not already present
if [[ ! -f "$ODIR/old.srt" ]] || [[ ! -s "$ODIR/old.srt" ]]; then
	# If the subtitles file exists and is enUS-srt, copy it as is
	if [[ -f $SUBLOC ]] && [[ $SUBLOC =~ .*\.[a-zA-Z]+\.srt ]]; then
		echo "The file $SUBLOC is already srt. Copying to $ODIR/old.srt ..."
		cp $SUBLOC $ODIR/old.srt
	# If the location is a valid url, download it
	elif [[ $SUBLOC =~ http[^\s]* ]]; then
		echo "The string $SUBLOC is a url. Downloading subtitles ..."
		download_sub_url $SUBLOC &> /dev/null
	fi

	# Make sure the file exists now
	if [[ ! -f "$ODIR/old.srt" ]] || [[ ! -s "$ODIR/old.srt" ]]; then
		echo "Failed to obtain subtitles file. Terminating."
		exit
	fi
else
	echo "The file $ODIR/old.srt already exists. No need to obtain it."
fi

echo ""


# Get the times for each clip
vid_times=($(srt_time_ints "$ODIR/old.srt"))

echo "Splitting video into flac files and translating ..."
for line in ${vid_times[@]}; do
	# Split on commas into the array ts
	IFS="," ts=($line)
	IFS=$' \t\n'

	# Only translate if we have not already
	if [[ ! -f "$ODIR/tmp/${ts[0]}.sub.txt" ]] || [[ ! -s "$ODIR/tmp/${ts[0]}.sub.txt" ]]; then
		echo "Processing clip from ${ts[0]} to ${ts[1]}"

		# Output the audio between those times
		ffmpeg -y -i "$ODIR/old.mp4" -ss ${ts[0]} -t $(echo "${ts[1]}-${ts[0]}" | bc | awk '{printf "%.2f\n", $0}') \
			-ar 44100 -ac 1 "$ODIR/tmp/${ts[0]}.flac" &> /dev/null

		# Google Speech API as specified to save the result to jap
		jap=$(
			echo "{
				'config': {
					'encoding': 'FLAC',
					'sampleRateHertz': 44100,
					'languageCode': 'ja-JP',
					'enableWordTimeOffsets': false
				},
				'audio': {
					'content': '$(base64 $ODIR/tmp/${ts[0]}.flac -w 0)'
				}
			}" | \
			curl -s -X POST \
				-H "Content-Type: application/json; charset=utf-8" \
				-d @- \
				"https://speech.googleapis.com/v1/speech:recognize?key=$APIKEY" | \
			# Pipe the result for processing
			jq -r .results[0].alternatives[0].transcript
		)

		# Google Translate API as specified to save the result to eng
		eng=$(
			curl -s -X POST \
			-H "Content-Type: application/json" \
			--data "{
				'q': '$jap',
				'source': 'ja',
				'target': 'en',
				'format': 'text'
			}" "https://translation.googleapis.com/language/translate/v2?key=$APIKEY" | \
			jq -r .data.translations[0].translatedText
		)

		# Append to output file
		echo $eng > $ODIR/tmp/${ts[0]}.sub.txt
	fi

	# Make sure translation succeeded
	if [[ ! -f "$ODIR/tmp/${ts[0]}.sub.txt" ]] || [[ ! -s "$ODIR/tmp/${ts[0]}.sub.txt" ]]; then
		echo "Failed to translate. Terminating."
		exit
	fi
done

echo ""


# Generate new subtitles
echo "Generating new subtitles ..."
# Consolidate subtitles
> $ODIR/tmp/raw_subs.txt
for line in ${vid_times[@]}; do
	# Split on commas into the array ts
	IFS="," ts=($line)
	IFS=$' \t\n'
	cat "$ODIR/tmp/${ts[0]}.sub.txt" >> $ODIR/tmp/raw_subs.txt
done
IFS=$(echo -en "\n\b") raw_subs=($(cat "$ODIR/tmp/raw_subs.txt"))
IFS=$' \t\n'

# Write subtitles
> $ODIR/new.srt
IFS=$'\n'
i=0;
cat "$ODIR/old.srt" | sed "/[[:alpha:]]/d" | while read line; do
	if [[ -z $line ]]; then
		if [[ "${raw_subs[$i]}" == "null" ]]; then
			echo "[Censored]" >> $ODIR/new.srt
		else
			break_on_n 50 "${raw_subs[$i]}" >> $ODIR/new.srt
		fi
		echo "" >> $ODIR/new.srt
		i=$i+1
	else
		echo $line >> $ODIR/new.srt
	fi
done
IFS=$' \t\n'
unset i

echo ""


# Generate new voices if we have not already
echo "Generating voiceovers ..."
i=0
for line in ${vid_times[@]}; do
	# Split on commas into the array ts
	IFS="," ts=(${line})
	IFS=$' \t\n'

	# Only generate new voices if we have not already
	if [[ ! -f "$ODIR/tmp/${ts[0]}.trans.m4a" ]] || [[ ! -s "$ODIR/tmp/${ts[0]}.trans.m4a" ]]; then
		# Make sure subtitles were generated
		echo "Processing clip from ${ts[0]} to ${ts[1]}"
		if [[ ! "${raw_subs[i]}" == "null" ]]; then
			gtts-cli -o "$ODIR/tmp/${ts[0]}.trans.m4a" "${raw_subs[i]}" &> /dev/null
		else
			# 1000 Hz sine wave
			ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=$(echo "${ts[1]}-${ts[0]}+1" | bc)" \
				-ac 2 "$ODIR/tmp/${ts[0]}.trans.m4a" &> /dev/null
		fi
	fi

	# Make sure voice generation succeeded
	if [[ ! -f "$ODIR/tmp/${ts[0]}.trans.m4a" ]] || [[ ! -s "$ODIR/tmp/${ts[0]}.trans.m4a" ]]; then
		# Try writing a 1000 Hz sine wave
		ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=$(echo "${ts[1]}-${ts[0]}+1" | bc)" \
			-ac 2 "$ODIR/tmp/${ts[0]}.trans.m4a" &> /dev/null
	fi
	if [[ ! -f "$ODIR/tmp/${ts[0]}.trans.m4a" ]] || [[ ! -s "$ODIR/tmp/${ts[0]}.trans.m4a" ]]; then
		echo "Failed to generate voice clip $ODIR/tmp/${ts[0]}.trans.m4a. Terminating."
		exit
	fi

	i=$i+1
done
unset i

echo ""


echo "Generating video clips ..."
# Length of the full video
lenvf=$(ffprobe -i "$ODIR/old.mp4" -show_entries format=duration -v quiet -of csv="p=0" | awk '{printf "%.2f\n", $0}')
for (( i=-1; i<${#vid_times[@]}; i++ )); do
	# Only regenerate video if we have not already
	if [[ ! -f "$ODIR/tmp/pm$i.mp4" ]] || [[ ! -s "$ODIR/tmp/pm$i.mp4" ]]; then 
		# Special handling for before the first subtitle
		if (( i == -1 )); then
			# Split on commas into the array ts
			IFS="," ts=(${vid_times[0]})
			IFS=$' \t\n'
			echo "Processing clip -1 from 0.00 to ${ts[0]}"
			ffmpeg -y -t ${ts[0]} -i "$ODIR/old.mp4" -c copy "$ODIR/tmp/pm$i.mp4" &> /dev/null
		elif (( i != ${#vid_times[@]}-1 )); then
			# Split on commas into the array ts
			IFS="," ts0=(${vid_times[$i]})
			IFS="," ts1=(${vid_times[$i+1]})
			IFS=$' \t\n'
			# Length of audio stream with leading 0
			lena=$(ffprobe -i "$ODIR/tmp/${ts0[0]}.trans.m4a" -show_entries format=duration -v quiet -of csv="p=0" | awk '{printf "%.2f\n", $0}')
			# Length of the video stream with leading 0
			lenv=$(echo "${ts1[0]}-${ts0[0]}" | bc | awk '{printf "%.2f\n", $0}')
			echo "Processing clip $i from ${ts0[0]} to ${ts1[0]}"
			if (( $(echo "$lena >= $lenv" | bc) )); then
				# Audio longer than video
				# Crop video
				ffmpeg -y -ss ${ts0[0]} -t $lenv \
					-i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid.mp4" &> /dev/null
				# Crop audio and merge
				ffmpeg -y -i "$ODIR/tmp/tmpvid.mp4" -i "$ODIR/tmp/${ts0[0]}.trans.m4a" \
					-map 0:v:0 -map 1:a:0 -ac 2 -shortest "$ODIR/tmp/pm$i.mp4" &> /dev/null
				rm "$ODIR/tmp/tmpvid.mp4"
			else
				# Audio shorter than video
				# Crop first part of video
				ffmpeg -y -ss ${ts0[0]} -t $lena \
					-i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid.mp4" &> /dev/null
				# Merge audio
				ffmpeg -y -i "$ODIR/tmp/tmpvid.mp4" -i "$ODIR/tmp/${ts0[0]}.trans.m4a" \
					-map 0:v:0 -map 1:a:0 -ac 2 -shortest "$ODIR/tmp/tmpvid2.mp4" &> /dev/null
				# Crop second part of video
				ffmpeg -y -ss $(echo "${ts0[0]}+$lena" | bc | awk '{printf "%.2f\n", $0}') \
					-t $(echo "$lenv-$lena" | bc | awk '{printf "%.2f\n", $0}') \
					-i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid3.mp4" &> /dev/null
				# Concatenate as specified with filter
				ffmpeg -y -i "$ODIR/tmp/tmpvid2.mp4" -i "$ODIR/tmp/tmpvid3.mp4" \
					-filter_complex "[0:v] [0:a] [1:v] [1:a] concat=n=2:v=1:a=1 [v] [a]" \
					-map "[v]" -map "[a]" "$ODIR/tmp/pm$i.mp4" &> /dev/null
				rm "$ODIR/tmp/tmpvid.mp4"
				rm "$ODIR/tmp/tmpvid2.mp4"
				rm "$ODIR/tmp/tmpvid3.mp4"
			fi
		# Special handling for the last iteration
		elif (( i == ${#vid_times[@]}-1 )); then
			# Split on commas into the array ts
			IFS="," ts0=(${vid_times[$i]})
			IFS=$' \t\n'
			# Length of audio stream with leading 0
			lena=$(ffprobe -i "$ODIR/tmp/${ts0[0]}.trans.m4a" -show_entries format=duration -v quiet -of csv="p=0" | awk '{printf "%.2f\n", $0}')
			# Length of the video stream with leading 0
			lenv=$(echo "$lenvf-${ts0[0]}" | bc | awk '{printf "%.2f\n", $0}')
			echo "Processing clip $i from ${ts0[0]} to $lenvf"
			if (( $(echo "$lena >= $lenv" | bc) )); then
				# Audio longer than video
				# Crop video
				ffmpeg -y -ss ${ts0[0]} \
					-i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid.mp4" &> /dev/null
				# Crop audio and merge
				ffmpeg -y -i "$ODIR/tmp/tmpvid.mp4" -i "$ODIR/tmp/${ts0[0]}.trans.m4a" \
					-map 0:v:0 -map 1:a:0 -ac 2 -shortest "$ODIR/tmp/pm$i.mp4" &> /dev/null
				rm "$ODIR/tmp/tmpvid.mp4"
			else
				# Audio shorter than video
				# Crop first part of video
				ffmpeg -y -ss ${ts0[0]} -t $lena \
					-i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid.mp4" &> /dev/null
				# Merge audio
				ffmpeg -y -i "$ODIR/tmp/tmpvid.mp4" -i "$ODIR/tmp/${ts0[0]}.trans.m4a" \
					-map 0:v:0 -map 1:a:0 -ac 2 -shortest "$ODIR/tmp/tmpvid2.mp4" &> /dev/null
				# Crop second part of video
				ffmpeg -y -ss $(echo "${ts0[0]}+$lena" | bc | awk '{printf "%.2f\n", $0}') \
					-i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid3.mp4" &> /dev/null
				# Concatenate as specified with filter
				ffmpeg -y -i "$ODIR/tmp/tmpvid2.mp4" -i "$ODIR/tmp/tmpvid3.mp4" \
					-filter_complex "[0:v] [0:a] [1:v] [1:a] concat=n=2:v=1:a=1 [v] [a]" \
					-map "[v]" -map "[a]" "$ODIR/tmp/pm$i.mp4" &> /dev/null
				rm "$ODIR/tmp/tmpvid.mp4"
				rm "$ODIR/tmp/tmpvid2.mp4"
				rm "$ODIR/tmp/tmpvid3.mp4"
			fi
		fi
	fi

	# Make sure video generation was successful
	if [[ ! -f "$ODIR/tmp/pm$i.mp4" ]] || [[ ! -s "$ODIR/tmp/pm$i.mp4" ]]; then 
		echo "Failed to generate video clip $ODIR/tmp/pm$i.mp4. Terminating."
		exit
	fi
done


# Merge video clips
echo "Merging video clips (this may take a while) ..."
# Generate the command
cmd="ffmpeg -y"
# Input files
for (( i=-1; i<${#vid_times[@]}; i++ )); do
	cmd="$cmd -i $ODIR/tmp/pm$i.mp4"
done
# Filter complex
cmd="$cmd -filter_complex '"
for (( i=-1; i<${#vid_times[@]}; i++ )); do
	cmd="$cmd[$(expr $i + 1):v] [$(expr $i + 1):a] "
done
# Make rest of command and execute
cmd="$cmd concat=n=$(expr ${#vid_times[@]} + 1):v=1:a=1 [v] [a]'"
cmd="$cmd -map '[v]' -map '[a]' '$ODIR/new.mp4'"
eval "$cmd" &> /dev/null

# Make sure merge was successful
if [[ ! -f "$ODIR/new.mp4" ]] || [[ ! -s "$ODIR/new.mp4" ]]; then
	echo "Failed to generate video. Terminating."
	exit
fi

echo ""


# Clean if we have to
if $CLEAN_END; then
	echo "Cleaning temporary files ..."
	rm -rf "$ODIR/tmp"
fi