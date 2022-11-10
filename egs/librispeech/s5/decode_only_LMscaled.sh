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

deocdeDir=exp/gop_denominator_LMscaled

if [ -f exp/gop_replace_all/$fname/gop.score.all.symbol ]; then
	echo "gop file already exists skipped:" $fname
	exit 0
fi
. ./cmd.sh
. ./path.sh
. parse_options.sh

# you might not want to do this for interactive shells.
set -e



if [ $stage -le 4 ]; then
  #GOP denom HCP gragh, the model is the same as the monophone model for canonical input 
  if [ ! -d $deocdeDir ];then
	steps/make_gop_mono_graph.sh  data/lang_nosp exp/ali_mono_align exp/ali_mono_align  $deocdeDir
  fi
fi

if [ $stage -le 5 ]; then
  #GOP score for canonical and modified input
  if [ ! -d $deocdeDir/decode ];then
  	steps/decode_gop2_LMscaled.sh  --config conf/decode.config --nj 2 --cmd "$decode_cmd" exp/ali_mono_align exp/ali_mono_align $deocdeDir/phone_graph data/gop_combined $deocdeDir/decode
  fi

fi


echo "done"
exit 0

