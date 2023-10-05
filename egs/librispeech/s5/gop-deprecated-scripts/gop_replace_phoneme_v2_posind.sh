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

echo $#
if [ $# -ne 1 ]; then
	echo "Usage: $0 (substitution pair)AA_S" >&2
    exit 1
fi

#fname=AA_S
fname=$1
targetP=$(echo $fname | cut -d'_' -f1)
toP=$(echo $fname | cut -d'_' -f2)
#dictDir=data/local/$fname
#langDir=data/lang_replace/$fname
aliDir=exp/mono_ali_v2_ind/$fname
gopDir=exp/gop_replace_all_v2_ind/$fname

if [ -f $gopDir/gop.score.all.symbol ]; then
	echo "gop file already exists skipped:" $fname
	exit 0
fi
. ./cmd.sh
. ./path.sh
. parse_options.sh

# you might not want to do this for interactive shells.
set -e


if [ $stage -le 2 ]; then
  #align canonical text with the monophone model 
  if [ ! -d exp/ali_mono_align_ctm_ind ];then
  	steps/align_si_gop_ctm.sh  --nj 2 --cmd "$train_cmd" \
                    data/gop_combined data/lang_nosp_ind  exp/mono_all_data_ind exp/ali_mono_align_ctm_ind
  fi
fi


if [ $stage -le 3 ]; then
  #Segment features and prepare other files for aligments
  if [ ! -d data/gop_combined_ind/extracted_segments/$targetP/$toP ];then
	local/extract_newdata_from_ctm.sh exp/ali_mono_align_ctm_ind/all.phonemes.ctm data/lang_nosp_ind data/gop_combined_ind  $targetP $toP
  fi
fi

if [ $stage -le 4 ]; then
  #Align phonemes
  steps/align_si_gop_phonesub.sh  --nj 2 --cmd "$train_cmd" \
                    data/gop_combined_ind/extracted_segments/$targetP/$toP/data-segmented  data/gop_combined_ind/extracted_segments/$targetP/$toP exp/mono_all_data_ind $aliDir
fi

if [ $stage -le 5 ]; then
  #replace the original aligments
  steps/replace_alignment.sh --nj 2 --cmd "$train_cmd" \
      exp/ali_mono_align_ctm_ind $aliDir data/gop_combined_ind/extracted_segments/$targetP/$toP/data-segmented $aliDir
fi

if [ $stage -le 6 ]; then
  #GOP denom HCP gragh, the model is the same as the monophone model for canonical input
  if [ ! -d exp/gop_denominator_ind ];then
        steps/make_gop_mono_graph.sh  data/lang_nosp_ind exp/ali_mono_align_ctm_ind exp/ali_mono_align_ctm_ind  exp/gop_denominator_ind
  fi
fi

if [ $stage -le 7 ]; then
  #GOP score for canonical and modified input
  if [ ! -d exp/gop_denominator_ind/decode ];then
  	steps/decode_gop.sh --config conf/decode.config --nj 2 --cmd "$decode_cmd" exp/ali_mono_align_ctm_ind exp/ali_mono_align_ctm_ind exp/gop_denominator_ind/phone_graph data/gop_combined exp/gop_denominator_ind/decode
  fi

fi

if [ $stage -le 8 ]; then
	steps/compute_gop_modified_ali.sh --nj 2 --cmd "$decode_cmd" $aliDir exp/ali_mono_align_ctm_ind exp/gop_denominator_ind/decode $gopDir
fi


echo "done"
exit 0

