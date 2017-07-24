#!/bin/bash

if [ "$#" = 0 ]; then
	echo "USAGE: $0 <Video Path>"
	exit 1
fi

echo -e "##### Auto-MkvExtract: Start #####\n"
src="$1"
programs="mkvinfo mkvextract"
erromesg="no"

for profile in $programs
do
	which $profile 1>/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo -e "$profile cannot be found."
		erromesg="yes"
	fi
done

if [ "$erromesg" = "yes" ]; then
	echo "$0 is going to stop for the reason that some program elements are missing."
	exit 1
fi

mkvinfo "$src" >./mkvinfo.info

[ -f ./mkvinfo.info ] || (echo -e "Cannot generate Video Track Information."; exit 1;)

eval $(cat ./mkvinfo.info | grep -n "Track number" | cut -d ":" -f 1 | awk '{printf "linenum[%s]=%s;",NR,$0}')
eval $(cat ./mkvinfo.info | grep -n "EbmlVoid" | cut -d ":" -f 1 | awk 'NR==2 {printf "linend=%s",$0}')

num=${#linenum[*]}

[ $num -le 1 ] && (echo -e "Unable to get the right Track number: ${num}."; exit 1;)

for x in $(seq 1 $num)
do
	next=$(($x + 1))
	[ $x -eq $num ] && linecnt[${x}]=$(($linend - ${linenum[${x}]})) && continue

	linecnt[${x}]=$((${linenum[${next}]} - ${linenum[${x}]}))
done

echo -e "Generate Video Mediainfo\n"

for x in $(seq 1 $num)
do
	if [ $x -eq $num ]; then
		end=$(($linend - 1))
	else
		end=$((${linenum[$(($x + 1))]} - 1))
	fi

	head -n $end ./mkvinfo.info | tail -n ${linecnt[$x]} >./temp.info

	[ -f ./temp.info ] || (echo -e "Cannot generate Single Track Information."; exit 1;)

	eval $(cat ./temp.info | grep "Track number" | cut -d " " -f 6 | awk -v idx=$x '{s=$0; s=s-1; printf "Tracknumber[%s]=\"%s\";",idx,s}')
	eval $(cat ./temp.info | grep "Track type" | cut -d " " -f 6 | awk -v idx=$x '{s=$0; printf "TrackType[%s]=\"%s\";",idx,s}')
	eval $(cat ./temp.info | grep "Codec ID" | cut -d " " -f 6 | awk -v idx=$x '{s=$0; printf "Codec[%s]=\"%s\";",idx,s}')
	eval $(cat ./temp.info | grep "Name" | cut -d " " -f 4 --complement | awk -v idx=$x '{s=$0; printf "Name[%s]=\"%s\";",idx,s}')
	eval $(cat ./temp.info | grep "lang" | cut -d " " -f 4 --complement | awk -v idx=$x '{s=$0; printf "lang[%s]=\"%s\";",idx,s}')
done

rm ./mkvinfo.info ./temp.info

videoname=$(basename $src)
videoname=${videoname%.*}

echo -e "##### ${videoname} #####\n"
for x in $(seq 1 $num)
do
	echo "----- Track: ${Tracknumber[$x]} -----"
	echo "Track type: ${TrackType[$x]}"
	echo "Codec ID: ${Codec[$x]}"
	[ -n "${Name[$x]}" ] && echo "Name: ${Name[$x]}"
	[ -n "${lang[$x]}" ] && echo "lang: ${lang[$x]}"
	echo " "
done
echo "##### Input Track Number #####"
declare -a TrackExt
read -a TrackExt

# Codec ID:
VideoFormat=("V_MPEG4/ISO/AVC" "V_MS/VFW/FOURCC" "V_REAL/*" "V_THEORA" "V_VP8" "V_VP9")
VideoExtent=("mp4" "avi" "rm" "ogg" "ivf" "ivf")

AudioFormat=("A_AC3" "A_DTS" "A_MPEG/L2" "A_MPEG/L3" "A_PCM/INT/LIT" "A_AAC/MPEG2/*" " A_AAC/MPEG4/*" "A_AAC" "A_VORBIS" "A_REAL/*" "A_TTA1" "A_ALAC" "A_FLAC" "A_WAVPACK4" "A_OPUS")
AudioExtent=("ac3" "dts" "mp2" "mp3" "wav" "aac" "aac" "aac" "ogg" "rm" "tta" "caf" "flac" "wv" "ogg")

SubFormat=("S_HDMV/PGS" "S_TEXT/UTF8" "S_TEXT/ASS" "S_TEXT/SSA" "S_VOBSUB" "S_TEXT/USF" "S_KATE")
SubExtent=("sup" "srt" "ass" "ssa" "sub" "usf" "ogg")

declare -a ext
for x in ${TrackExt[*]}
do
	idx=$(($x + 1))
	case ${TrackType[$idx]} in
		"video")
		z=$((${#VideoFormat[*]} - 1))
		for y in $(seq 0 $z)
		do
			if (echo ${Codec[$idx]} | grep "${VideoFormat[$y]}") &>/dev/null; then
				ext[$idx]=${VideoExtent[$y]}; break
			fi
		done
		;;
		"audio")
		z=$((${#AudioFormat[*]} -1))
		for y in $(seq 0 $z)
		do
			if (echo "${Codec[$idx]}" | grep "${AudioFormat[$y]}") &>/dev.null; then
				ext[$x]=${AudioExtent[$y]}; break
			fi
		done
		;;
		"subtitles")
		z=$((${#SubFormat[*]} -1))
		for y in $(seq 0 $z)
		do
			if (echo ${Codec[$idx]} | grep "${SubFormat[$y]}") &>/dev/null; then
				ext[$idx]=${SubExtent[$y]}; break
			fi
		done
		;;
		"*")
		echo "Generate ouputfile extention failed."
		exit 1
		;;
	esac
done

[ -f ./option ] && rm ./option
touch ./option
for x in ${TrackExt[*]}
do
	idx=$(($x + 1))
	printf "%s:%s_%s_%s.%s " $x $videoname ${TrackType[$idx]} $x ${ext[$x]} >>./option
done

echo "##### Generated Command #####"
cat ./option | awk -v src=$src '{printf "mkvextract tracks %s %s",src,$0}'
read -p "Continue? Quit with \"no\" or \"No\"." choose

[ "$choose" == "no" ] && exit 1 || [ "$choose" = "NO" ] && exit 1
cat ./option | eval $(awk -v src=$src '{printf "mkvextract tracks %s %s",src,$0}')

[ $? = 0 ] && rm ./option
