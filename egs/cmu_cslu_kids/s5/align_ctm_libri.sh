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
si_model_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/exp/mono_all_data
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
  if [ ! -d data/data_cmu_gop ];then
  	./local/cmu_prepare_data_gop.sh --corpus cmu_kids/kids --data data/data_cmu_gop
  	#./local/cslu_prepare_data.sh --corpus cslu --data data/data_cslu 
  fi
fi

# Make MFCC features
if [ $stage -le 1 ]; then
  mkdir -p mfcc
  mkdir -p exp
  if [ ! -d ./mfcc ];then
  	steps/make_mfcc.sh --nj 40 --cmd "$train_cmd" data/data_cmu_gop/test exp/make_feat/test-gop mfcc
  	steps/compute_cmvn_stats.sh data/data_cmu_gop/test exp/make_feat/test-gop mfcc
  fi
fi


# Align with external model 
if [ $stage -le 2 ]; then
  steps/align_si_gop_ctm.sh --nj 2 --cmd "$train_cmd" data/data_cmu_gop/test $lang_path $si_model_path exp/gop_ali_mono_ctm
fi

echo "done"
