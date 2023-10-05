#! /bin/bash

# Copyright Johns Hopkins University
#   2019 Fei Wu

set -eo

stage=0
cmu_kids=/talebase/data/speech_raw/cmu_kids_v2               # path to cmu_kids corpus
cslu_kids=/talebase/data/speech_raw/CSLU_Kids/cslu_kids              # path to cslu_kids corpus
lm_src=                 # path of existing librispeech lm 
extra_features=false    # Extra features for GMM model (MMI, boosting and MPE)
vtln=false              # Optional, run VLTN on gmm and tdnnf models if set true 
email=                  # Reporting email for tdnn-f training
#sd_model_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/exp/tri4b
#si_model_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/exp/mono_ali_5k
si_model_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/exp/mono_all_data_30
lang_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/data/lang_nosp
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

lm_url=www.openslr.org/resources/11
mkdir -p data
mkdir -p data/local


#Alignment
if [ $stage -le 0 ]; then
  if [ ! -d exp/align_mono_30 ];then
	steps/align_si_gop_ctm.sh --nj 1 --cmd "$train_cmd" data_30/data_cmu_gop/test $lang_path $si_model_path exp/ali_mono_30
  fi
fi

# Denominator
if [ $stage -le 1 ]; then
  #make phoneme-level graph HCP - no L.fst is needed
  steps/make_gop_mono_graph.sh $lang_path exp/ali_mono_30 exp/ali_mono_30 exp/gop_gmm_30/
fi

if [ $stage -le 2 ]; then
  # Phone-level decode and get the best path with its scores per frame
  #steps/decode_gop.sh --config conf/decode.config --nj 2 --cmd "$decode_cmd" exp/gop_ali_si exp/gop_ali_sat exp/gop_denominator/phone_graph data/data_cmu_gop/test exp/gop_denominator/decode
  steps/decode_gop.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" exp/ali_mono_30 exp/ali_mono_30  exp/gop_gmm_30/phone_graph data_30/data_cmu_gop/test exp/gop_gmm_30/decode
fi

echo "done"
exit 0
