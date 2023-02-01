#!/usr/bin/env bash
#set -x

# Set this to somewhere where you want to put your data, or where
# someone else has already put it.  You'll want to change this
# if you're not on the CLSP grid.
data=/localhome/stipendiater/xinweic/data/libri

# base url for downloads.
data_url=www.openslr.org/resources/12
lm_url=www.openslr.org/resources/11
mfccdir=mfcc
stage=0



. ./cmd.sh
. ./path.sh
. parse_options.sh

# you might not want to do this for interactive shells.
set -e


if [ $stage -le 0 ]; then
  #align canonical text with the monophone model 
  if [ ! -d exp/align_gop_nnet ];then
  	steps/align_si_gop_nnet2.sh --cmd "$train_cmd" \
                    data/gop_combined data/lang_nosp  exp/mono_all_data exp/align_gop_nnet
  fi
fi



if [ $stage -le 1 ]; then
  #GOP score using nnet2 for likeRatio 
  #if [ ! -d exp/gop_nnet2_likeRatio/ ];then
  	steps/gop-nnet2-likeRatio.sh  exp/nnet5a_clean_100_gpu exp/align_gop_nnet data/gop_combined exp/gop_nnet2_likeRatio
  #fi

fi



echo "done"
exit 0

