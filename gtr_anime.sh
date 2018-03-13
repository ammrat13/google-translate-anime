#!/bin/bash
################################################################################
# google-translate-anime.sh
# By: Ammar Ratnani
#
# This program will take in an output directory, the location of the video 
# file, and the location of the audio file. If the locations are urls, the it 
# will download from that url. It will then put the subtitles through google 
# translate. It will output a "translated" subtitle file.
################################################################################


# Rename the parameters so the code is more clear
ODIR=$1
VIDLOC=$2
SUBLOC=$3


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
		youtube-dl -o "$ODIR/old.enUS.srt" --write-sub --sub-format srt \
			--sub-lang enUS --skip-download $URL
		mv $ODIR/old.enUS.srt $ODIR/old.srt
	fi
}


# Create the output directories if they do not exist
if [ ! -d $ODIR ]; then
	mkdir $ODIR
fi
if [ ! -d "$ODIR/tmp" ]; then
	mkdir $ODIR/tmp
fi


# Only try to obtain the video file if it is not already present
if [[ ! -f "$ODIR/old.mp4" ]]; then
	# If the video file exists and is mp4, copy it as is
	if [[ -f $VIDLOC ]] && [[ $VIDLOC =~ .*\.mp4 ]]; then
		echo "The file $VIDLOC is already mp4. Copying to $ODIR/old.mp4 ..."
		cp $VIDLOC $ODIR/old.mp4
	# If the file exists but is not an mp4, then convert with ffmpeg
	elif [[ -f $VIDLOC ]]; then
		echo "The file $VIDLOC exists but is not mp4. Converting and outputing to $ODIR/old.mp4 ..."
		ffmpeg -i $VIDLOC "$ODIR/old.mp4" &> /dev/null
	# If the location is a valid url, download it
	elif [[ $VIDLOC =~ http[^\s]* ]]; then
		echo "The string $VIDLOC is a url. Downloading video ..."
		download_vid_url $VIDLOC
	fi

	# Make sure the file exists now
	if [[ ! -f "$ODIR/old.mp4" ]]; then
		echo "Failed to obtain video file. Terminating."
		exit
	fi
else
	echo "The file $ODIR/old.mp4 already exists. No need to obtain it."
fi

echo ""


# Only try to obtain the subtitles file if it is not already present
if [[ ! -f "$ODIR/old.srt" ]]; then
	# If the subtitles file exists and is enUS-srt, copy it as is
	if [[ -f $SUBLOC ]] && [[ $SUBLOC =~ .*\.[a-zA-Z]+\.srt ]]; then
		echo "The file $SUBLOC is already srt. Copying to $ODIR/old.srt ..."
		cp $SUBLOC $ODIR/old.srt
	# If the location is a valid url, download it
	elif [[ $SUBLOC =~ http[^\s]* ]]; then
		echo "The string $SUBLOC is a url. Downloading subtitles ..."
		download_sub_url $SUBLOC
	fi

	# Make sure the file exists now
	if [[ ! -f "$ODIR/old.srt" ]]; then
		echo "Failed to obtain subtitles file. Terminating."
		exit
	fi
else
	echo "The file $ODIR/old.srt already exists. No need to obtain it."
fi

echo ""


# Get the times for each clip
vid_times=($(./get_times.py "$ODIR/old.srt"))

# Only translate if we have not already
if [[ ! -f "$ODIR/tmp/raw_subs.txt" ]] || [[ $(wc -l < $ODIR/tmp/raw_subs.txt) -ne ${#vid_times[@]} ]]; then
	echo "Splitting video into wav files and translating ..."
	# Create output file if it does not exist and clear it if it does
	> $ODIR/tmp/raw_subs.txt

	for line in ${vid_times[@]}; do
		# Split on commas into the array ts
		IFS="," ts=(${line})
		echo "Processing clip from ${ts[0]} to ${ts[1]}"

		# Output the audio between those times
		ffmpeg -i "$ODIR/old.mp4" -ss ${ts[0]} -t $(echo "${ts[1]}-${ts[0]}" | bc) \
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
				-H "Authorization: Bearer "$(gcloud auth print-access-token) \
				-H "Content-Type: application/json; charset=utf-8" \
				-d @- \
				"https://speech.googleapis.com/v1/speech:recognize" | \
			# Pipe the result for processing
			jq -r .results[0].alternatives[0].transcript
		)

		echo "Japanese transcript: $jap"

		# Google Translate API as specified to save the result to eng
		eng=$(
			curl -s -X POST \
			-H "Content-Type: application/json" \
			-H "Authorization: Bearer "$(gcloud auth print-access-token) \
			--data "{
				'q': '$jap',
				'source': 'ja',
				'target': 'en',
				'format': 'text'
			}" "https://translation.googleapis.com/language/translate/v2" | \
			jq -r .data.translations[0].translatedText
		)
		echo "English translation: $eng"

		# Append to output file
		echo $eng >> $ODIR/tmp/raw_subs.txt
	done
else
	echo "The video has already been translated. No need to redo."
fi

echo ""


# Generate new subtitles
echo "Generating new subtitles ..."
./new_subs.py $ODIR/old.srt $ODIR/tmp/raw_subs.txt > $ODIR/new.srt

# Generate new voices if we have not already
echo "Generating voiceovers ..."
IFS=$(echo -en "\n\b") raw_subs=($(cat "$ODIR/tmp/raw_subs.txt"))
i=0
for line in ${vid_times[@]}; do
	# Split on commas into the array ts
	IFS="," ts=(${line})

	# Only generate new voices if we have not already
	if [[ ! -f "$ODIR/tmp/${ts[0]}.trans.m4a" ]]; then
		# Make sure subtitles were generated
		echo "Processing clip from ${ts[0]} to ${ts[1]}"
		if [[ ! "${raw_subs[i]}" == "null" ]]; then
			gtts-cli -o "$ODIR/tmp/${ts[0]}.trans.m4a" ${raw_subs[i]}
		else
			# 1000 Hz sine wave
			ffmpeg -f lavfi -i "sine=frequency=1000:duration=$(echo "${ts[1]}-${ts[0]}+1" | bc)" \
				-ac 1 "$ODIR/tmp/${ts[0]}.trans.m4a" &> /dev/null
		fi
	else
		true # Do nothing
	fi

	i=$i+1
done
unset i

echo ""


echo "Generating video ..."
for (( i=-1; i<${#vid_times[@]}; i++ )); do
	# Special handling for before the first subtitle
	if (( i == -1 )); then
		# Split on commas into the array ts
		IFS="," ts=(${vid_times[0]})
		echo "Processing clip from 0.00 to ${ts[0]}"
		ffmpeg -y -t ${ts[0]} -i "$ODIR/old.mp4" -c copy "$ODIR/new.mp4" &> /dev/null
	elif (( i != ${#vid_times[@]}-1 )); then
		# Split on commas into the array ts
		IFS="," ts0=(${vid_times[$i]})
		IFS="," ts1=(${vid_times[$i+1]})
		# Length of audio stream
		lena=$(ffprobe -i "$ODIR/tmp/${ts0[0]}.trans.m4a" -show_entries format=duration -v quiet -of csv="p=0")
		# Length of the video stream
		lenv=$(echo "${ts1[0]}-${ts0[0]}" | bc)
		echo "Processing clip from ${ts0[0]} to ${ts1[0]}"
		if (( $(echo "$lena > $lenv" | bc) )); then
			# Audio longer than video
			# Crop video
			ffmpeg -y -ss $(echo "${ts0[0]}+.01" | bc) -t $lenv -i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid.mp4" &> /dev/null
			# Crop audio and merge
			ffmpeg -y -i "$ODIR/tmp/tmpvid.mp4" -i "$ODIR/tmp/${ts0[0]}.trans.m4a" \
				-map 0:v:0 -map 1:a:0 -shortest "$ODIR/tmp/tmpvid2.mp4" &> /dev/null
			# Concatenate as specified with filter
			ffmpeg -y -i "$ODIR/new.mp4" -i "$ODIR/tmp/tmpvid2.mp4" \
				-filter_complex "[0:v:0][0:a:0][1:v:0]concat=n=2:v=1:a=1[outv][outa]" \
				-map "[outv]" -map "[outa]" "$ODIR/newp.mp4" &> /dev/null
			cp "$ODIR/newp.mp4" "$ODIR/new.mp4"
			rm "$ODIR/tmp/tmpvid.mp4"
			rm "$ODIR/tmp/tmpvid2.mp4"
			rm "$ODIR/newp.mp4"
			exit
		else
			# Audio shorter than video
			# Crop first part of video
			ffmpeg -y -ss $(echo "${ts0[0]}+.01" | bc) -t $lena -i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid.mp4" &> /dev/null
			# Merge audio
			ffmpeg -y -i "$ODIR/tmp/tmpvid.mp4" -i "$ODIR/tmp/${ts0[0]}.trans.m4a" \
				-map 0:v:0 -map 1:a:0 -shortest "$ODIR/tmp/tmpvid2.mp4" &> /dev/null
			# Crop second part of video
			ffmpeg -y -ss $(echo "${ts0[0]}+$lena" | bc) -t $(echo "$lenv-$lena" | bc) \
				-i "$ODIR/old.mp4" "$ODIR/tmp/tmpvid3.mp4" &> /dev/null
			# Concatenate as specified with filter
			ffmpeg -y -i "$ODIR/new.mp4" -i "$ODIR/tmp/tmpvid2.mp4" -i "$ODIR/tmp/tmpvid3.mp4" \
				-filter_complex "[0:v:0][0:a:0][1:v:0][1:a:0][2:v:0][2:a:0]concat=n=3:v=1:a=1[outv][outa]" \
				-map "[outv]" -map "[outa]" "$ODIR/newp.mp4" &> /dev/null
			cp "$ODIR/newp.mp4" "$ODIR/new.mp4"
			rm "$ODIR/tmp/tmpvid.mp4"
			rm "$ODIR/tmp/tmpvid2.mp4"
			rm "$ODIR/tmp/tmpvid3.mp4"
			rm "$ODIR/newp.mp4"
		fi
	fi
done