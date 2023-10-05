#!/bin/bash

. ./cmd.sh
. ./path.sh

stage=2

#DIRs
decodedir=./exp/decode-teflon
si_model_path=./exp/tri2b
lang_path=./data/lang_teflon
#lang_path=./data/lang_nosp
data_path=./data/test-gop-teflon

#prepare the data
if [ $stage -le 0 ]; then
	if [ ! -d $data_path ]; then
		source ~/python-env/wav2vec2/bin/activate
		python ./local/prepare_data_from_tsv.py /talebase/data/speech_raw/teflon_no/assessments.csv $lang_path/phones/align_lexicon.txt ./local/phoneme_ano.maps $data_path
	fi
fi



#prepare the features
if [ $stage -le 1 ]; then
	steps/make_mfcc.sh --nj 12 --cmd run.pl --mfcc-config conf/mfcc.conf $data_path
	steps/compute_cmvn_stats.sh $data_path
fi

if [ $stage -le 2 ]; then
  #GOP denom HCP gragh, the model is the same as the monophone model for canonical input
  if [ ! -d $decodedir ];then
        steps/make_gop_graph.sh  $lang_path $si_model_path $si_model_path  $decodedir
  fi
fi

if [ $stage -le 3 ]; then
  if [ ! -d $decodedir/decode ];then
        steps/decode_only_for_gop.sh  --nj 1 --cmd "$decode_cmd" $decodedir/phone_graph $data_path  $decodedir/decode
  fi
fi

echo "done"
exit 0
