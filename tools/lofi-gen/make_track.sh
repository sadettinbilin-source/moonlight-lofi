#!/bin/bash
# make_track.sh NAME SEED KEY BPM PROG  -> out/NAME.m4a (AAC256, -14 LUFS) + out/NAME.mp3
set -e; cd "$(dirname "$0")"; N=$1
python3 lofi_gen.py --seed ${2:-1} --key ${3:-D} --bpm ${4:-80} --prog ${5:-ii-V-I-vi} --out out/$N.wav
F="loudnorm=I=-14:TP=-2:LRA=11,alimiter=limit=0.7:level=false,aresample=44100"
ffmpeg -y -loglevel error -i out/$N.wav -af $F -ar 44100 -c:a aac -b:a 256k out/$N.m4a
ffmpeg -y -loglevel error -i out/$N.wav -af $F -ar 44100 -c:a libmp3lame -b:a 192k out/$N.mp3
