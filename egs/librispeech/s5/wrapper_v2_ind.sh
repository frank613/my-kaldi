#!/bin/bash
# wrapper  


#cat phones.txt | cut -d' ' -f1 | grep '[A-Z]\+[0-9]' | cut -d'_' -f1 | sed 's/\([A-Z]\+\).*/\1/g' | sort -u | tr '\n' ' '
#vowel_set=(AA AE AH AO AW AY EH ER EY IH IY OW OY UH UW B CH D DH F G HH JH K L M N NG P R S SH SIL SPN T TH W V W Y Z ZH)
#vowel_set=(AA AE AH AO AW AY EH ER EY IH IY OW OY UH UW B CH D DH F G HH JH K L M N NG P R S SH T TH W V W Y Z ZH)
#vowel_set_shorted=(AH AO AW AY EH ER EY IH IY OW OY UH UW B CH D DH F G HH JH K L M N NG P R S SH T TH W V W Y Z ZH)
vowel_set_shorted=(AO AW EH EY IH OW UH B CH D F G HH K L M S T Z)

for vowel in AH;do
	for vowel2 in ${vowel_set_shorted[@]};do
		if [ ! $vowel = $vowel2 ]; then
			echo "processing" "$vowel -> $vowel2"
			./gop_replace_phoneme_v2_posind.sh ${vowel}_${vowel2} || { echo "exit"; exit 1; } 
	        fi	       

	done
done

