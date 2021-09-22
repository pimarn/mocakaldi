#!/bin/bash
. ./path.sh || exit 1

train_cmd=run.pl
decode_cmd=run.pl
nj=1       # number of parallel jobs - 1 is perfect for such a small dataset
lm_order=3 # language model order (n-gram quantity) - 1 is enough for digits grammar
stage=0


# Safety mechanism (possible running this script with modified arguments)
. utils/parse_options.sh || exit 1
[[ $# -ge 1 ]] && { echo "Wrong arguments!"; exit 1; }

if [ $stage -le 0 ]; then

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
fi

if [ $stage -le 1 ]; then

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

	[ -d data/lang_nosp ] && rm -rf data/lang_nosp
	./prepare_LG.sh lexicon.txt $local/tmp/lm.arpa phones.txt data/local/dict data/lang_nosp

fi

# Making feats.scp files
mfccdir=mfcc
trainset=train
testset=test

if [ $stage -le 2 ]; then
  # make MFCC features for the test data. Only hires since it's flat-start.
  echo "$0: extracting MFCC features for the test sets"
  for x in $testset; do
    [ -d data/${x}_hires ] && rm -rf data/${x}_hires
	cp -r data/$x data/${x}_hires
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj \
                       --mfcc-config conf/mfcc_hires.conf data/${x}_hires exp/make_mfcc/${x}_hires $mfccdir
    steps/compute_cmvn_stats.sh data/${x}_hires exp/make_mfcc/${x}_hires $mfccdir
  done
fi
if [ $stage -le 3 ]; then
  echo "$0: perturbing the training data to allowed lengths"
  utils/data/get_utt2dur.sh data/$trainset  # necessary for the next command

  # 12 in the following command means the allowed lengths are spaced
  # by 12% change in length.
  utils/data/perturb_speed_to_allowed_lengths.py 12 data/${trainset} \
                                                 data/${trainset}_spe2e_hires
  cat data/${trainset}_spe2e_hires/utt2dur | \
    awk '{print $1 " " substr($1,5)}' >data/${trainset}_spe2e_hires/utt2uniq
  utils/fix_data_dir.sh data/${trainset}_spe2e_hires
fi

if [ $stage -le 4 ]; then
  echo "$0: extracting MFCC features for the training data"
  steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
                     --cmd "$train_cmd" data/${trainset}_spe2e_hires
  steps/compute_cmvn_stats.sh data/${trainset}_spe2e_hires
fi

if [ $stage -le 5 ]; then
  echo "$0: calling the flat-start chain recipe..."
  local/chain/e2e/run_tdnn_flatstart.sh
fi



echo
echo "===== run.sh script is finished ====="
echo
