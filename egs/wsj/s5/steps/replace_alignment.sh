#!/usr/bin/env bash

# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# Begin configuration section.
                 # supply existing fMLLR transforms when decoding.
stage=0
nj=4
cmd=run.pl
num_threads=1 # if >1, will use gmm-latgen-faster-parallel

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;


if [ $# != 4 ]; then
   echo "Usage: steps/modify_alignments.sh [options] <ori-ali-dir> <p-ali-dir> <feats-dir> <out-dir>"
   echo "This script modifies the alignment for phoneme replacement"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --num-threads <n>                                # number of threads to use, default 1."
   exit 1;
fi

orialigndir=$1
paligndir=$2
featdir=$3
dir=$4


mkdir -p $dir/log
echo $nj > $dir/num_jobs


thread_string=
[ $num_threads -gt 1 ] && thread_string="-parallel --num-threads=$num_threads"



if [ $stage -le 0 ]; then
   [ $nj != "`cat $paligndir/num_jobs`" ] && echo "$0: mismatch in num-jobs for computing numerator and denominator scores" && exit 1;
   $cmd JOB=1:$nj $dir/log/replace_ali.JOB.log \
	   gop-replace-score-ali ark,t:$orialigndir/AM-SCORE.JOB.txt ark,t:$paligndir/AM-SCORE.JOB.txt scp:$featdir/feats.scp ark,t:$dir//AS-modified.JOB.txt
fi


exit 0;
