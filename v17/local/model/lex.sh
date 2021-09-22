#!/bin/bash

#g2p.py --model model-5 --encoding UTF-8 --apply $1 > g2plex.txt

echo "<SIL> SIL" > $1.lex
echo "<UNK> SPN" >> $1.lex
g2p.py --model model-5 --encoding UTF-8 --apply $1 >> $1.lex
