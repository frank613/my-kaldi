#!/bin/bash

. ./cmd.sh
. ./path.sh

stage=0

#DIRs
alidir=./exp/ali-ctm-teflon-20
si_model_path=./exp/tri2b
lang_path=./data/lang_teflon
#lang_path=./data/lang_nosp
data_path=./data/test-gop-teflon-20
#data_path=./data/test-gop-teflon-new

#prepare the data
if [ $stage -le 0 ]; then
	if [ ! -d $data_path ]; then
		source ~/python-env/wav2vec2/bin/activate
		python ./local/prepare_data_from_tsv.py /talebase/data/speech_raw/teflon_no/assessments.csv $lang_path/phones/align_lexicon.txt ./local/phoneme_ano.maps $data_path
	fi
fi

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
