#!/bin/sh

cut -d " " -f 2- $1
#awk '{for (i=2;i<=NF;i++) printf ("%s\n",$i)}' $1
