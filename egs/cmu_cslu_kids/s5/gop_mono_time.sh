#! /bin/bash

# Copyright Johns Hopkins University
#   2019 Fei Wu

set -eo

stage=4
cmu_kids=/talebase/data/speech_raw/cmu_kids_v2               # path to cmu_kids corpus
cslu_kids=/talebase/data/speech_raw/CSLU_Kids/cslu_kids              # path to cslu_kids corpus
lm_src=                 # path of existing librispeech lm 
extra_features=false    # Extra features for GMM model (MMI, boosting and MPE)
vtln=false              # Optional, run VLTN on gmm and tdnnf models if set true 
email=                  # Reporting email for tdnn-f training
#sd_model_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/exp/tri4b
si_model_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/exp/mono_ali_5k
lang_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/data/lang_nosp
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

lm_url=www.openslr.org/resources/11
mkdir -p data
mkdir -p data/local

# Prepare data
if [ $stage -le 0 ]; then
  # Make soft link to the corpora
  if [ ! -e cmu_kids ]; then
     echo "ERROR: Expected to find a directory called 'kids' in $cmu_kids. Exiting." && exit 1; fi
#  if [ ! -e cslu ]; then
#    if [ ! -d $cslu_kids/speech ]; then echo "ERROR: Expected to find a directory called 'speech' in $cslu_kids. Exiting." && exit 1; fi

#    ln -sf $cslu_kids cslu
#  fi
  
  # Make softlink to lm, if lm_src provided
  if [ ! -z "$lm_src" ] && [ ! -e data/local/lm ] ; then
	  echo "ERROR: Expected to find a directory for LM. Exiting." && exit 1;
  fi

  # Data Prep
  ./local/cmu_prepare_data_gop.sh --corpus cmu_kids/kids --data data/data_cmu_gop
  #./local/cslu_prepare_data.sh --corpus cslu --data data/data_cslu 
fi

# LM, WFST Preparation
if [ $stage -le 2 ]; then
  if [ ! -d data/local/dict ]; then
      ./local/download_cmu_dict.sh
  fi

  if [ ! -e data/local/lm ]; then
    echo "lm_src not provided. Downloading lm from openslr."
    ./local/download_lm.sh $lm_url data/local/lm
  fi

  utils/prepare_lang.sh data/local/dict "<UNK>"  data/local/lang data/lang
  local/format_lms.sh --src_dir data/lang  data/local/lm 
   
  # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  #utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz data/lang data/lang_test_tglarge
  #utils/build_const_arpa_lm.sh data/local/lm/lm_fglarge.arpa.gz data/lang data/lang_test_fglarge 
fi

# Make MFCC features
if [ $stage -le 3 ]; then
  mkdir -p mfcc
  mkdir -p exp
  steps/make_mfcc.sh --nj 40 --cmd "$train_cmd" data/data_cmu_gop/test exp/make_feat/test-gop mfcc
  steps/compute_cmvn_stats.sh data/data_cmu_gop/test exp/make_feat/test-gop mfcc
fi

echo "data prepared"

# Align with sat model 
if [ $stage -le 4 ]; then
  steps/align_si_gop.sh --nj 2 --cmd "$train_cmd" data/data_cmu_gop/test $lang_path $si_model_path exp/gop_ali_mono
fi

# Numerator score
#if [ $stage -le 5 ]; then
#  steps/align_si_gop.sh --nj 2 --cmd "$train_cmd" data/data_cmu_gop/test $lang_path $si_model_path exp/gop_ali_si
#fi

# Denominator
if [ $stage -le 6 ]; then
  #make phoneme-level graph HCP - no L.fst is needed
  steps/make_gop_graph.sh $lang_path exp/gop_ali_si exp/gop_ali_si exp/gop_denom_mono_time/ 
fi

if [ $stage -le 7 ]; then
  # Phone-level decode and get the best path with its scores per frame
  #steps/decode_gop.sh --config conf/decode.config --nj 2 --cmd "$decode_cmd" exp/gop_ali_si exp/gop_ali_sat exp/gop_denominator/phone_graph data/data_cmu_gop/test exp/gop_denominator/decode
  steps/decode_gop.sh --config conf/decode.config --nj 2 --cmd "$decode_cmd" exp/gop_ali_si exp/gop_ali_mono exp/gop_denom_mono_time/phone_graph data/data_cmu_gop/test exp/gop_denom_mono_time/decode
fi 


echo "done"
exit 0
## Add other features
#if [ $stage -le 7 ]; then
#  if [ $extra_features = true ]; then
#    # Add MMI
#    steps/make_denlats.sh --nj 20 --cmd "$train_cmd" data/train data/lang exp/tri2 exp/tri2_denlats
#    steps/train_mmi.sh data/train data/lang exp/tri2_ali exp/tri2_denlats exp/tri2_mmi
#    steps/decode.sh --config conf/decode.config --iter 4 --nj 20 --cmd "$decode_cmd" exp/tri2/graph data/test exp/tri2_mmi/decode_it4
#    steps/decode.sh --config conf/decode.config --iter 3 --nj 20 --cmd "$decode_cmd" exp/tri2/graph data/test exp/tri2_mmi/decode_it3
#    
#    # Add Boosting 
#    steps/train_mmi.sh --boost 0.05 data/train data/lang exp/tri2_ali exp/tri2_denlats exp/tri2_mmi_b0.05
#    steps/decode.sh --config conf/decode.config --iter 4 --nj 20 --cmd "$decode_cmd" exp/tri2/graph data/test exp/tri2_mmi_b0.05/decode_it4
#    steps/decode.sh --config conf/decode.config --iter 3 --nj 20 --cmd "$decode_cmd" exp/tri2/graph data/test exp/tri2_mmi_b0.05/decode_it3
#    
#    # Add MPE 
#    steps/train_mpe.sh data/train data/lang exp/tri2_ali exp/tri2_denlats exp/tri2_mpe
#    steps/decode.sh --config conf/decode.config --iter 4 --nj 20 --cmd "$decode_cmd" exp/tri2/graph data/test exp/tri2_mpe/decode_it4
#    steps/decode.sh --config conf/decode.config --iter 3 --nj 20 --cmd "$decode_cmd" exp/tri2/graph data/test exp/tri2_mpe/decode_it3
#  fi
#fi

# Add SAT
#if [ $stage -le 8 ]; then 
#  # Do LDA+MLLT+SAT, and decode.
#  steps/train_sat.sh 1800 9000 data/train data/lang exp/tri2_ali exp/tri3
#  utils/mkgraph.sh data/lang_test_tgmed exp/tri3 exp/tri3/graph
#  steps/decode_fmllr.sh --config conf/decode.config --nj 40 --cmd "$decode_cmd" exp/tri3/graph data/test exp/tri3/decode
#fi
#
#if [ $stage -le 9 ]; then
#  # Align all data with LDA+MLLT+SAT system (tri3)
#  steps/align_fmllr.sh --nj 20 --cmd "$train_cmd" --use-graphs true data/train data/lang_test_tgmed exp/tri3 exp/tri3_ali
#  utils/mkgraph.sh data/lang_test_tgmed exp/tri3_ali exp/tri3_ali/graph   
#  steps/decode_fmllr.sh --config conf/decode.config --nj 40 --cmd "$decode_cmd" exp/tri3_ali/graph data/test exp/tri3_ali/decode
#fi

#if [ $stage -le 10 ]; then 
#    # Uncomment reporting email option to get training progress updates by email
#  ./local/chain/run_tdnnf.sh --train_set train \
#      --test_sets test --gmm tri3  # --reporting_email $email 
#fi
#
#
## Optional VTLN. Run if vtln is set to true
#if [ $stage -le 11 ]; then
#  if [ $vtln = true ]; then
#    ./local/vtln.sh
#    ./local/chain/run_tdnnf.sh --nnet3_affix vtln --train_set train_vtln \
#        --test_sets test_vtln --gmm tri5 # --reporting_email $email
#  fi
#fi

# Collect and resport WER results for all models
./local/sort_result.sh
