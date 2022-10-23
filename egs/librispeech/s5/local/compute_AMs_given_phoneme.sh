#!/usr/bin/env bash

##This script calculates AM-scores for the sgement using the middle state of the given target phoenme (in the segment-dir) and writes out the scores using the ark format. 

nj=4
cmd=run.pl

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;


if [ $# -ne 3 ]; then
  cat >&2 <<EOF
Usage: $0  <segment-dir> <model-dir> <out-dir>
	main options (for others, see top of script file)
	--nj <nj>
	--cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs.
EOF
   exit 1;
fi

seg_dir=$1
model_dir=$2
dir=$3
sdata=$seg_dir/data-segmented/split$nj
mkdir -p $dir/log
echo $nj > $dir/num_jobs

if [ ! -f $seg_dir/phones.txt ];then
	echo "phones.txt not found in the segment dir"
	exit 1;
fi
#always pick the phoneeme in the middle (_I)
targetP=$(tail -n1 $seg_dir/phones.txt | cut -d' ' -f1 | cut -d'_' -f1)"_I" 
#alaways pick the middle state (state = 1))
pdf_id=$(show-transitions ${model_dir}/phones.txt ${model_dir}/final.mdl  | grep "phone = $targetP " | grep "state = 1" | sed 's/.*pdf = \([0-9]*\).*/\1/g')

[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;

$cmd JOB=1:$nj $dir/log/align.JOB.log \
	gmm-compute-likes $model_dir/final.mdl "ark,s,cs:apply-cmvn --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | add-deltas  ark:- ark:- |" "ark,t:$dir/matrix_$targetP.JOB.out" || exit 1;

$cmd JOB=1:$nj $dir/log/align2.JOB.log \
	like-to-ali $pdf_id "ark,t:$dir/matrix_$targetP.JOB.out" "ark,t:$dir/AM-SCORE.JOB.txt" || exit 1;




