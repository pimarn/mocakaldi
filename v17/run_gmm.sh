#!/bin/bash
. ./path.sh || exit 1

train_cmd=run.pl
decode_cmd=run.pl
nj=4      # number of parallel jobs - 1 is perfect for such a small dataset
lm_order=3 # language model order (n-gram quantity) - 1 is enough for digits grammar


# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh || exit 1
[[ $# -ge 1 ]] && { echo "Wrong arguments!"; exit 1; }


# Removing previously created data (from last run.sh execution)
rm -rf exp mfcc data/train/spk2utt data/train/utt2dur data/train/utt2num_frames data/train/frame_shift data/train/cmvn.scp data/train/feats.scp data/train/split1 data/test/spk2utt data/test/utt2dur data/test/utt2num_frames data/test/frame_shift data/test/cmvn.scp data/test/feats.scp data/test/split1 data/local/lang data/lang data/local/tmp data/local/dict/lexiconp.txt data/local/dict


echo
echo "===== PREPARING ACOUSTIC DATA ====="
echo
# Needs to be prepared by hand (or using self written scripts):
#
# spk2gender  [<speaker-id> <gender>]
# wav.scp     [<uterranceID> <full_path_to_audio_file>]
# text        [<uterranceID> <text_transcription>]
# utt2spk     [<uterranceID> <speakerID>]
# corpus.txt  [<text_transcription>]
# Making spk2utt files
utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt

echo
echo "===== FEATURES EXTRACTION ====="
echo
# Making feats.scp files
mfccdir=mfcc
# Uncomment and modify arguments in scripts below if you have any problems with data sorting
# utils/validate_data_dir.sh data/train     # script for checking prepared data - here: for data/train directory
# utils/fix_data_dir.sh data/train          # tool for data proper sorting if needed - here: for data/train directory
steps/make_mfcc_pitch.sh --nj $nj --cmd "$train_cmd" data/train exp/make_mfcc/train $mfccdir || exit 1
steps/make_mfcc_pitch.sh --nj $nj --cmd "$train_cmd" data/test exp/make_mfcc/test $mfccdir  || exit 1
# Making cmvn.scp files
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir
steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir


echo "===== PREPARING LANGUAGE DATA ====="
echo
# Needs to be prepared by hand (or using self written scripts):
#
# lexicon.txt           [<word> <phone 1> <phone 2> ...]
# nonsilence_phones.txt [<phone>]
# silence_phones.txt    [<phone>]
# optional_silence.txt  [<phone>]
# Preparing language data
#utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
#utils/prepare_lang.sh data/local/dict "<SIL>" data/local/lang data/lang
echo
echo "===== LANGUAGE MODEL CREATION ====="
echo "===== MAKING lm.arpa ====="
echo
loc=`which ngram-count`;
if [ -z $loc ]; then
        if uname -a | grep 64 >/dev/null; then
                sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64
        else
                        sdir=$KALDI_ROOT/tools/srilm/bin/i686
        fi
        if [ -f $sdir/ngram-count ]; then
                        echo "Using SRILM language modelling tool from $sdir"
                        export PATH=$PATH:$sdir
        else
                        echo "SRILM toolkit is probably not installed.
                                Instructions: tools/install_srilm.sh"
                        exit 1
        fi
fi
local=data/local
mkdir $local/tmp
ngram-count -order $lm_order -write-vocab $local/tmp/vocab-full.txt -wbdiscount -text $local/corpus.txt -lm $local/tmp/lm.arpa

./prepare_LG.sh lexicon.src $local/tmp/lm.arpa phones.txt data/local/dict data/lang

echo
echo "===== MONO TRAINING ====="
echo
# Train monophone models on a subset of the data
utils/subset_data_dir.sh data/train 1000 data/train.1k  || exit 1;
#steps/train_mono.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/mono  || exit 1
steps/train_mono.sh --boost-silence 1.25 --nj $nj --cmd "$train_cmd" data/train.1k data/lang exp/mono  || exit 1
echo
echo "===== MONO DECODING ====="
echo
utils/mkgraph.sh --mono data/lang exp/mono exp/mono/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/mono/graph data/test exp/mono/decode
echo "Done MONO"

echo
echo "===== MONO ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/mono exp/mono_ali || exit 1
echo
echo "===== TRI1 (first triphone pass) TRAINING ====="
echo
steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/lang exp/mono_ali exp/tri1 || exit 1
#steps/train_deltas.sh --cmd "$train_cmd" 1800 9000 data/train data/lang exp/mono_ali exp/tri1 || exit 1


echo "===== TRI1 DECODING ====="
echo
utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph || exit 1
steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri1/graph data/test exp/tri1/decode


echo
echo "===== TRI1 ALIGNMENT ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" --use-graphs true data/train data/lang exp/tri1 exp/tri1_ali || exit 1
echo
echo
echo "===== Train delta + delta-delta triphones ====="
echo
#steps/train_deltas.sh --cmd "$train_cmd" 2500 15000 data/train data/lang exp/tri1_ali exp/tri2a || exit 1;
steps/train_deltas.sh --cmd "$train_cmd" 2000 11000 data/train data/lang exp/tri1_ali exp/tri2a || exit 1;
echo
echo
echo "===== Align delta + delta-delta triphones ====="
echo
steps/align_si.sh --nj $nj --cmd "$train_cmd" --use-graphs true data/train data/lang exp/tri2a exp/tri2a_ali  || exit 1;
echo
echo
echo "===== Train LDA-MLLT triphones ====="
echo
#steps/train_lda_mllt.sh --cmd "$train_cmd" 3500 20000 data/train data/lang exp/tri1_ali exp/tri2b || exit 1;
steps/train_lda_mllt.sh --cmd "$train_cmd" 2000 11000 data/train data/lang exp/tri1_ali exp/tri2b || exit 1;

steps/align_si.sh --nj $nj --cmd "$train_cmd" --use-graphs true data/train data/lang exp/tri2b exp/tri2b_ali  || exit 1;
#echo
#echo "===== Align LDA-MLLT triphones with FMLLR ====="
#echo
#steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" data/train data/lang exp/tri3a exp/tri3a_ali || exit 1;
#echo
#echo "===== TRI1 (first triphone pass) DECODING ====="
#echo
#utils/mkgraph.sh data/lang exp/tri3a exp/tri3a/graph || exit 1
#steps/decode.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3a/graph data/test exp/tri3a/decode

echo
echo "===== Train SAT triphones ====="
echo
#steps/train_sat.sh  --cmd "$train_cmd" 4200 40000 data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
steps/train_sat.sh  --cmd "$train_cmd" 2000 110000 data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;

echo
echo "===== SAT DECODING ====="
echo
utils/mkgraph.sh data/lang exp/tri3b exp/tri3b/graph || exit 1
steps/decode_fmllr.sh --config conf/decode.config --nj $nj --cmd "$decode_cmd" exp/tri3b/graph data/test exp/tri3b/decode
echo
echo "===== run.sh script is finished ====="
echo
