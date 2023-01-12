#!/usr/bin/env bash

# Copyright 2012 Vassil Panayotov
# Apache 2.0

source ./path.sh

echo "=== Preparing train and test data ..."
srcdir=data/local
lmdir=data/local/
tmpdir=data/local/lm_tmp
lexicon=data/local/dict/lexicon.txt
mkdir -p $tmpdir

for x in train test; do
  mkdir -p data/$x
  cp $srcdir/${x}_wav.scp data/$x/wav.scp || exit 1;
  cp $srcdir/${x}_trans.txt data/$x/text || exit 1;
  cp $srcdir/$x.spk2utt data/$x/spk2utt || exit 1;
  cp $srcdir/$x.utt2spk data/$x/utt2spk || exit 1;
  utils/filter_scp.pl data/$x/spk2utt $srcdir/spk2gender > data/$x/spk2gender || exit 1;
done




echo "*** Succeeded in formatting data."
