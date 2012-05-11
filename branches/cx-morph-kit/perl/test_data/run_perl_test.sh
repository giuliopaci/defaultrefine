#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Run regression test for perl code"
  echo "Usage: run_perl_test.sh <svn_dir> <defref_dir>"
  echo "       svn_dir    = directory where Meraka svn repository"
  echo "       defref_dir = directory defaultrefine checked out"
  exit
fi

SVN_DIR=$1
DEFREF_DIR=$2

ln -s $SVN_DIR/hlt/asr/dicts/scripts . 
cp $DEFREF_DIR/python/test_data/setswana-dict/setswana.shuf.* .

#------------------------------------------------------------------------------

# Reformat train dict for Perl scripts
perl scripts/prep_dict.pl setswana.shuf.3988.dict dm setswana.train.perl_dict setswana.gmap setswana.pmap setswana.prep_dict_train.log

# Reformat test dict for Perl scripts (using mapping generated during previous step
perl scripts/remap_dict.pl gra setswana.shuf.1024.dict dm setswana.gmap ltr setswana.test.no-diac.dict
perl scripts/remap_dict.pl pho setswana.test.no-diac.dict dm setswana.pmap ltr setswana.test.no-diac.1-char.dict
perl scripts/reformat_dict.pl dm sc setswana.test.no-diac.1-char.dict setswana.test.perl_dict

# Extract rules
perl scripts/extract_rules.pl setswana.train.perl_dict setswana.rules setswana.gnulls setswana.extract_rules.log

# Recreate train and test dict based on rules
perl scripts/words_from_dict.pl setswana.shuf.3988.dict dm setswana.train.words
perl scripts/words_from_dict.pl setswana.shuf.1024.dict dm setswana.test.words
perl scripts/create_dict.pl setswana.train.words setswana.rules setswana.gnulls setswana.train.recreated.dict -g setswana.gmap ltr
perl scripts/create_dict.pl setswana.test.words setswana.rules setswana.gnulls setswana.test.recreated.dict -g setswana.gmap ltr

# Reformat recreated train dict for accuracy comparison
perl scripts/remap_dict.pl gra setswana.train.recreated.dict htk setswana.gmap ltr setswana.train.recreated.no-diac.dict
perl scripts/reformat_dict.pl htk sc setswana.train.recreated.no-diac.dict setswana.train.recreated.perl_dict

# Reformat recreated test dict for accuracy comparison
perl scripts/remap_dict.pl gra setswana.test.recreated.dict htk setswana.gmap ltr setswana.test.recreated.no-diac.dict
perl scripts/reformat_dict.pl htk sc setswana.test.recreated.no-diac.dict setswana.test.recreated.perl_dict

# Eval acc of train and test dict
cut -f 2 setswana.pmap > setswana.phones
perl scripts/g2p.pl accuracy setswana.train.perl_dict setswana.train.recreated.perl_dict phone setswana.phones setswana.train.result
perl scripts/g2p.pl accuracy setswana.test.perl_dict setswana.test.recreated.perl_dict phone setswana.phones setswana.test.result

# Summarise results
wc setswana.*.perl_dict > setswana.summary
grep WORD setswana.t*.result | sed s/WORD/PHONE/ >> setswana.summary
grep SENT setswana.t*.result | sed s/SENT/WORD/ >> setswana.summary

#------------------------------------------------------------------------------

