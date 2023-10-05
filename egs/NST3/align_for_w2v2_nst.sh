#!/bin/bash

. ./cmd.sh
. ./path.sh

stage=2

#DIRs
alidir=./exp/ali-ctm-NST-train20
si_model_path=./exp/tri2b
lang_path=./data/lang_teflon
#lang_path=./data/lang_nosp
data_path=./data/train_20
#data_path=./data/test-gop-teflon-new


#prepare the features
if [ $stage -le 1 ]; then
	steps/make_mfcc.sh --nj 12 --cmd run.pl --mfcc-config conf/mfcc_16k_20ms.conf $data_path
	steps/compute_cmvn_stats.sh $data_path
fi

# Align with si triphone model
if [ $stage -le 2 ]; then
        if [ ! -d $alidir ]; then
                steps/align_si_gop_ctm.sh --nj 1 --cmd "$train_cmd" $data_path $lang_path $si_model_path $alidir
        fi
fi

echo "done"
exit 0
