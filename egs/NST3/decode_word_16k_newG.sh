#!/bin/bash

. ./cmd.sh
. ./path.sh

stage=4

#DIRs
decode_fmllr_dir=./exp/decode16-newG-word-tri3b-teflon
si_model_path=./exp/tri2b/
sd_model_path=./exp/tri3b/
lang_path=./data/lang_teflon_customG
data_path=./data/test-gop-teflon-16k

#prepare the data
if [ $stage -le 0 ]; then
	if [ ! -d $data_path ]; then
		source ~/python-env/wav2vec2/bin/activate
		python ./local/prepare_data_from_tsv_16k.py /talebase/data/speech_raw/teflon_no/assessments.csv $lang_path/phones/align_lexicon.txt ./local/phoneme_ano.maps $data_path
	fi
fi


#prepare the features
if [ $stage -le 1 ]; then
	steps/make_mfcc.sh --nj 12 --cmd run.pl --mfcc-config conf/mfcc_16k.conf $data_path
	steps/compute_cmvn_stats.sh $data_path
fi


if [ $stage -le 4 ]; then
  if [ ! -d ${decode_fmllr_dir}/graph ];then
	utils/mkgraph.sh $lang_path $sd_model_path ${decode_fmllr_dir}/graph || exit 1;
  fi
fi

if [ $stage -le 5 ]; then
  if [ ! -d $decode_fmllr_dir/decode ];then
	
        steps/decode_fmllr.sh  --nj 1 --cmd "$decode_cmd" $decode_fmllr_dir/graph $data_path  $decode_fmllr_dir/decode
  fi
fi

echo "done"
exit 0
