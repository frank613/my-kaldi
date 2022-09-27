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
   echo "Usage: steps/compute_gop.sh [options] <ali-dir> <time-dir> <decode-dir> <out-dir>"
   echo "This script computes GOP from denominator and numerator"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --num-threads <n>                                # number of threads to use, default 1."
   exit 1;
fi

alidir=$1
timedir=$2
decode_dir=$3
dir=$4


mkdir -p $dir/log
echo $nj > $dir/num_jobs


thread_string=
[ $num_threads -gt 1 ] && thread_string="-parallel --num-threads=$num_threads"



if [ $stage -le 0 ]; then
   [ $nj != "`cat $alidir/num_jobs`" ] && echo "$0: mismatch in num-jobs for computing numerator and denominator scores" && exit 1;
   $cmd JOB=1:$nj $dir/log/gop.JOB.log \
	   gop-base "ark,t:$alidir/AM-SCORE.JOB.txt" "ark,t:$timedir/ali.phone.JOB.txt" "ark,t:$decode_dir/best.ali.JOB.txt"  "ark,t:$dir/gop.JOB.score.txt"

   cat $dir/gop.* > $dir/gop.score.all
   cat $dir/gop.score.all  | utils/int2sym.pl -f 2 $decode_dir/../phones.txt > $dir/gop.score.all.symbol
fi


exit 0;
