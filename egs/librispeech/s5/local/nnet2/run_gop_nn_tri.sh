#!/usr/bin/env bash

# This is p-norm neural net training, with the "fast" script, on top of adapted
# 40-dimensional features.


train_stage=-10
use_gpu=true

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh


if $use_gpu; then
  if ! cuda-compiled; then
    cat <<EOF && exit 1 
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA 
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
  fi
  parallel_opts="--gpu wait"
  num_threads=1
  minibatch_size=512
  dir=exp/nnet_gop_tri
else
  # with just 4 jobs this might be a little slow.
  num_threads=16
  parallel_opts="--num-threads $num_threads" 
  minibatch_size=128
  dir=exp/nnet_gop_tri
fi


if [ ! -f $dir/final.mdl ]; then
  if [[  $(hostname -f) ==  *.clsp.jhu.edu ]]; then 
     # spread the egs over various machines.  will help reduce overload of any
     # one machine.
     utils/create_split_dir.pl /export/b0{1,2,3,4}/$USER/kaldi-data/egs/librispeech/s5/$dir/egs/storage $dir/egs/storage
  fi

  steps/nnet2/train_pnorm_fast.sh --stage $train_stage \
   --samples-per-iter 400000 \
   --parallel-opts "$parallel_opts" \
   --num-threads "$num_threads" \
   --minibatch-size "$minibatch_size" \
   --num-jobs-nnet 1  \
   --initial-learning-rate 0.01 --final-learning-rate 0.001 \
   --num-hidden-layers 4 \
   --pnorm-input-dim 2000 --pnorm-output-dim 400 \
   --cmd "$decode_cmd" \
    data/train_clean_100 data/lang_nosp exp/tri_all_data $dir || exit 1
fi


exit 0;

