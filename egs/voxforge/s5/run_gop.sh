#!/usr/bin/env bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

# NOTE: You will want to download the data set first, before executing this script.
#       This can be done for example by:
#       1. Setting the variable DATA_ROOT in path.sh to point to a
#          directory with enough free space (at least 20-25GB
#          currently (Feb 2014))
#       2. Running "getdata.sh"

# The second part of this script comes mostly from egs/rm/s5/run.sh
# with some parameters changed

. ./path.sh || exit 1

# If you have cluster of machines running GridEngine you may want to
# change the train and decode commands in the file below
. ./cmd.sh || exit 1

set -e -o pipefail -u

# The number of parallel jobs to be started for some parts of the recipe
# Make sure you have enough resources(CPUs and RAM) to accomodate this number of jobs
nj=10

# This recipe can select subsets of VoxForge's data based on the "Pronunciation dialect"
# field in VF's etc/README files. To select all dialects, set this to "English"
#dialects="((American)|(British)|(Australia)|(Zealand))"
dialects="(American)"

# The number of randomly selected speakers to be put in the test set
#nspk_test=20
#for GOP
nspk_test=500

# Test-time language model order
lm_order=2

# Word position dependent phones?
pos_dep_phones=true

# The directory below will be used to link to a subset of the user directories
# based on various criteria(currently just speaker's accent)
selected=${DATA_ROOT}/selected

# The user of this script could change some of the above parameters. Example:
# /bin/bash run.sh --pos-dep-phones false
. utils/parse_options.sh || exit 1


si_model_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/exp/mono_all_data
lang_path=/localhome/stipendiater/xinweic/kaldi/egs/librispeech/s5/data/lang_nosp

stage=3
[[ $# -ge 1 ]] && { echo "Unexpected arguments"; exit 1; }

# Data preparation
if [ $stage -le 0 ]; then


# Select a subset of the data to use
# WARNING: the destination directory will be deleted if it already exists!
local/voxforge_select.sh --dialect $dialects \
  ${DATA_ROOT}/extracted ${selected} || exit 1

# Mapping the anonymous speakers to unique IDs
local/voxforge_map_anonymous.sh ${selected} || exit 1

# Initial normalization of the data
local/voxforge_data_prep.sh --nspk_test ${nspk_test} ${selected} || exit 1

# Prepare ARPA LM and vocabulary using SRILM
#local/voxforge_prepare_lm.sh --order ${lm_order} || exit 1

# Prepare the lexicon and various phone lists
# Pronunciations for OOV words are obtained using a pre-trained Sequitur model
#local/voxforge_prepare_dict.sh || exit 1

# Prepare data/lang and data/local/lang directories
#utils/prepare_lang.sh --position-dependent-phones $pos_dep_phones \
#  data/local/dict '!SIL' data/local/lang data/lang || exit 1

# Prepare data/{train,test} directories
local/voxforge_format_data_gop.sh || exit 1

fi

if [ $stage -le 2 ]; then
# Now make MFCC features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=${DATA_ROOT}/mfcc
for x in train test; do
 steps/make_mfcc.sh --cmd "$train_cmd" --nj $nj \
   data/$x exp/make_mfcc/$x $mfccdir || exit 1;
 steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
done

fi

echo "done data preparation"

# Align with si model
if [ $stage -le 3 ]; then
        if [ ! -d exp/ali_ctm ];then
                steps/align_si_gop_ctm.sh --nj 1 --cmd "$train_cmd" data/test $lang_path $si_model_path exp/gop_ali_ctm
        fi
fi

echo "done"
