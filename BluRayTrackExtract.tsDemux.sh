#!/bin/bash
# Program:			Demuxing tracks from Blu-Ray via tsmuxeR
# Usage:			"demux_auto.sh <Blu-Ray's playlist file name>"
# Version History:	v0.0.0 first version 2017-03-17 11:10:09
# Autor Info:		failedhero(failedhero@live.cn)
# Create Time:		2017-03-17 11:11:08

message_output()
{
	printf '\n############### %-8s ###############\n' $1
	for i in $(seq 2 $#)
	do
		eval tmp=\$$i
		echo $tmp
	done
	printf "#########################################\n"
}

# [ $# -eq 2 ] || [ $# -eq 1 ] && OUTPUT=$(pwd) || { printf "\tUSAGE: $0 <playlist path> <output path>\n"; exit 3; }
[ $# -eq 2 ] || [ $# -eq 1 ] && OUTPUT=$(pwd) || { message_output "USAGE:" "$0 <playlist path> <output path>"; exit 3; }

CURPATH=$(pwd)
TOOLPATH=$(dirname $0)
TOOLPATH="${CURPATH}/${TOOLPATH}"
PLALIST=$1
OUTPUT=$2
DAEMON="${TOOLPATH}/tsMuxeR.exe"
PATH=$PATH:$TOOLPATH
export PATH

# check the Envorinment
# [ -f $PLALIST ] && [ -r $PLALIST ] || { echo "$PLALIST don't exitst. Please check."; exit 1; }
# [ -e $DAEMON ] || { echo "$DAEMON don't exitst. Please check."; exit 1; }
[ -f $PLALIST ] && [ -r $PLALIST ] || { message_output "ERROR:" "$PLALIST don't exitst. Please check."; exit 1; }
[ -e $DAEMON ] || { message_output "ERROR:" "$DAEMON don't exitst. Please check."; exit 1; }

# read the Blu-Ray mediainfo from input playlist file
message_output "Progress:" "Start Read the Blu-Ray information from ${PLALIST}"
FILENAME=$(basename $PLALIST)
MEDINFO="${TOOLPATH}/${FILENAME%.*}.info"

type wine &>/dev/null || { message_output "ERROR:" "Please check if \"wine\" is already installed."; exit 1; }
wine "${DAEMON}" $PLALIST 2>/dev/null 1>${MEDINFO}
type dos2unix &>/dev/null || { message_output "ERROR:" "Please check if \"dos2unix\" is already installed."; exit 1; }
dos2unix $MEDINFO &>/dev/null

message_output "Progress:" "Read Finished, Savedpath: ${MEDINFO}"

# process the mediainfo and print the track information
TRACKCNT=$(grep -c "Track ID:" $MEDINFO)
[ $TRACKCNT = 0 ] && { message_output "ERROR:" "Track information search failed."; exit 1; }

eval $(grep "Track ID:" $MEDINFO | awk 'BEGIN {i=1} {gsub(/Track ID: +| +$/,"",$0)} {gsub(/ +/," ",$0)} {printf "TRACKID[%s]=\"%d\";",i,$0 ;i=i+1}')
eval $(grep "Stream ID:" $MEDINFO | awk 'BEGIN {i=1} {gsub(/Stream ID: +| +$/,"",$0)} {gsub(/ +/," ",$0)} {printf "STREAMID[%s]=\"%s\";",i,$0 ;i=i+1}')
eval $(grep "Stream lang:" $MEDINFO | awk 'BEGIN {i=1} {gsub(/Stream lang: +| +$/,"",$0)} {gsub(/ +/," ",$0)} {printf "STREAMLANG[%s]=\"%s\";",i,$0 ;i=i+1}')
eval $(grep "Stream info:" $MEDINFO | awk 'BEGIN {i=1} {gsub(/Stream info: +| +$/,"",$0)} {gsub(/ +/," ",$0)} {printf "STREAMINFO[%s]=\"%s\";",i,$0 ;i=i+1}')
eval $(grep "Stream lang:" $MEDINFO | awk 'BEGIN {i=1} {gsub(/Stream lang: +| +$/,"",$0)} {gsub(/ +/," ",$0)} {printf "STREAMLANG[%s]=\"%s\";",i,$0 ;i=i+1}')

printf '\n############### %-8s ###############\n' "TrackID:"

for i in $(seq 1 $TRACKCNT)
do
	echo "No." ${i} in $TRACKCNT
	echo -e "Track ID:\t${TRACKID[i]}\nStream type:\t${STREAMID[i]}\nStream info:\t${STREAMINFO[i]}\nSteam lang:\t${STREAMLANG[i]}"
	echo -e "\n----------------------------->\t"
	read -p "Continue? " ANSWER
	case $ANSWER in
		no|NO)
			break
			;;
		*)
			;;
	esac
done

printf "#########################################\n"

FPS=${STREAMINFO[1]#*Frame rate:}
FPS=$(echo $FPS | sed 's/\ //g')
STARTTIME=$(grep "start-time:" $MEDINFO | awk 'BEGIN {FS=":"} {gsub(/^ +| +$/,"",$2)} {print $2}')
STREAMFILE=$(grep "File * name=" $MEDINFO | awk 'BEGIN {FS="="} {gsub(/^ +| +$/,"",$2)} {print $2}')
STREAMFILE=$(echo ${STREAMFILE} | sed 's/\\/\//g');
STREAMFILE="${CURPATH}/${STREAMFILE}"

message_output "Progress:" "Choose the track for demuxing from followed tracks:\n"
for i in $(seq 1 $TRACKCNT)
do
	printf '%s%-3d%-15s%-6d%-15s%-s\n' "No." ${i} "Track ID:" "${TRACKID[i]}" "Stream ID:" "${STREAMID[i]}"
done

TMPANW="yes"
declare -i DEMUXTRACKCNT
declare -i TMPID
DEMUXTRACKCNT=0

until [ ${TMPANW} = "no" -o ${TMPANW} = "NO" ]
do
	echo -e "\n----------------------------->\t"	
	read -p "Input the Number of the index: (1-${TRACKCNT},finish with input of \"no\" or \"NO\") " TMPANW
	TMPID=${TMPANW}

	if [ ${TMPANW} = "no" -o ${TMPANW} = "NO" ]; then
		break;
	fi

	test $TMPID -ge 1 && test $TMPID -le $TRACKCNT && DEMUXTRACKCNT=$(($DEMUXTRACKCNT+1));DEMUXID[DEMUXTRACKCNT]=$TMPID || echo -e "${TMPANW} is out of range. Please input again."
done

[ $DEMUXTRACKCNT -ge 1 ] || { message_output "ERROR:" "There is no track choosed."; exit 3; }

FILENAME=$(basename $PLALIST)
METAFILE="${CURPATH}/${FILENAME%.*}.meta"
$(touch $METAFILE) && { test -w $METAFILE || { message_output "ERROR:" "$METAFILE do not have write permission. Please check."; exit 1; }; } || { echo "$METAFILE can't be created. Please check."; exit 1; }

echo -e "MUXOPT --no-pcr-on-video-pid --new-audio-pes --demux --vbr  --vbv-len=500 --start-time=${STARTTIME}\n" >$METAFILE
for i in $(seq 1 $DEMUXTRACKCNT)
do
	if echo ${STREAMID[${DEMUXID[i]}]} | grep -q "S_" ; then
		echo -e "${STREAMID[${DEMUXID[i]}]}, \"${PLALIST}\", fsp=${FPS}, track=${TRACKID[${DEMUXID[i]}]}, lang=${STREAMLANG[${DEMUXID[i]}]}\n" >>$METAFILE
	elif echo ${STREAMID[${DEMUXID[i]}]} | grep -q "A_" ; then
		echo -e "${STREAMID[${DEMUXID[i]}]}, \"${PLALIST}\", track=${TRACKID[${DEMUXID[i]}]}, lang=${STREAMLANG[${DEMUXID[i]}]}\n" >>$METAFILE
	elif echo ${STREAMID[${DEMUXID[i]}]} | grep -q "V_" ; then
		echo -e "${STREAMID[${DEMUXID[i]}]}, \"${PLALIST}\", insertSEI, contSPS, track=${TRACKID[${DEMUXID[i]}]}\n" >>$METAFILE
	fi
done

message_output "MetaFile:" "Generated Meta File as following:"

cat $METAFILE

printf "#########################################\n\n"

read -p "Please check the generated meta file. Print \"ok\" or \"OK\" to continue: " TMPANW

if [ -n $TMPANW -a $TMPANW = "no" -o $TMPANW = "NO" ]; then
	exit 3
fi

wine "${DAEMON}" "${METAFILE}" "${OUTPUT}" | awk ' {if($2 ~ /.*complete.*/){printf "\r%-6s %-10s",$1,"complete";}else{print $0;}}'

exit 0


