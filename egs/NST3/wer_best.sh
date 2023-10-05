dir=$1
for x in $dir/decode*; do [ -d $x ] && [[ $x =~ "$1" ]] && grep WER $x/wer_* | utils/best_wer.sh; done

