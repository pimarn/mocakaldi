#!/bin/sh

f=`basename $1`

ngram-count -text $1 -order 3 -lm $f.lm
