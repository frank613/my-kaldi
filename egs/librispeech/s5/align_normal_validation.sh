#!/usr/bin/env bash


# Set this to somewhere where you want to put your data, or where
# someone else has already put it.  You'll want to change this
# if you're not on the CLSP grid.
data=/localhome/stipendiater/xinweic/data/libri

# base url for downloads.
data_url=www.openslr.org/resources/12
lm_url=www.openslr.org/resources/11
mfccdir=mfcc
stage=16

. ./cmd.sh
. ./path.sh
. parse_options.sh

# you might not want to do this for interactive shells.
set -e


if [ $stage -le 16 ]; then
  if [ ! -d exp/align_valid_normal ];then
        steps/align_si_gop_nnet2.sh --cmd "$train_cmd" \
                     data/dev_clean data/lang_nosp exp/mono_all_data exp/align_valid_normal
  fi	
fi

echo "done with aligning"
exit 0

