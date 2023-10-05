import sys
import pandas as pd
import pdb
import os
import re

audio_dir = "/talebase/data/speech_raw/teflon_no/speech16khz"
re_phone = re.compile(r'([@:a-zA-Z]+)([0-9])?(_\w)?')

if __name__ == "__main__":

    if len(sys.argv) != 5:
        sys.exit("this script takes 4 arguments <teflon_csv_file> <model lexicon> <phoneme-map> <out-dir>.\n \
        , it parses the csv file and prepare the test data for kaldi recipe")

    df = pd.read_csv(sys.argv[1])
    #pdb.set_trace()

    if os.path.isdir(sys.argv[4]):
        sys.exit("folder already exists")
    os.mkdir(sys.argv[4])
    #step1 prepare the wav.scp, utt2spk
    wav_list = []
    for filen in df["File name"]:
        target = os.path.join(audio_dir, filen)
        if os.path.exists(target):
            wav_list.append((filen.split('.')[0], target))

    pdb.set_trace()
    wav_list = list(set(wav_list))
    wav_list.sort(key=lambda x: x[0])

    utt2spk_list = []
    for uttid in map(lambda x: x[0], wav_list):
        spk,word = uttid.split('_')
        utt2spk_list.append((uttid,spk))

    utt2spk_list = list(set(utt2spk_list)) 
    utt2spk_list.sort(key=lambda x: x[0])

    #step2 prepare the text
    text_list = []
    for filen,word in df[["File name", "Word"]].values.tolist():
        uttid = filen.split('.')[0]
        text_list.append((uttid,word))
    text_list = list(set(text_list)) 
    text_list.sort(key=lambda x: x[0])

    #step3 word.txt file
    word_list = set([ pair[1] for pair in text_list ])
    
    #step4 prepare the annotation file(verify and convert phonetic anno)
    p_map = {}
    with open(sys.argv[3]) as ifile:
        for line in ifile:
            fields = line.strip().split()
            if len(fields) != 2:
                sys.exit('bad input in phoneme mapping')
            p_map[fields[0]] = fields[1]

    lexicon_map = {}
    with open(sys.argv[2]) as ifile:
        for line in ifile:
            fields = line.strip().split()
            word = fields[0]
            phoneme = [ re_phone.match(ph).group(1) for ph in fields[2:] ]
            lexicon_map[word]= phoneme  
    
    #overall score == 0 means broken audio?
    score_list = df.loc[df['Score'] != 0, ['File name','Score', 'Assessor']].values.tolist()
    score_list = [ [f.split('.')[0], s,a]for f,s,a in score_list]
    #phoneme score
    phoneme_score_list = df.loc[df['Score'] != 0, ['File name', 'Word', 'Pronunciation','pronScores', 'Assessor']].values.tolist()
    #phoneme_score_list = map(lambda x: x[0].split('.')[0], phoneme_score_list)
    phoneme_score_list = [[f.split('.')[0],w,p,s,a] for f,w,p,s,a in phoneme_score_list]
    #check and convert to kaldi phonemes
    remove_index = []
    for i,item in enumerate(phoneme_score_list):
        #print(item)
        #print(lexicon_map[item[1]])
        assert(len(item[2].split()) == len(item[3].split()))
        if item[1] not in lexicon_map.keys():
            print("warning word {} not in the dictionary".format(item[1]) )
            remove_index.append(i)
            continue
        if len(item[2].split()) != len(lexicon_map[item[1]]):
            print("warning annotation for word {0} ({1}) does not agree with that in the dictionary ({2})".format(item[1], item[2], ' '.join(lexicon_map[item[1]])))        
            remove_index.append(i)
            continue
        new_ph = []
        for ph in item[2].split():
            assert(ph in p_map.keys())
            new_ph.append(p_map[ph])
        item[2] = new_ph
    score_list.sort(key=lambda x: x[0])
    phoneme_score_list = [ item for i,item in enumerate(phoneme_score_list) if i not in remove_index ]
    phoneme_score_list.sort(key=lambda x: x[0])


    print("data-prepared")
    #write wav.scp
    with open(os.path.join(sys.argv[4],'wav.scp'), 'w') as ofile:
        for item in wav_list:
            ofile.write(' '.join(item) + '\n')

    #write utt2spk and spk2utt
    with open(os.path.join(sys.argv[4], 'utt2spk'), 'w') as ofile:
        for item in utt2spk_list: 
            ofile.write(' '.join(item) + '\n')

    os.system("./utils/utt2spk_to_spk2utt.pl {}/utt2spk > {}/spk2utt".format(sys.argv[4], sys.argv[4]))

    #write text
    with open(os.path.join(sys.argv[4], 'text'), 'w') as ofile:
        for item in text_list:
            ofile.write(' '.join(item) + '\n')

    #write word.txt
    #with open(os.path.join(sys.argv[4], 'word.txt'), 'w') as ofile:
    #    for item in word_list:
    #        ofile.write(item + '\n')

    #write scores
    with open(os.path.join(sys.argv[4], 'scores'), 'w') as ofile:
        for item in score_list:
            ofile.write(item[0] + ' ' + str(item[1]) + ' ' + item[2].split()[0] + '\n')

    #write phoneme trans
    with open(os.path.join(sys.argv[4], 'phoneme_anno') ,'w') as ofile:
        for item in phoneme_score_list:
            ofile.write(item[0] + ' ' + ",".join(item[2]) + ' ' + item[3].replace(" ", ",") + " " + item[4].split()[0] + '\n')
