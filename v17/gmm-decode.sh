#!/bin/bash

train_cmd='run.pl'
decode_cmd='run.pl'
nj=1
mfccdir='mfcc'
#testset=test-go
#testset=test-fin
#testset=test-clean
#testset=test-new
testset=test_lotus

source ./path.sh

echo "Compute MFCC"
steps/make_mfcc_pitch.sh --nj $nj --cmd "$train_cmd" data/$testset exp/make_mfcc/$testset $mfccdir  || exit 1
steps/compute_cmvn_stats.sh data/$testset exp/make_mfcc/$testset $mfccdir

echo "Decoding..."
utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/$testset exp/mono/decode_$testset


utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/$testset exp/tri1/decode_$testset

utils/mkgraph.sh data/lang exp/tri2b exp/tri2b/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri2b/graph data/$testset exp/tri2b/decode_$testset


#utils/mkgraph.sh data/lang exp/tri3b exp/tri3b/graph || exit 1
#steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3b/graph data/$testset exp/tri3b/decode_$testset

utils/mkgraph.sh data/lang exp/tri3b exp/tri3b/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3b/graph data/$testset exp/tri3b/decode_$testset

echo "Done"
