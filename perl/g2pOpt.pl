#!/usr/bin/perl

use GTree;
use strict;
use g2pRulesHelper;

my $debug=0;

#--------------------------------------------------------------------------------;

#my $test = GTree->new();
#$test->name("test");
#$test->count(10);
#$test->parents("here","are","parents");
#$test->kids("here","are","kids");
#
#my $parentstr = join ' ',@{$test->parents};
#printf "HERE %s %d %s\n",$test->name,$test->count,$parentstr;

#--------------------------------------------------------------------------------;

sub rules_frompats_opt($\%\%\%\%) {
	my ($g,$patp,$rulep,$rulecntp,$numfoundp) = @_;
	print "<p>-- Enter rulegroups_from_pats_olist_large [$g]\n" if $debug;
	
	#Extract the best <$g>-specific rulegroups based on the set of patterns in <$gpatp>
	#Update globals %rule, %rorder and %numfound
    
	my $grulenum=1;
        my $root = new GTree("-$g-");
	my $log=$root->logging;
	$log->record('init');
        $root->build_tree($patp);
	$log->record('build_tree');
        #$root->traverse;
        #$root->traverse_net;
   
	#update 'best' if necessary, and pick winning rule      
	my $winner=$root->get_winning_rule;
	$log->record('get_winning_rule');
	while ($winner) {
            my $newrule = $winner->name;
            my $cnt = $winner->max;
	    my $p = $winner->outcome;
	    $rulep->{$newrule}=$p;
	    $rulecntp->{$g}[$grulenum]=$newrule;
            $numfoundp->{$newrule}=$cnt;
            print "$g:\t[$grulenum]\t[$newrule] --> [$p]\t$cnt\n";
	    #remove rule and update counts, max and order
            $root->remove_rule($winner);
	    $log->record('remove_rule');
	    #$root->traverse_net;
            $grulenum++;
	    $winner=$root->get_winning_rule;
	    $log->record('get_winning_rule');
	}
        #my @missed = $root->leaves;
        my @missed=();
	foreach my $w (@missed) {
		print "Error: missed $w\n";
	}
	
	#Add 1-g backoff rule, if missed by other rules
	if (!(exists $rulep->{"-$g-"})) {
		$rulep->{"-$g-"}=$rulep->{$rulecntp->{$g}[1]};
		$rulecntp->{$g}[0]="-$g-";
		print "Adding backoff\t[-$g-] -> $rulep->{$rulecntp->{$g}[1]}\n";
	} else {
		$rulecntp->{$g}[0]="-1";
	}
	$log->summarise();
}

sub fread_tree_patts(\%$) {
    my ($patp,$fname)=@_;
    open IH, "$fname" or die "Error opening $fname\n";	
    while (<IH>) {
	chomp;
	my ($p,$w) = split ";";
	my @wordpats = get_all_pats_limit($w,1,1000);   #keep limit for later
	foreach my $pat (@wordpats) {
	    my $len = (length $pat) - 2;
	    $patp->{$len}{$pat}{$p}++;
	}
    }
    close IH;
}

sub fgen_rules_opt($$$)  {
        my ($g,$pattsfile,$rulefile)=@_;
        my %rule=();
        my %rulecnt=();
        my %numfound=();
        my %gpatts=();
        my %gwords=();
        my $found=0;

	if (-e $pattsfile) {
            fread_tree_patts(%gpatts,$pattsfile);
            print "Finding best rules for [$g]\n";
	    rules_frompats_opt($g,%gpatts,%rule,%rulecnt,%numfound);
            $found=1;
        }

        if ($found==0) {
                $rule{"-$g-"} = "0";
                $rulecnt{$g}[0]="-$g-";
                $numfound{"-$g-"}=0;
                print "$g:\t[0]\t[-$g-] --> 0\n"; 
        }
}

#--------------------------------------------------------------------------------;

sub print_usage {
        print "Usage: ./g2pOpt.pl extract <g> <pattsfile> <rulesfile>\n";
}


if ($ARGV[0] eq "extract") {
        if ($#ARGV==3) { fgen_rules_opt $ARGV[1],$ARGV[2],$ARGV[3] }
        else {print "Usage: extract <g> <pattsfile> <rulesfile>\n"}
} else {
	print_usage;
}

#fgen_rules_opt('e','test.patts','test.rules');
#fgen_rules_opt('e','current/gr01.dict.train.patts.1.100.e','test.rules');
#fgen_rules_opt('e','test.patts.400','test.rules');
#fgen_rules_opt('e','current/gr01.dict.train.patts.1.1000.e','test.rules');
#--------------------------------------------------------------------------------;
