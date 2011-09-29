#!/usr/bin/perl
# -w
# -d:DProf

#--------------------------------------------------------------------------
use g2pDefref;
use g2pFiles;
use g2pArchive;
use g2pDict;
use g2pAlign;
use g2pOlist;
use Time::Local;
use g2pRulesHelper;
use strict;

#--------------------------------------------------------------------------

sub cl_predict ($$$) {
	my ($word,$rf,$gf) = @_;
	$rtype = 'defrefine';
	my %gnulls=();
	fread_gnull_list($gf,%gnulls);
	fread_rules_dr($rf);
	my @info = ();
	my %dict=();
	my %stat=();
	my $result = predict_one_dr($word,%gnulls,@info,%dict,%stat);
	print "$result\n";
}


sub cl_predict_info ($$$) {
	my ($word,$rf,$gf) = @_;
	$rtype = 'defrefine';
	my %gnulls=();
	fread_gnull_list($gf,%gnulls);
	fread_rules_dr($rf);
	my @info=();
	my %dict=();
	my %stat=();
	my $result = predict_one_dr($word,%gnulls,@info,%dict,%stat);
	print "$result\n";
	foreach my $i (@info) {
		print "$i;$rule{$i};$rulecnt{$i};$numfound{$i}\n";
	}
}

sub cl_predict_file ($$$$$$) {
	my ($wf,$rf,$gf,$df,$hasIgnore,$if) = @_;
	print "Generating pronunciations:\nWord file:\t$wf\n";
	print "Rules file:\t$rf\nGnulls file:\t$gf\nDict file:\t$df\n";
	my @ignore = ();
	if ($hasIgnore==1) {
		print "Ignore file:\t$if\n";
		fread_words($if,@ignore);
	}
	my (%gnulls,%dict,%stat);
	fread_rules_dr($rf);
	fread_gnull_list($gf,%gnulls);
	predict_list($wf,%gnulls,@ignore,%dict,%stat);
	fwrite_dict($df,%dict,%stat);
}

#--------------------------------------------------------------------------

sub cl_align ($$$$$$) {
	my ($df,$ff,$cf,$af,$gf,$pre) = @_;
	print "Aligning dictionary:\n";
	print "Dict file:\t$df\nAligned dict file:\t$af\nGnulls file:\t$gf\n";
	$g2pFiles::grpt = $ff;
        $g2pFiles::phnt = $cf;
	falign_dict($df,$af,$gf,$pre);
}

sub cl_extract_patts($$$) {
	my ($featf,$dataf,$pattsf) = @_;
	print "Extracting patterns for single feat:\n";
	print "Feat file:\t$featf\nData file:\t$dataf\nPatterns file:\t$pattsf\n";
	custom_extract_patts($featf,$dataf,$pattsf);
}

#--------------------------------------------------------------------------

sub cl_find_rules_single ($$$) {
	my ($feat,$pattsf,$rf) = @_;
	print "Generating rule set for single feat:\n";
	print "feat:\t$feat\nPattsfile:\t$pattsf\nRules file:\t$rf\n";
	find_rules_single($feat,$pattsf,$rf);
}


sub cl_find_rules_all ($$$) {
	my ($featf,$pattsf,$rf) = @_;
	print "Generating rule set for all features:\n";
	print "Features file:\t$featf\nPattsfile:\t$pattsf\nRules file:\t$rf\n";
	my @feats;
	fread_graphs($featf,@feats);
	foreach my $f (@feats) {
		find_rules_single($f,"$pattsf.$f","$rf.$f");
		my $t = gmtime();
		print "TIME\trules written [$f]:\t\t$t\n";
	}

	if ( -e $rf ) {
		system "rm -v $rf";
	}
	foreach my $f (@feats) {
		my $gf = "$rf.$f";
		system "cat $gf >> $rf";
		my $t = gmtime();
		print "TIME\trules written [$f]:\t\t$t\n";
	}
}

#--------------------------------------------------------------------------

sub print_usage () {
	print "Usage: predict <data> <rules> <gnulls>\n";
	print "       predict_info <data> <rules> <gnulls>\n";
	print "       predict_file <datafile> <rules> <gnulls> <newdict> [ <ignore-characters> ]\n";
	print "       align <datafile> <aligned_datafile> <gnulls>\n";
	print "       patts <feature_file> <aligned_datafile> <patts_prefix>\n";
	print "       rules_single <f> <pattsfile> <newrules>\n"; 
	print "       rules_all <featurelist> <patts_prefix> <newrules_prefix>\n"; 
}

#--------------------------------------------------------------------------

if (@ARGV < 1) {
	print_usage;
	exit;
}

if ($ARGV[0] eq "predict") {
	if ($#ARGV==3) { cl_predict $ARGV[1],$ARGV[2],$ARGV[3] }
	else {print "Usage: predict <data> <rules> <gnulls>\n"} 
} elsif ($ARGV[0] eq "predict_info") {
	if ($#ARGV==3) {cl_predict_info $ARGV[1],$ARGV[2],$ARGV[3] }	
	else {print "Usage: predict_info <data> <rules> <gnulls>\n";} 
} elsif ($ARGV[0] eq "predict_file") {
	if (scalar @ARGV==6) {
		cl_predict_file $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],1,$ARGV[5]; 
	} elsif (scalar @ARGV==5) {
		cl_predict_file $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],0,""; 
	} else {
		print "Usage: predict_file <datafile> <rules> <gnulls> <newdict> [ <ignore-characters> ]\n";
		print "The optional <ignore-characters> is a file of all characters to be kept in the orthography\n";
		print "but ignored when predicting pronunciations\n";
	} 
} elsif ($ARGV[0] eq "align") {
	if (scalar @ARGV==6) {cl_align $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5],0}
	else { print "Usage: align <datafile> <feature_file> <class_file> <aligned_datafile> <gnulls>\n"} 
} elsif ($ARGV[0] eq "patts") {
	if (scalar @ARGV==4) { cl_extract_patts $ARGV[1],$ARGV[2],$ARGV[3];
	} else { print "Usage: patts <feature_file> <aligned_datafile> <patts_prefix>\n";}
} elsif ($ARGV[0] eq "rules_single") {
	if (scalar @ARGV==4) { cl_find_rules_single $ARGV[1],$ARGV[2],$ARGV[3];
	} else { print "Usage: rules_single <f> <pattsfile> <newrules>\n";}
} elsif ($ARGV[0] eq "rules_all") {
	if (scalar @ARGV==4) { cl_find_rules_all $ARGV[1],$ARGV[2],$ARGV[3];
	} else { print "Usage: rules_all <featurelist> <patts_prefix> <newrules_prefix>\n"; }
} else { print_usage }


#--------------------------------------------------------------------------

