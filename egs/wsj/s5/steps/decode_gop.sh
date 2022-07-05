#!/usr/bin/env bash

# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# Begin configuration section.
transform_dir=   # this option won't normally be used, but it can be used if you want to
                 # supply existing fMLLR transforms when decoding.
iter=
model= # You can specify the model to use (e.g. if you want to use the .alimdl)
stage=0
nj=4
cmd=run.pl
max_active=7000
beam=16
lattice_beam=10
acwt=10 # note: only really affects pruning (scoring is on lattices).
num_threads=1 # if >1, will use gmm-latgen-faster-parallel
parallel_opts=  # ignored now.
scoring_opts=
# note: there are no more min-lmwt and max-lmwt options, instead use
# e.g. --scoring-opts "--min-lmwt 1 --max-lmwt 20"
skip_scoring=true
decode_extra_opts=
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 4 ]; then
   echo "Usage: steps/decode_gop.sh [options] <ali-dir> <graph-dir> <data-dir> <decode-dir>"
   echo "... where <decode-dir> is assumed to be a sub-directory of the directory"
   echo " where the model is."
   echo "e.g.: steps/decode.sh exp/gop_ali_si exp/gop_denominator/phone_graph data/data_cmu_gop/test exp/gop_denominator/decode"
   echo ""
   echo "This script computes the denominator score and GOP  using the decoding schema based on steps/decode.sh"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>                           # config containing options"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --iter <iter>                                    # Iteration of model to test."
   echo "  --model <model>                                  # which model to use (e.g. to"
   echo "                                                   # specify the final.alimdl)"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --transform-dir <trans-dir>                      # dir to find fMLLR transforms "
   echo "  --acwt <float>                                   # acoustic scale used for lattice generation "
   echo "  --scoring-opts <string>                          # options to local/score.sh"
   echo "  --num-threads <n>                                # number of threads to use, default 1."
   echo "  --parallel-opts <opts>                           # ignored now, present for historical reasons."
   exit 1;
fi

alidir=$1
timedir=$2
graphdir=$3
data=$4
dir=$5
srcdir=`dirname $dir`; # The model directory is one level up from decoding directory.
sdata=$data/split$nj;

mkdir -p $dir/log
[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;
echo $nj > $dir/num_jobs

if [ -z "$model" ]; then # if --model <mdl> was not specified on the command line...
  if [ -z $iter ]; then model=$srcdir/final.mdl;
  else model=$srcdir/$iter.mdl; fi
fi

if [ $(basename $model) != final.alimdl ] ; then
  # Do not use the $srcpath -- look at the path where the model is
  if [ -f $(dirname $model)/final.alimdl ] && [ -z "$transform_dir" ]; then
    echo -e '\n\n'
    echo $0 'WARNING: Running speaker independent system decoding using a SAT model!'
    echo $0 'WARNING: This is OK if you know what you are doing...'
    echo -e '\n\n'
  fi
fi

for f in $sdata/1/feats.scp $sdata/1/cmvn.scp $model $graphdir/HCLG.fst; do
  [ ! -f $f ] && echo "$0: Error: no such file $f" && exit 1;
done

if [ -f $srcdir/final.mat ]; then feat_type=lda; else feat_type=delta; fi
echo "decode.sh: feature type is $feat_type";

splice_opts=`cat $srcdir/splice_opts 2>/dev/null` # frame-splicing options.
cmvn_opts=`cat $srcdir/cmvn_opts 2>/dev/null`
delta_opts=`cat $srcdir/delta_opts 2>/dev/null`

thread_string=
[ $num_threads -gt 1 ] && thread_string="-parallel --num-threads=$num_threads"

case $feat_type in
  delta) feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | add-deltas $delta_opts ark:- ark:- |";;
  lda) feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $srcdir/final.mat ark:- ark:- |";;
  *) echo "$0: Error: Invalid feature type $feat_type" && exit 1;
esac
if [ ! -z "$transform_dir" ]; then # add transforms to features...
  echo "Using fMLLR transforms from $transform_dir"
  [ ! -f $transform_dir/trans.1 ] && echo "Expected $transform_dir/trans.1 to exist."
  [ ! -s $transform_dir/num_jobs ] && \
    echo "$0: Error: expected $transform_dir/num_jobs to contain the number of jobs." && exit 1;
  nj_orig=$(cat $transform_dir/num_jobs)
  if [ $nj -ne $nj_orig ]; then
    # Copy the transforms into an archive with an index.
    echo "$0: num-jobs for transforms mismatches, so copying them."
    for n in $(seq $nj_orig); do cat $transform_dir/trans.$n; done | \
       copy-feats ark:- ark,scp:$dir/trans.ark,$dir/trans.scp || exit 1;
    feats="$feats transform-feats --utt2spk=ark:$sdata/JOB/utt2spk scp:$dir/trans.scp ark:- ark:- |"
  else
    # number of jobs matches with alignment dir.
    feats="$feats transform-feats --utt2spk=ark:$sdata/JOB/utt2spk ark:$transform_dir/trans.JOB ark:- ark:- |"
  fi
fi

if [ $stage -le 0 ]; then
  if [ -f "$graphdir/num_pdfs" ]; then
    [ "`cat $graphdir/num_pdfs`" -eq `am-info --print-args=false $model | grep pdfs | awk '{print $NF}'` ] || \
      { echo "$0: Error: Mismatch in number of pdfs with $model"; exit 1; }
  fi
  ##larger acoustic scale and enable partial output at end state for more freedom at decoding. Disable all dertminization for state-level lattice
  $cmd JOB=1:$nj $dir/log/decode.JOB.log \
    gmm-latgen-faster  --beam=$beam --lattice-beam=$lattice_beam \
    --acoustic-scale=$acwt --allow-partial=true --determinize-lattice=false $decode_extra_opts \
    $model $graphdir/HCLG.fst "$feats" "ark:| gzip -c > $dir/lat.JOB.gz" || exit 1;
#  $cmd --num-threads $num_threads JOB=1:$nj $dir/log/decode.JOB.log \
#    gmm-latgen-faster  --beam=$beam --lattice-beam=$lattice_beam \
#    --acoustic-scale=$acwt --allow-partial=true  $decode_extra_opts \
#    $model $graphdir/HCLG.fst "$feats" "ark:| gzip -c > $dir/lat.JOB.gz" || exit 1;


  #GOP denominator only cares acoustic evidence
  $cmd JOB=1:$nj $dir/log/1best.JOB.log \
   lattice-1best-normal --acoustic-scale=100 --lm-scale=0.01  "ark:gunzip -c $dir/lat.JOB.gz|" ark:- | lattice-topsort "ark:-" "ark,t:$dir/best.ali.JOB.txt"
   #lattice-1best --acoustic-scale=100 --lm-scale=0.01  "ark:gunzip -c $dir/lat.*.gz|" "ark:$dir/best.ali"
   #lattice-1best --acoustic-scale=100 --lm-scale=0.01  "ark:gunzip -c $dir/lat.*.gz|" "ark:-" | lattice-scale --write-compact=false "ark:-" "ark:-" | lattice-topsort "ark:-" "ark,t:$dir/best.ali.txt"
fi

if [ $stage -le 1 ]; then
   [ $nj != "`cat $akidir/num_jobs`" ] && echo "$0: mismatch in num-jobs for computing numerator and denominator scores" && exit 1;
   $cmd JOB=1:$nj $dir/log/gop.JOB.log \
   gop-base "ark,t:$alidir/AM-SCORE.JOB.txt" "ark,t:$timedir/ali.phone.JOB.txt" "ark,t:$dir/best.ali.JOB.txt"  "ark,t:$dir/gop.JOB.score.txt"

fi
#if [ $stage -le 1 ]; then
#  [ ! -z $iter ] && iter_opt="--iter $iter"
#  steps/diagnostic/analyze_lats.sh --cmd "$cmd" $iter_opt $graphdir $dir
#fi

if ! $skip_scoring ; then
  [ ! -x local/score.sh ] && \
    echo "$0: Not scoring because local/score.sh does not exist or not executable." && exit 1;
  local/score.sh --cmd "$cmd" $scoring_opts $data $graphdir $dir ||
    { echo "$0: Error: scoring failed. (ignore by '--skip-scoring true')"; exit 1; }
fi

exit 0;
