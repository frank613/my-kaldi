#!/bin/bash
# wrapper  


#cat phones.txt | cut -d' ' -f1 | grep '[A-Z]\+[0-9]' | cut -d'_' -f1 | sed 's/\([A-Z]\+\).*/\1/g' | sort -u | tr '\n' ' '
#vowel_set=(AA AE AH AO AW AY EH ER EY IH IY OW OY UH UW B CH D DH F G HH JH K L M N NG P R S SH SIL SPN T TH W V W Y Z ZH)
#vowel_set=(AA AE AH AO AW AY EH ER EY IH IY OW OY UH UW B CH D DH F G HH JH K L M N NG P R S SH T TH W V W Y Z ZH)
#vowel_set_shorted=(AH AO AW AY EH ER EY IH IY OW OY UH UW B CH D DH F G HH JH K L M N NG P R S SH T TH W V W Y Z ZH)
pFile="./p-set.txt"
vowel_set_shorted=(AA AE AH AO EH ER IH IY OW OY UH UW B CH D F G HH JH K L M P R S T W Y Z)
#vowel_set_shorted=$(cat $pFile)

nj=7

length=${#vowel_set_shorted[@]} 

count=0
for vowel in ${vowel_set_shorted[@]};do
	wait
	for vowel2 in ${vowel_set_shorted[@]};do
		if [ ! $vowel = $vowel2 ]; then
			count=$((count+1))
			echo "processing" "$vowel -> $vowel2"
			./gop_replace_phoneme_v2.sh ${vowel}_${vowel2} || { echo "exit"; exit 1; } &
			#sleep 5 &
			if [ $count -ge $nj ];then
				wait
				count=0
			fi
	        fi	       

	done
done

