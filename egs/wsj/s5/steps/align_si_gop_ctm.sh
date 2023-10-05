#!/usr/bin/env bash
# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# Compute training alignments using a model with delta or
# delta + delta-delta features.

# If you supply the "--use-graphs true" option, it will use the training
# graphs from the source directory (where the model is).  In this
# case the number of jobs must match with the source directory.


# Begin configuration section.
nj=4
cmd=run.pl
use_graphs=false
# Begin configuration.
scale_opts="--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1"
beam=10
retry_beam=40
careful=false
boost_silence=1.0 # Factor by which to boost silence during alignment.
# End configuration options.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

if [ $# != 4 ]; then
   echo "usage: steps/align_si.sh <data-dir> <lang-dir> <src-dir> <align-dir>"
   echo "e.g.:  steps/align_si.sh data/train data/lang exp/tri1 exp/tri1_ali"
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>                           # config containing options"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --use-graphs true                                # use graphs in src-dir"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   exit 1;
fi

data=$1
lang=$2
srcdir=$3
dir=$4


for f in $data/text $lang/oov.int $srcdir/tree $srcdir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1;
done

oov=`cat $lang/oov.int` || exit 1;
mkdir -p $dir/log
echo $nj > $dir/num_jobs
sdata=$data/split$nj
splice_opts=`cat $srcdir/splice_opts 2>/dev/null` # frame-splicing options.
cp $srcdir/splice_opts $dir 2>/dev/null # frame-splicing options.
cmvn_opts=`cat $srcdir/cmvn_opts 2>/dev/null`
cp $srcdir/cmvn_opts $dir 2>/dev/null # cmn/cmvn option.
delta_opts=`cat $srcdir/delta_opts 2>/dev/null`
cp $srcdir/delta_opts $dir 2>/dev/null

[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;

utils/lang/check_phones_compatible.sh $lang/phones.txt $srcdir/phones.txt || exit 1;
cp $lang/phones.txt $dir || exit 1;

cp $srcdir/{tree,final.mdl} $dir || exit 1;
cp $srcdir/final.occs $dir;



if [ -f $srcdir/final.mat ]; then feat_type=lda; else feat_type=delta; fi
echo "$0: feature type is $feat_type"

case $feat_type in
  delta) feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | add-deltas $delta_opts ark:- ark:- |";;
  lda) feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $srcdir/final.mat ark:- ark:- |"
    cp $srcdir/final.mat $srcdir/full.mat $dir
   ;;
  *) echo "$0: invalid feature type $feat_type" && exit 1;
esac

echo "$0: aligning data in $data using model from $srcdir, putting alignments in $dir"

mdl="gmm-boost-silence --boost=$boost_silence `cat $lang/phones/optional_silence.csl` $dir/final.mdl - |"

if $use_graphs; then
  [ $nj != "`cat $srcdir/num_jobs`" ] && echo "$0: mismatch in num-jobs" && exit 1;
  [ ! -f $srcdir/fsts.1.gz ] && echo "$0: no such file $srcdir/fsts.1.gz" && exit 1;

  $cmd JOB=1:$nj $dir/log/align.JOB.log \
    gmm-align-compiled $scale_opts --beam=$beam --retry-beam=$retry_beam --careful=$careful "$mdl" \
      "ark:gunzip -c $srcdir/fsts.JOB.gz|" "$feats" "ark:|gzip -c >$dir/ali.JOB.gz" || exit 1;
else
  tra="ark:utils/sym2int.pl --map-oov $oov -f 2- $lang/words.txt $sdata/JOB/text|";
  # We could just use gmm-align in the next line, but it's less efficient as it compiles the
  # training graphs one by one.
  $cmd JOB=1:$nj $dir/log/align.JOB.log \
    compile-train-graphs --read-disambig-syms=$lang/phones/disambig.int $dir/tree $dir/final.mdl  $lang/L.fst "$tra" ark:- \| \
    gmm-align-compiled $scale_opts --beam=$beam --retry-beam=$retry_beam --careful=$careful --write-per-frame-acoustic-loglikes="ark,t:$dir/AM-SCORE.JOB.txt" "$mdl" ark:- \
      "$feats" "ark,t:|gzip -c >$dir/ali.JOB.gz"  || exit 1;
fi

#align-to-phone
  $cmd JOB=1:$nj $dir/log/align_to_phone.JOB.log \
  ali-to-phones --per-frame "$mdl" "ark:gunzip -c $dir/ali.JOB.gz|" "ark,t:$dir/ali.phone.JOB.txt"
  [ -f $dir/ali.phonemes.all.txt ] && rm $dir/ali.phonemes.all.txt
  cat $dir/ali.phone.*.txt | utils/int2sym.pl -f 2- $lang/phones.txt >> "$dir/ali.phonemes.all.txt" || exit 1;

#align-to-phone-ctm
  $cmd JOB=1:$nj $dir/log/align_to_phone.JOB.log \
  ali-to-phones --ctm-output --per-frame "$mdl" "ark:gunzip -c $dir/ali.JOB.gz|" "$dir/ali.phone.JOB.ctm"
  cat $dir/ali.phone.*.ctm | utils/int2sym.pl -f 5- $lang/phones.txt >> "$dir/all.phonemes.ctm" || exit 1;

#align-to-words
for f in $lang/words.txt $dir/ali.1.gz $lang/oov.int; do
  [ ! -f $f ] && echo "$0: expecting file $f to exist" && exit 1;
done
oov=`cat $lang/oov.int` || exit 1
  if [ -f $lang/phones/word_boundary.int ]; then
    $cmd JOB=1:$nj $dir/log/get_ctm.JOB.log \
      set -o pipefail '&&' linear-to-nbest "ark:gunzip -c $dir/ali.JOB.gz|" \
      "ark:utils/sym2int.pl --map-oov $oov -f 2- $lang/words.txt < $sdata/JOB/text |" \
      '' '' "ark:-" \| \
      lattice-align-words $lang/phones/word_boundary.int "$mdl" ark:- ark:- \| \
      nbest-to-ctm  --print-silence=true ark:- $dir/words.ctm.JOB || exit 1
    cat $dir/words.ctm.* | utils/int2sym.pl -f 5 $lang/words.txt  > "$dir/all.words.ctm" || exit 1;
  else
    if [ ! -f $lang/phones/align_lexicon.int ]; then
	    echo "align-to-ctm failed, missing lang/phones/align_lexicon.in" && exit 1
    fi
  fi
    
steps/diagnostic/analyze_alignments.sh --cmd "$cmd" $lang $dir

echo "$0: done aligning data."
