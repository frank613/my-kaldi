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


if [ $stage -le 2 ]; then
  #align canonical text with the monophone model 
  if [ ! -d exp/ali_mono_align_ctm ];then
  	steps/align_si_gop_ctm.sh  --nj 2 --cmd "$train_cmd" \
                    data/gop_combined data/lang_nosp  exp/mono_all_data exp/ali_mono_align_ctm
  fi
fi



if [ $stage -le 6 ]; then
  #GOP denom HCP gragh, the model is the same as the monophone model for canonical input
  if [ ! -d exp/gop_denominator ];then
        steps/make_gop_mono_graph.sh  data/lang_nosp exp/ali_mono_align exp/ali_mono_align  exp/gop_denominator
  fi
fi

if [ $stage -le 7 ]; then
  #GOP score for canonical and modified input
  if [ ! -d exp/gop_denominator/decode-mod ];then
  	steps/decode_gop.sh --config conf/decode.config --nj 2 --cmd "$decode_cmd" exp/ali_mono_align exp/ali_mono_align exp/gop_denominator/phone_graph data/gop_combined exp/gop_denominator/decode-mod
  fi

fi



echo "done"
exit 0

