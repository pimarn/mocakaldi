#!/bin/sh

tmp=$1.tmp
out=$1.lex
mdir=local/model

. ./path.sh

sort -u $1 > $tmp.sorted

awk '{for (i=1;i<=NF;i++) printf ("%s\n",$i)}' $tmp.sorted | sort -u > $tmp
rm $tmp.sorted 

#echo "<SIL> SIL" > $out
#echo "<UNK> SPN" >> $out
g2p.py --model $mdir/model-5 --encoding UTF-8 --apply $tmp >> $out

rm $tmp

