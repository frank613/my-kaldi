#!/bin/bash

. ./cmd.sh
. ./path.sh

stage=0

#DIRs
si_model_path=./exp/tri2b
lang_path=./data/lang_teflon
#data_path=./data/test-gop-teflon

decode_dir=/localhome/stipendiater/xinweic/git-repos/my-kaldi/egs/NST3/exp/decode-teflon/decode
work_dir=$decode_dir
symtab=$lang_path/phones.txt

gop_file=/home/stipendiater/xinweic/tools/pykaldi/compute-gop/teflon/output-teflon/teflon.gop
ptext=$work_dir/ptext

nj=1
stage=0
min_lmwt=1
max_lmwt=10
cmd=run.pl

# Get the target phoneme text
#./local/prepare_ptext_from_gop.sh $gop_file > $ptext  || exit 1;

# Get the phone-sequence on the best-path:
#for LMWT in $(seq $min_lmwt $max_lmwt); do

LMWT=$min_lmwt
#$cmd JOB=1:$nj $work_dir/scoring/log/best_path_basic.$LMWT.JOB.log \
#lattice-best-path --lm-scale=$LMWT --word-symbol-table=$symtab --verbose=2 \
#"ark:gunzip -c $work_dir/lat.JOB.gz|" ark,t:$work_dir/scoring/$LMWT.JOB.tra || exit 1;
#cat $work_dir/scoring/$LMWT.*.tra | sort > $work_dir/scoring/$LMWT.tra
#rm $work_dir/scoring/$LMWT.*.tra

#done

# Map hypothesis to 39 phone classes:
$cmd $work_dir/scoring/log/score_basic.LMWT.log \
   cat $work_dir/scoring/$LMWT.tra \| \
    utils/int2sym.pl -f 2- $symtab \| \
    sed -r 's/\([0-9]*_\)[A-Z]+//g' \| \
    compute-wer --text --mode=all \
     ark,t:$ptext ark,p:- ">&" $work_dir/wer_LMWT || exit 1;
