#!/bin/bash
# replace unique words in one sentence with 

if [ $# -ne 3 ]; then
    echo "Usage: $0 <input-dict-file>" >&2
    exit 1
fi


inFile=$1

generate_dict() {
  frm=$1
  to=$2
  ##wether to keep streess in the target phoenme, Ture/False
  keepStress=$3
  dict=$4
  if [ $keepStress == "True" ]; then
	  #gawk -v frm=$frm -v to=$to '{ a=$1"\t"; for(i=2; i<=NF; i++) { if ($i ~ frm) {match($i, /[A-Z]+([0-9])*/, ary); { a=a to ary[1] " "}} else {a=a $i " "}} {print substr(a, 1, length(a)-1)}}' $dict | sort -u > ./out/$1_$2.lex
	  gawk -v frm=$frm -v to=$to '{ a=$1"\t"; for(i=2; i<=NF; i++) { if ($i ~ frm) {match($i, /[A-Z]+([0-9]_[BEIS])*/, ary); { a=a to ary[1] " "}} else {a=a $i " "}} {print substr(a, 1, length(a)-1)}}' $dict | sort -u 
  elif [ $keepStress == "False" ]; then
	  #gawk -v frm=$frm -v to=$to '{ a=$1"\t"; for(i=2; i<=NF; i++) { if ($i ~ frm) {a=a to " "} else {a=a $i " "}} {print substr(a, 1, length(a)-1)}}' $dict | sort -u > ./out/$1_$2.lex
	  gawk -v frm=$frm -v to=$to '{ a=$1"\t"; for(i=2; i<=NF; i++) { if ($i ~ frm) {match($i, /[A-Z]+([0-9]*)(_[BEIS]*)/, ary); {a=a to ary[2] " "}} else {a=a $i " "}} {print substr(a, 1, length(a)-1)}}' $dict | sort -u 
  else
	echo "the third argument must be False/True" 1>&2 && exit 1
  fi
}

frm=$2
to=$3

vowel_set=(AA AE AH AO AW AY EH ER EY IH IY OW OY UH UW)
cons_set=(B CH D DH F G HH JH K L M N NG P R S SH SIL SPN T TH W V W Y Z ZH)

if [[ " ${vowel_set[*]} " == *" $frm "*  ]] && [[ " ${vowel_set[*]} " == *" $to "* ]]; then
	generate_dict $frm $to True $inFile
else
	generate_dict $frm $to False $inFile
fi

