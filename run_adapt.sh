#!/bin/bash


# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.

# This script constructs a new phoneme-based lexicon based on a supplied dictionary
# file (defaults to cantab-TEDLIUM.dct)

dict=../db/cantab-TEDLIUM/cantab-TEDLIUM.dct
#dict=../db/cantab-TEDLIUM/TEDLIUM.152k.dic
lm_folder=adapt_lm
langdir=data/lang_phn

# Generate pronunciations for words in supplied text file "newwords.txt"

# Get pronunciations from CMU lex tool (requires internet connectivity!)
curl -s `curl -s -F "wordfile=@newwords.txt" http://www.speech.cs.cmu.edu/cgi-bin/tools/logios/lextool.pl | awk ' /DICT/ { print $3 } '` | sed 's/ TS$/ T S/' | sed 's/ IX/ EH/g' | awk '{printf tolower($1 " "); for (i=2; i<=NF; i++)  
   printf ($i " "); print ""}' > newwords.dct
cat newwords.dct $dict | sort > newdict.dct


# Construct the phoneme-based lexicon
echo "Constructing the phoneme-based lexicon"
../local/tedlium_prepare_phn_dict.sh --srcdict newdict.dct || exit 1;

# Compile the lexicon and token FSTs
echo "Compiling the lexicon and token FSTs"
../utils/ctc_compile_dict_token.sh data/local/dict_phn data/local/${langdir}_tmp $langdir || exit 1;

# build our own ARPA LM from user provided (or default) training text
# train_lms.sh takes lang_bd/words.txt and wordlist.txt as input; create anew from dictionary
# creates output file adapt_lm/3gram-mincount/lm_pr6.0.gz

# why doesn't this work?
#cat $langdir/words.txt | awk '{print $1}' | sort | uniq > wordlist.txt
cat newdict.dct | awk '{print $1}' | sort | uniq > wordlist.txt

# this works
#cat $dict | awk '{print $1}' | sort | uniq > wordlist.txt

cp $langdir/words.txt lang_bd
# lingering data corrupts output, so clear first
rm -rf $lm_folder
. path.sh
train_lms.sh example_txt $lm_folder

# Compose the decoding graph but use the just-built ARPA LM
echo "Finding OOV words in ARPA LM but not in our words.txt"
arpa_lm=$lm_folder/3gram-mincount/lm_pr6.0.gz
oov_list=$langdir/oovs.txt

gunzip -c $arpa_lm | utils/find_arpa_oovs.pl $langdir/words.txt > $oov_list || exit 1;

echo "Composing the decoding graph using our own ARPA LM"
../local/tedlium_decode_graph.sh --arpa_lm $arpa_lm --oov_list $oov_list $langdir || exit 1;

echo "Finished adapting LM"