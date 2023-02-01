#!/usr/bin/env bash

stage=0
parallel_opts="--gpu wait"
cmd="run.pl $parallel_opts"
cmvn_opts=

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;


if [ $# != 4 ]; then
   echo "Usage: steps/gop-nnet2-likeRatio.sh [options] <model-dir> <ali-dir> <data-dir> <work-dir>"
   echo ""
   echo "This script computes the GOP using nnet2 DNN"
   echo ""
   exit 1;
fi

moddir=$1
alidir=$2
datadir=$3
workdir=$4

mkdir -p $workdir/log


#raw feats as input, the splice will be done with the nnet2 layer
feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$datadir/utt2spk scp:$datadir/cmvn.scp scp:$datadir/feats.scp ark:- |"

if [ $stage -le 0 ]; then
   $cmd  $workdir/log/gop.log \
   gop-nnet2-likeRatio $moddir/final.mdl "$feats" "ark,t:$alidir/ali.all.txt" "ark,t:$workdir/gop.score.txt"

   cat $workdir/gop.* > $workdir/gop.score.all
   cat $workdir/gop.score.all  | utils/int2sym.pl -f 2 $alidir/phones.txt > $workdir/gop.score.all.symbol
fi


exit 0;
