#!/usr/bin/env bash
#set -x

# Set this to somewhere where you want to put your data, or where
# someone else has already put it.  You'll want to change this
# if you're not on the CLSP grid.
data=/localhome/stipendiater/xinweic/data/libri

# base url for downloads.
data_url=www.openslr.org/resources/12
lm_url=www.openslr.org/resources/11
mfccdir=mfcc
stage=0

dict_modified=$1
if [ $# -ne 2 ] | [ ! -f $dict_modified ]; then
    echo "Usage: $0 <modified-dict-file-absolutePath>" >&2
    exit 1
fi

fname=$(echo $dict_modified | xargs basename | cut -d'.' -f1)
fname=AA_S
dictDir=data/local/$fname
langDir=data/lang_replace/$fname
aliDir=exp/mono_ali/${fname}_ctm
gopDir=exp/gop_replace_all/$fname

. ./cmd.sh
. ./path.sh
. parse_options.sh

# you might not want to do this for interactive shells.
set -e



if [ $stage -le 1 ]; then
  # when the "--stage 3" option is used below we skip the G2P steps, and use the
  # lexicon we have already downloaded from openslr.org/11/
  if [ ! -d $dictDir ]; then
  	cp -r data/local/dict_nosp $dictDir  && rm $dictDir/lexicon.txt $dictDir/lexiconp.txt && cp $dict_modified $dictDir/lexicon.txt || (echo "something wrong here";exit 1) 
  	utils/prepare_lang.sh $dictDir \
   	"<UNK>" data/local/lang_tmp_nosp $langDir 

  	local/format_lms.sh --src-dir $langDir data/local/lm
  fi
fi

if [ $stage -le 2 ]; then
  #align canonical text with the monophone model 
  if [ ! -d exp/ali_mono_align_ctm ];then
  	steps/align_si_gop_ctm.sh  --nj 2 --cmd "$train_cmd" \
                    data/gop_combined data/lang_nosp  exp/mono_all_data exp/ali_mono_align_ctm
  fi
fi


if [ $stage -le 3 ]; then
  #align modified text with the monophone model --- GOP numerator 
  steps/align_si_gop_ctm.sh  --nj 2 --cmd "$train_cmd" \
                    data/gop_combined $langDir exp/mono_all_data $aliDir
fi




echo "done"
exit 0

