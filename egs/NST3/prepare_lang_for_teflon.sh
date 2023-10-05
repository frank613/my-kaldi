#!/bin/bash

stage=0

. ./cmd.sh
. ./path.sh

if [ $stage -le 0 ]; then
	utils/prepare_lang.sh data/dict_nosp_teflon "<unk>" data/local/lang_teflon data/lang_teflon
fi

echo "done"
