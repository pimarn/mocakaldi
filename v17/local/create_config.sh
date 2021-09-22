#!/bin/bash

src=$1
dst=$2
trans=$1/trans.txt

[ -d $dst ] && rm -rf $dst
mkdir $dst

#create wav.scp file
wav_scp=$dst/wav.scp
find -L $src/ -iname "*.wav" | sort | xargs -I% basename % .wav | \
      awk -v "dir=$src" '{printf "%s %s/%s.wav\n", $0, dir, $0}' >>$wav_scp || exit 1;

#create text file from transcription
txt=$dst/text
awk '{print $1}' $wav_scp > text.tmp
paste -d" " text.tmp $trans > $txt

#create utt2spk
utt2spk=$dst/utt2spk
while read line
do
        a=`echo $line |awk '{print $1'}`
        b=`echo $a | sed 's/_.*//'`
        echo $a $b >> $utt2spk
done < text.tmp
rm text.tmp

#create spk2utt
spk2utt=$dst/spk2utt
utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt || exit 1


