#!/usr/bin/env bash

. ./path.sh || exit 1

lm_order=3 # language model order (n-gram quantity) - 1 is enough for digits grammar
stage=0
affix=1a

lmdir=data/local/newlm
dir=exp/chain/e2e_tdnnf_${affix}
corpus=$1

. utils/parse_options.sh || exit 1

###############################
# Create new ARPA and update LM
###############################

if [ $stage -eq 0 ]; then
echo "Update new LM"
test ! -d $lmdir && mkdir -p $lmdir 
#sort -u $corpus > $lmdir/corpus.txt 
cp $corpus $lmdir/corpus.txt 
awk '{for (i=1;i<=NF;i++) printf ("%s\n",$i)}' $lmdir/corpus.txt | sort -u > $lmdir/wordlist

# Create new ARPA LM
#ngram-count -text $lmdir/corpus.txt -order 3 -limit-vocab -vocab $lmdir/wordlist -unk \
#  -map-unk "<unk>" -kndiscount -interpolate -lm $lmdir/srilm.o3g.kn.gz

ngram-count -text $lmdir/corpus.txt -order 3 -vocab $lmdir/wordlist \
  -wbdiscount -lm $lmdir/srilm.o3g.kn.gz

# Use different LM

dict_dir=data/local/dict                # The dict directory provided by the online-nnet2 models
lm=${lmdir}/srilm.o3g.kn.gz                      # ARPA format LM you just built.
lang=data/lang                          # Old lang directory provided by the online-nnet2 models
lang_new=data/lang_new                  # Lang directory after update new vocab
lang_own=data/lang_own                  # New lang directory we are going to create, which contains the new language model
model_dir=$dir

if [ -d $lang_new ]; then
   utils/format_lm.sh $lang_new $lm $dict_dir/lexicon.txt $lang_own
   rm -rf $lang_new
else
   utils/format_lm.sh $lang $lm $dict_dir/lexicon.txt $lang_own
fi
graph_own_dir=exp/chain/e2e_tree/graph_own

utils/mkgraph.sh $lang_own $model_dir $graph_own_dir || exit 1;

fi

###############################
# Update new vocab to LM
###############################

# Use different Vocab
if [ $stage -eq 1 ]; then

echo "Update vocab"

dict_dir=data/local/dict                # The dict directory provided by the online-nnet2 models
lang_own_tmp=data/local/lang_own_tmp/   # Temporary directory.
lang=data/lang_nosp                          # Old lang directory provided by the online-nnet2 models
lang_new=data/lang_new                  # Lang directory after update new vocab
lang_own=data/lang_own                  # New lang directory we are going to create, which contains the new language model
model_dir=$dir
graph_own_dir=exp/chain/e2e_tree/graph_own
lexicon_raw_nosil=input/lexicon.src

# update lexicon file
(echo '!SIL SIL'; ) |\
cat - $lexicon_raw_nosil | sort | uniq >$dict_dir/lexicon.txt
[ -f $dict_dir/lexiconp.txt ] && rm $dict_dir/lexiconp.txt

utils/prepare_lang.sh \
  --phone-symbol-table $lang/phones.txt \
  $dict_dir "!SIL" $lang_own_tmp $lang_own

cp -rp $lang_own $lang_new
utils/mkgraph.sh $lang_own $model_dir $graph_own_dir || exit 1;

fi

echo "Done."
