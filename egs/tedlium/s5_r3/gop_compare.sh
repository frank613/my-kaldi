#!/usr/bin/env bash
#
# Based mostly on the Switchboard recipe. The training database is TED-LIUM,
# it consists of TED talks with cleaned automatic transcripts:
#
# https://lium.univ-lemans.fr/ted-lium3/
# http://www.openslr.org/resources (Mirror).
#
# The data is distributed under 'Creative Commons BY-NC-ND 3.0' license,
# which allow free non-commercial use, while only a citation is required.
#
# Copyright  2014  Nickolay V. Shmyrev
#            2014  Brno University of Technology (Author: Karel Vesely)
#            2016  Vincent Nguyen
#            2016  Johns Hopkins University (Author: Daniel Povey)
#            2018  François Hernandez
#
# Apache 2.0
#

. ./cmd.sh
. ./path.sh


set -e -o pipefail -u

nj=35
decode_nj=38   # note: should not be >38 which is the number of speakers in the dev set
               # after applying --seconds-per-spk-max 180.  We decode with 4 threads, so
               # this will be too many jobs if you're using run.pl.
stage=0
train_rnnlm=false
train_lm=false

. utils/parse_options.sh # accept options

si_model_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/exp/mono_all_data
lang_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/data/lang_nosp

# Data preparation
if [ $stage -le 0 ]; then
  local/download_data.sh
fi

if [ $stage -le 1 ]; then
  local/prepare_data_gop.sh
  # Split speakers up into 3-minute chunks.  This doesn't hurt adaptation, and
  # lets us use more jobs for decoding etc.
  # [we chose 3 minutes because that gives us 38 speakers for the dev data, which is
  #  more than our normal 30 jobs.]
  for dset in train dev test; do
    utils/data/modify_speaker_info.sh --seconds-per-spk-max 180 data/${dset}.orig data/${dset}
  done
fi


# Feature extraction
if [ $stage -le 2 ]; then
  for set in test dev train; do
    dir=data/$set
    steps/make_mfcc.sh --nj 30 --cmd "$train_cmd" $dir
    steps/compute_cmvn_stats.sh $dir
  done
fi

if [ $stage -le 7 ]; then
	  utils/subset_data_dir.sh --shortest data/train 10000 data/gop_10kshort_dup
	    utils/data/remove_dup_utts.sh 10 data/gop_10kshort_dup data/gop_10kshort
    fi

echo "done with data preparation"


# Align with si model
if [ $stage -le 3 ]; then
        if [ ! -d exp/ali_ctm ];then
                steps/align_si_gop_ctm.sh --nj 1 --cmd "$train_cmd" data/gop_10kshort $lang_path $si_model_path exp/gop_ali_ctm
        fi
fi

# Denominator
if [ $stage -le 4 ]; then
  #make phoneme-level graph HCP - no L.fst is needed
  if [ ! -d exp/gop_denominator ];then
        steps/make_gop_mono_graph.sh $lang_path exp/gop_ali_ctm exp/gop_ali_ctm exp/gop_denominator
  fi
fi

if [ $stage -le 5 ]; then
  # Phone-level decode and get the best path with its scores per frame
  if [ ! -d exp/gop_denominator/decode ];then
        steps/decode_gop.sh --nj 1 --cmd "$decode_cmd" exp/gop_ali_ctm exp/gop_ali_ctm exp/gop_denominator/phone_graph data/gop_10kshort exp/gop_denominator/decode
  fi
fi

echo "done"
