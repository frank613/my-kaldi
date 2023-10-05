#!/bin/bash

. ./cmd.sh
. ./path.sh

stage=5

#DIRs
decode_dir=./exp/decode-word-teflon
decode_fmllr_dir=./exp/decode-word-tri3b-teflon
decode_fmllr_dir2=./exp/decode-word-tri4b-teflon
si_model_path=./exp/tri2b/
sd_model_path=./exp/tri3b/
sd_model_path2=./exp/tri4b/
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
  #make HCLG gragh, because we added some OOVs
  if [ ! -d ${decode_dir}/graph ];then
	utils/mkgraph.sh $lang_path $si_model_path ${decode_dir}/graph || exit 1;
  fi
fi

if [ $stage -le 3 ]; then
  if [ ! -d $decodedir/decode ];then
	
        steps/decode.sh  --nj 1 --cmd "$decode_cmd" $decode_dir/graph $data_path  $decode_dir/decode
  fi
fi


if [ $stage -le 4 ]; then
  if [ ! -d ${decode_fmllr_dir2}/graph ];then
	utils/mkgraph.sh $lang_path $sd_model_path2 ${decode_fmllr_dir2}/graph || exit 1;
  fi
fi

if [ $stage -le 5 ]; then
  if [ ! -d $decode_fmllr_dir2/decode ];then
	
        steps/decode_fmllr.sh  --nj 1 --cmd "$decode_cmd" $decode_fmllr_dir2/graph $data_path  $decode_fmllr_dir2/decode
  fi
fi

echo "done"
exit 0
