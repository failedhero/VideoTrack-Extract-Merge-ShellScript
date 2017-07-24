#!/bin/bash
toolpath=/home/deluge/rtorrent/download/tools
generaltxt=$toolpath/HDB-General.txt
videotxt=$toolpath/HDB-Video.txt
audiotxt=$toolpath/HDB-Audio.txt
txttxt=$toolpath/HDB-Text.txt
videopath=$1

general=$(mediainfo --Inform="General;file://$generaltxt" $videopath)
video=$(mediainfo --Inform="Video;file://$videotxt" $videopath)
audio=$(mediainfo --Inform="Audio;file://$audiotxt" $videopath)
txt=$(mediainfo --Inform="Text;file://$txttxt" $videopath)

echo "$general"
echo "$video"
echo "$audio"
echo "$txt"
