#!/bin/bash

affix=1a
stage=5

lang=data/lang_e2e
treedir=exp/chain/e2e_tree  # it's actually just a trivial tree (no tree building)
dir=exp/chain/e2e_tdnnf_${affix}
#test_sets="dev-goo"
#test_sets="test-moca"
#test_sets="filter2"
test_sets="test-clean"
#test_sets="test-new"
#test_sets="test"
#test_sets="test-lotus-base"
train_cmd=run.pl
decode_cmd=run.pl
nj=1
lang_test=data/lang-king
graph_dir=graph_own

frames_per_chunk=150
rm $dir/.error 2>/dev/null || true
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if [ $stage -eq 0 ]; then

  # make MFCC features for the test data. Only hires since it's flat-start.
  echo "$0: extracting MFCC features for the test sets"
  for x in $test_sets; do
    [ -d data/${x}_hires ] && rm -rf data/${x}_hires
        cp -r data/$x data/${x}_hires
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj \
                       --mfcc-config conf/mfcc_hires.conf data/${x}_hires exp/make_mfcc/${x}_hires $mfccdir
    steps/compute_cmvn_stats.sh data/${x}_hires exp/make_mfcc/${x}_hires $mfccdir
  done
fi

if [ $stage -eq 4 ]; then
  # The reason we are using data/lang here, instead of $lang, is just to
  # emphasize that it's not actually important to give mkgraph.sh the
  # lang directory with the matched topology (since it gets the
  # topology file from the model).  So you could give it a different
  # lang directory, one that contained a wordlist and LM of your choice,
  # as long as phones.txt was compatible.

  utils/lang/check_phones_compatible.sh \
    $lang_test/phones.txt $lang/phones.txt
  utils/mkgraph.sh \
    --self-loop-scale 1.0 $lang_test \
    $dir $treedir/$graph_dir || exit 1;
fi

if [ $stage -eq 5 ]; then
  echo "$0: decoding data from test sets"
  for data in $test_sets; do
    (
      data_affix=$(echo $data | sed s/test_//)
      nspk=$(wc -l <data/${data}_hires/spk2utt)
      #for lmtype in tgpr; do
      #lmtype=tgpr
      lmtype=own
        steps/nnet3/decode.sh \
          --acwt 1.0 --post-decode-acwt 10.0 \
          --extra-left-context-initial 0 \
          --extra-right-context-final 0 \
          --frames-per-chunk $frames_per_chunk \
	  --beam 10 \
          --nj $nspk --cmd "$decode_cmd"  --num-threads 4 \
          $treedir/graph_${lmtype} data/${data}_hires ${dir}/decode_${lmtype}_${data_affix} || exit 1
          #$treedir/graph_king data/${data}_hires ${dir}/decode_${lmtype}_${data_affix} || exit 1
      #done
        steps/nnet3/decode.sh \
          --acwt 1.0 --post-decode-acwt 10.0 \
          --extra-left-context-initial 0 \
          --extra-right-context-final 0 \
          --frames-per-chunk $frames_per_chunk \
	  --beam 15 \
          --nj $nspk --cmd "$decode_cmd"  --num-threads 4 \
          $treedir/graph_${lmtype} data/${data}_hires ${dir}/decode_${lmtype}_${data_affix}_1 || exit 1
        steps/nnet3/decode.sh \
          --acwt 1.0 --post-decode-acwt 10.0 \
          --extra-left-context-initial 3 \
          --extra-right-context-final 0 \
          --frames-per-chunk 100 \
	  --beam 15 \
          --nj $nspk --cmd "$decode_cmd"  --num-threads 4 \
          $treedir/graph_${lmtype} data/${data}_hires ${dir}/decode_${lmtype}_${data_affix}_2 || exit 1

      #steps/lmrescore.sh \
      #  --self-loop-scale 1.0 \
      #  --cmd "$decode_cmd" data/lang_nosp_test_{tgpr,tg} \
      #  data/${data}_hires ${dir}/decode_{tgpr,tg}_${data_affix} || exit 1


    ) || touch $dir/.error 
  done
fi

echo "$0: Done"

