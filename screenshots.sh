#!/bin/bash
file=$1
times=$(($2 + 1))
x=1
duration=$(ffmpeg -i "$1" 2>&1 | grep 'Duration' | cut -d ' ' -f 4 | sed s/,// | awk 'BEGIN {FS=":"} {time=$1*3600+$2*60+$3;print time}')
duration=$(echo "$duration / $times" | bc -l)
while [ $x -lt $times ];
do
ffmpeg -ss $(echo "$x * $duration" | bc -l) -i "$file" -an -vframes 1 -f image2 images$(echo "$x").png;
x=$(( $x + 1 ))
done
chmod 644 *.png
