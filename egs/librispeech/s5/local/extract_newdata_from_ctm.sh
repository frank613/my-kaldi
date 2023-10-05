#!/usr/bin/env bash

##This script takes phoneme-level ctm file(with phoneme substitution from e.g., /exp/mono_ali/AH_S_ctm) as input, extract features for doing single phoneme alignment. 
. ./cmd.sh
if [ $# -ne 5 ]; then
  cat >&2 <<EOF
Usage: $0 ctmfile.txt <lang-dir> <data-dir> phoenme-from phoneme-to
EOF
   exit 1;
fi


ctm_file=$1
lang_path=$2
data_dir=$3
targetP=$4
toP=$5

workdir=$data_dir/extracted_segments/$targetP/$toP

#step1, make new data dir and copy files
mkdir -p $workdir || exit 1
cp -r $data_dir/{cmvn.scp,frame_shift,spk2gender,conf} $workdir || exit 1

#step2, make segments, text, and other files from ctm $5 ~ ph might mess up G <> NG R <-> ER etc.
echo $ctm_file $targetP
cat $ctm_file | awk -F " " -v ph=$targetP '{ if($5 ~ ph) print $1"-"($3*1000),$1,$3,$4+$3,$5,$4}' > $workdir/temp || exit 1

cut -d' ' -f1-4 $workdir/temp | sort > $workdir/segments || exit 1
cut -d' ' -f1,5 $workdir/temp > text.orig || exit 1
./local/replace_stress.sh text.orig $targetP $toP | awk -F' ' '{print($1,"Phoneme_"$2)}' | sort > $workdir/text || exit 1
cut -d' ' -f2 $workdir/text | sort -u | nl -nln | sed 's/ *\t/ /g' | awk -F" " '{print $2,$1}' | sed  '1s/^/<eps> 0\n/' > $workdir/words.txt || exit 1

#step3, create (utt2dur utt2spk spk2utt)
cut -d' ' -f1,6 $workdir/temp > $workdir/utt2dur_fromCTM || exit 1
cut -d' ' -f1-2 $workdir/temp > $workdir/uttid_map.tmp || exit 1
join -t' ' -1 2 -2 1 $workdir/uttid_map.tmp $data_dir/utt2spk | cut -d' ' -f2,3 | sort >  $workdir/utt2spk || exit 1 
#utils/utt2spk_to_spk2utt.pl <$workdir/utt2spk  >$workdir/spk2utt || exit 1
#cut -d' ' -f2 $workdir/temp | sort -u > $workdir/recordings_tmp || exit 1
#@join -t' ' -1 1 -2 1 $workdir/recordings_tmp $data_dir/wav.scp > $workdir/wav.scp

#step4, extract segmented features
#steps/make_mfcc.sh --cmd "$train_cmd" --nj 11 $workdir || exit 1
./utils/data/subsegment_data_dir.sh $data_dir $workdir/segments $workdir/text $workdir/data-segmented || exit 1
cp $workdir/cmvn.scp $workdir/data-segmented
cp $workdir/utt2dur_fromCTM $workdir/data-segmented/utt2dur

#step5, create new lexicon files for all variants of the current phonemes  and create L.fst
cat $workdir/words.txt | cut -d' ' -f1 | sed 's/Phoneme_//g' > $workdir/phone_list.tmp
cat $lang_path/phones.txt | sort > $workdir/phones.orig 
join -t' ' -1 1 -2 1 $workdir/phone_list.tmp $workdir/phones.orig > $workdir/phones.txt 
cat $workdir/phones.txt | awk -F' ' '{print "Phoneme_"$1,"1.0",$1}' | tail -n +2 > $workdir/lexiconp.txt
cp $lang_path/oov.int $workdir

sil_prob=0.0
silphone=SIL
utils/lang/make_lexicon_fst.py --sil-prob=$sil_prob \
            $workdir/lexiconp.txt | \
    fstcompile --isymbols=$workdir/phones.txt --osymbols=$workdir/words.txt \
      --keep_isymbols=false --keep_osymbols=false | \
    fstarcsort --sort_type=olabel > $workdir/L.fst || exit 1;