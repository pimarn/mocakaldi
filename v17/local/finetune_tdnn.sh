# This script uses weight transfer as a transfer learning method to transfer
# already trained neural net model on aishell2 to a finetune data set.
. ./path.sh
. ./cmd.sh

data_set=finetune
data_dir=data/${data_set}
ali_dir=exp/${data_set}_ali
src_dir=exp/chain/e2e_tdnnf_1a
dir=${src_dir}_${data_set}

num_jobs_initial=1
num_jobs_final=1
num_epochs=5
initial_effective_lrate=0.0005
final_effective_lrate=0.00002
minibatch_size=1024

stage=1
train_stage=-10
nj=4
. ./utils/parse_options.sh

if [ $stage -eq 1 ]; then
  # align new data(finetune set) with GMM, we probably replace GMM with NN later
  steps/make_mfcc_pitch.sh \
    --pitch-config conf/pitch.conf --cmd "$train_cmd" --nj $nj \
    ${data_dir} exp/make_mfcc/${data_set} mfcc
  steps/compute_cmvn_stats.sh ${data_dir} exp/make_mfcc/${data_set} mfcc || exit 1;

  utils/fix_data_dir.sh ${data_dir} || exit 1;
  steps/align_si.sh --cmd "$train_cmd" --nj ${nj} ${data_dir} data/lang exp/tri3b ${ali_dir}

  # extract mfcc_hires for AM finetuning
  #utils/copy_data_dir.sh ${data_dir} ${data_dir}_hires
  #rm -f ${data_dir}_hires/{cmvn.scp,feats.scp}
  #utils/data/perturb_data_dir_volume.sh ${data_dir}_hires || exit 1;
  
  echo "$0: perturbing the training data to allowed lengths"
  #utils/data/get_utt2dur.sh ${data_dir}_hires  # necessary for the next command

  # 12 in the following command means the allowed lengths are spaced
  # by 12% change in length.
  utils/data/perturb_speed_to_allowed_lengths.py 12 ${data_dir} \
                                                 ${data_dir}_hires
  cat ${data_dir}_hires/utt2dur | \
    awk '{print $1 " " substr($1,5)}' >${data_dir}_hires/utt2uniq
  utils/fix_data_dir.sh ${data_dir}_hires


  steps/make_mfcc.sh \
    --cmd "$train_cmd" --nj $nj --mfcc-config conf/mfcc_hires.conf \
    ${data_dir}_hires exp/make_mfcc/${data_set}_hires mfcc_hires
  steps/compute_cmvn_stats.sh ${data_dir}_hires exp/make_mfcc/${data_set}_hires mfcc_hires
fi

if [ $stage -eq 2 ]; then
  $train_cmd $dir/log/generate_input_model.log \
    nnet3-am-copy --raw=true $src_dir/final.mdl $dir/input.raw
fi

if [ $stage -eq 3 ]; then
  steps/nnet3/train_dnn.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --trainer.input-model $dir/input.raw \
    --trainer.num-epochs $num_epochs \
    --trainer.optimization.num-jobs-initial $num_jobs_initial \
    --trainer.optimization.num-jobs-final $num_jobs_final \
    --trainer.optimization.initial-effective-lrate $initial_effective_lrate \
    --trainer.optimization.final-effective-lrate $final_effective_lrate \
    --trainer.optimization.minibatch-size $minibatch_size \
    --feat-dir ${data_dir}_hires \
    --lang data/lang \
    --ali-dir ${ali_dir} \
    --dir $dir || exit 1;
fi
