#! /bin/bash

# Copyright Johns Hopkins University
#   2019 Fei Wu

set -eo

stage=3
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
  steps/make_mfcc.sh --nj 40 --cmd "$train_cmd"  --mfcc_config conf/mfcc_wav2vec2.conf data_30/data_cmu_gop/test exp/make_mfcc_30/test-gop mfcc_30
  steps/compute_cmvn_stats.sh data_30/data_cmu_gop/test exp/make_mfcc_30/test-gop mfcc_30
fi

echo "data prepared"

# Align with sat model 
if [ $stage -le 4 ]; then
  if [ ! -d exp/align_mono_30 ];then
	steps/align_si_gop_ctm.sh --nj 5 --cmd "$train_cmd" data_30/data_cmu_gop/test $lang_path $si_model_path exp/ali_mono_30
  fi
fi

echo "done"
exit 0
