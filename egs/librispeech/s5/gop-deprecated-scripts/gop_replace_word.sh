#!/usr/bin/env bash


# Set this to somewhere where you want to put your data, or where
# someone else has already put it.  You'll want to change this
# if you're not on the CLSP grid.
data=/localhome/stipendiater/xinweic/data/libri

# base url for downloads.
data_url=www.openslr.org/resources/12
lm_url=www.openslr.org/resources/11
mfccdir=mfcc
stage=8

. ./cmd.sh
. ./path.sh
. parse_options.sh

# you might not want to do this for interactive shells.
set -e


if [ $stage -le 1 ]; then
  # download the data.  Note: we're using the 100 hour setup for
  # now; later in the script we'll download more and use it to train neural
  # nets.
  for part in dev-clean test-clean dev-other test-other train-clean-100; do
    local/download_and_untar.sh $data $data_url $part
  done


  # download the LM resources
  local/download_lm.sh $lm_url data/local/lm
fi

if [ $stage -le 2 ]; then
  # format the data as Kaldi data directories
  for part in dev-clean test-clean dev-other test-other train-clean-100; do
    # use underscore-separated names in data directories.
    local/data_prep.sh $data/LibriSpeech/$part data/$(echo $part | sed s/-/_/g)
  done
fi

## Optional text corpus normalization and LM training
## These scripts are here primarily as a documentation of the process that has been
## used to build the LM. Most users of this recipe will NOT need/want to run
## this step. The pre-built language models and the pronunciation lexicon, as
## well as some intermediate data(e.g. the normalized text used for LM training),
## are available for download at http://www.openslr.org/11/
#local/lm/train_lm.sh $LM_CORPUS_ROOT \
#  data/local/lm/norm/tmp data/local/lm/norm/norm_texts data/local/lm

## Optional G2P training scripts.
## As the LM training scripts above, this script is intended primarily to
## document our G2P model creation process
#local/g2p/train_g2p.sh data/local/dict/cmudict data/local/lm

if [ $stage -le 3 ]; then
  # when the "--stage 3" option is used below we skip the G2P steps, and use the
  # lexicon we have already downloaded from openslr.org/11/
  local/prepare_dict.sh --stage 3 --nj 30 --cmd "$train_cmd" \
   data/local/lm data/local/lm data/local/dict_nosp

  utils/prepare_lang.sh data/local/dict_nosp \
   "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  local/format_lms.sh --src-dir data/lang_nosp data/local/lm
fi

#if [ $stage -le 4 ]; then
  # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  #utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
  #  data/lang_nosp data/lang_nosp_test_tglarge
  #utils/build_const_arpa_lm.sh data/local/lm/lm_fglarge.arpa.gz \
  #  data/lang_nosp data/lang_nosp_test_fglarge
#fi

#if [ $stage -le 5 ]; then
  # spread the mfccs over various machines, as this data-set is quite large.
  #if [[  $(hostname -f) ==  *.clsp.jhu.edu ]]; then
  #  mfcc=$(basename mfccdir) # in case was absolute pathname (unlikely), get basename.
  #  utils/create_split_dir.pl /export/b{02,11,12,13}/$USER/kaldi-data/egs/librispeech/s5/$mfcc/storage \
  #   $mfccdir/storage
  #fi
#fi


if [ $stage -le 6 ]; then
  utils/combine_data.sh data/gop_combined data/dev_clean data/test_clean data/dev_other data/test_other
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/gop_combined exp/make_mfcc/gop_combined $mfccdir
  steps/compute_cmvn_stats.sh data/gop_combined exp/make_mfcc/gop_combined $mfccdir
fi

if [ $stage -le 7 ]; then
  #align canonical text with the monophone model 
  steps/align_si.sh  --nj 2 --cmd "$train_cmd" \
                    data/gop_combined data/lang_nosp exp/mono_all_data exp/mono_ali_gop
fi

if [ $stage -le 8 ]; then
  #get the word alignment from the above output
  steps/get_word_align.sh  data/gop_combined data/lang_nosp exp/mono_ali_gop 
fi

if [ $stage -le 9 ]; then
  #substitude the words and align again
  echo "hi"
fi


echo "done"
exit 0

