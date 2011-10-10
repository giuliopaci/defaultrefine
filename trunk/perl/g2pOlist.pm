package g2pOlist;

use g2pFiles;
use g2pAlign;
use g2pDict;
use Time::Local;
#use AnyDBM_File;
use Graph;
#use g2pTrees;
use g2pRulesHelper;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;
	$msg = 0;
	
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(%rule %rorder %numfound &fread_rules_olist &fwrite_rules_olist &g2p_word_olist &fgen_rulegroups_single &fgen_rulegroups_single_large &conv_rules_olist &restrict_rules &extract_patterns_olist &get_words_per_pat_match &olist_add_word &olist_tree_from_rules &olist_fast_word &olist_fast_file &olist_add_upto_sync &id_pos_errors &extract_patterns_olist_1word &fgen_rulegroups_single_large_wspecific &predict_one_wspecific);
}

#--------------------------------------------------------------------------

sub fread_rules_olist($) {
	#Read ruleset from file
	#Update globals %rule and %rorder
		
	my $fname = shift @_;
	print "-- Enter fread_rules_olist: $fname\n" if $debug;
	open RH, "<:encoding(utf8)", "$fname" or die "Error opening $fname\n";

	%rule = ();
	%rorder=();
	%rulecnt=();
	%numfound=();
	my ($grph,$left,$right,$phn,$cnt,$numi);
	while (<RH>) {
		chomp;
		my @line=split ";";
		if ($#line==4) {
			($grph,$left,$right,$phn,$cnt) = @line;
			$numi=0;
		} elsif ($#line==5) {
			($grph,$left,$right,$phn,$cnt,$numi) = @line;
		} else {
			die "Error: problem with $fname rule format";
		}
		my $pattern = "$left-$grph-$right";
		$rule{$pattern} = $phn;
		$rorder{$grph}[$cnt]=$pattern;
		$rulecnt{$pattern}=$cnt;
		$numfound{$pattern}=$numi;
		$grulenum=$cnt;
	}
	close RH;
	if ($use_rulepairs==1) {
		fread_rulepairs("$fname.rulepairs");
	}
}


sub fwrite_rules_olist($) {
	#Write ruleset to file
	#Write rules from globals %rule, %rorder and %numfound
		
	my $fname = shift @_;
	print "-- Enter fwrite_rules_olist: $fname\n" if $debug;
	open OH, ">:encoding(utf8)", "$fname" or die;
	
	foreach my $g (sort keys %rorder) {
		$deleted=0;
		my @rlist = @{$rorder{$g}};
		foreach my $i (0..$#rlist) {
			my $r = $rlist[$i];
			if ($r eq "-1") {
				$deleted++;
			} else {
				my $rulenum = $i-$deleted;
				my $numi = $numfound{$r};
				if ($r !~ /(.*)-(.*)-(.*)/) {die "Error in rule format\n"};
				print OH "$2;$1;$3;$rule{$r};$rulenum;$numi\n";
			}
		}
	}
	close OH;
}

#--------------------------------------------------------------------------

sub bycontext { (length $a <=> length $b) || ($rulecnt{$b}<=>$rulecnt{$a}) || (get_sym($a) <=> get_sym($b)) || (right_first($b)<=>right_first($a) ) }

sub conv_rules_olist {
#Rewrite rule global vars
#Update global $rorder based on globals $context and $rulecnt
	foreach my $g (keys %context) {
		my @rlist = sort bycontext keys %{$context{$g}};
		@{$rorder{$g}}=@rlist;
	}
}

sub restrict_rules_v1($$$) {
	my ($g,$num,$cutoff) = @_;
	my $seen=0;
	my @rlist = @{$rorder{$g}};
	my $rlistnum = @rlist;
	$rlistnum--;
	my $i=$rlistnum;
	while ($i>=0) {
		my $pat = $rlist[$i];
		my $numi = $numfound{$pat};
		if ($numi > $cutoff) {
			$seen++;
		}
		if ($seen<$num) {
			if (!($pat eq "-$g-")) {
				delete $rule{$pat};
				delete $rulecnt{$pat};
				delete $numfound{$pat};
				$rorder{$g}[$i]=-1;
			}
		} else {
			last;
		}
		$i--;
	}
}

sub restrict_rules($$$) {
	my ($g,$num,$cutoff) = @_;
	my $seen=0;
	my @rlist = @{$rorder{$g}};
	my $rlistnum = @rlist;
	my $i=0;
	my $docut=0;
	while ($i<$rlistnum) {
		if ($docut==1) {
			delete $rule{$pat};
			delete $rulecnt{$pat};
			delete $numfound{$pat};
			$rorder{$g}[$i]=-1;
		} else {
			my $pat = $rlist[$i];
			my $numi = $numfound{$pat};
			if ($numi <= $cutoff) {
				$seen++;
			}
			if ($seen>=$num) {
				$docut=1;
			}
		}
		$i++;
	}
}

#--------------------------------------------------------------------------

sub g2p_word_olist($$\@){
	($word,$soundp,$infop) = @_;
	chomp $word;
	my @slist=();

	my $wordend = (length $word)-1;
	my $l = " "; 
	my $g = substr $word,0,1; 
	my $r="";
	if ($wordend>0) {
		$r = (substr $word,1)." ";
	} else {
		$r = " ";
	}
			
	#foreach graph->phone
	foreach my $i (0 .. $wordend) {
		my @rlist = @{$rorder{$g}};
		$ri=$#rlist;
		$found=0;
		
		my $pat = $l."-".$g."-".$r;
		while ($ri>=0) {
			if ($pat =~ /$rlist[$ri]/) {
				$found=1;
				$rmatch=$rlist[$ri];
				last;
			}
			$ri--;
		}
		if ($found==0) {
			die "No matching rule found! [$word][$i]\n";
		} else { 
			$slist[$i]=$rule{$rmatch};
			$infop->[$i]=$rmatch;
			print "[$rmatch] -> $slist[$i]\n" if $debug;
		}
		$l = $l.$g; 
		$g = substr $r,0,1; 
		$r=substr $r,1; 
	}
	$$soundp=join "",@slist;
	$$soundp =~ s/0//g;
	#$$soundp =~ s/ //g;
	print "<p>Result: $word -> [$$soundp]\n" if $debug;
	return 0;
}

sub predict_one_wspecific($$) {
	my ($wordpat,$rulesfn) = @_;
	fread_rules_olist($rulesfn);
	$wordpat =~ /.*-(.)-.*/;
	my @rlist = @{$rorder{$1}};
        $ri=$#rlist;
        $found=0;
        while ($ri>=0) {
                if ($wordpat =~ /$rlist[$ri]/) {
                        $found=1;
                        $rmatch=$rlist[$ri];
                        last;
                }
		$ri--;
	}
	if ($found==0) {
		die "No matching rule found! [$word][$i]\n";
	} 
	return $rule{$rmatch};
}

#--------------------------------------------------------------------------

sub id_pos_errors($$$$\%) {
	my ($sf,$netcnt,$actcnt,$cutoff,$errp) = @_;
        
	open IH, "<:encoding(utf8)", "$sf" or die "Error reading $sf\n";

	my %single_rules=();
        while (<IH>) {
                chomp;
                @parts=split /;/;
                if (@parts != 4) {
			die "Error in file format: $sf,[$_]\n";
		}
		my ($num1,$num2,$w,$r) = @parts;
		$w =~ s/ //g;
		$w =~ s/-//g;
		if (($num1<=$netcnt)&&($num2<=$actcnt)) {
			$single_rules{$w}{$r}=1;
		}
	}
	close IH;

	foreach my $w (keys %single_rules) {
		my @srules = keys %{$single_rules{$w}};
		my $srulesnum = @srules;
		#print "HERE $w @srules $srulesnum [$cutoff]\n";
		if ($srulesnum>=$cutoff) {
			foreach my $r (@srules) {
				$errp->{$w}{$r}=1;
				#print "FOUND! $r [$w]\n";
			}
		}
	}	
}

#--------------------------------------------------------------------------

sub fwrite_patts_olist(\%$) {
	my ($allp,$fname) = @_;
	foreach my $g (keys %$allp) {
		open OH, ">>:encoding(utf8)", "$fname.$g" or die "Error opening $fname.$g\n";
		my $gp = $allp->{$g}; 
		foreach my $pat (keys %$gp) {
			print OH "$pat\n";
			delete $gp->{$pat};
		}
		close OH;
	}
	my @graphs=();
	read_graphs(@graphs);
	push @graphs,'0';
	foreach my $g (@graphs) {
		`touch "$fname.$g"`
	}
}

#--------------------------------------------------------------------------

sub extract_patterns_olist_1word($$) {
	my ($word,$pron) = @_;
	print "<p>-- Enter extract_patterns_olist_1word: $word\n" if $debug;
	my %return_patts=();
	my @gstr = split //,$word;
	push @gstr," ";
	unshift @gstr," ";
	my @pstr = split //,$pron;
	push @pstr," ";
	unshift @pstr," ";
	my $patstr = join "",@gstr;
	for my $i (1..$#gstr-1) {
		my $g = $gstr[$i];
		my $p = $pstr[$i];
		my $l = substr ($patstr,0,$i);
		my $r = substr ($patstr,$i+1);
		my $w = $l."-".$g."-".$r;
		$return_patts{$g}{$w}=$p;
	}
	return %return_patts;
}


sub extract_patterns_olist(\%\%$) {
	my ($agdp,$apdp,$pattsfile) = @_;
	print "<p>-- Enter extract_patterns_olist\n" if $debug;
	my %all = ();
	my $max_words=10000;
	frm_patts($pattsfile,$grpt);
	my $cnt=0;
	foreach $word (keys %{$agdp}) {
		my @gstr = @{$agdp->{$word}};
		push @gstr," ";
		unshift @gstr," ";
		my @pstr = @{$apdp->{$word}};
		push @pstr," ";
		unshift @pstr," ";
		my $patstr = join "",@gstr;
		my $wlen = length $patstr;
		for my $i (1..$#gstr-1) {
			my $g = $gstr[$i];
			my $p = $pstr[$i];
			my $l = substr ($patstr,0,$i);
			my $r = substr ($patstr,$i+1);
			my $w = $l."-".$g."-".$r;
			$all{$g}{"$p;$w"}=1;
		}
		$cnt++;
		if ($cnt==$max_words) {
			fwrite_patts_olist(%all,$pattsfile);
			$cnt=0;
		}
		delete $agdp->{$word};
		delete $apdp->{$word};
	}
	fwrite_patts_olist(%all,$pattsfile);
}

#--------------------------------------------------------------------------

sub get_top_pats_v1($\%\%$\@) {
	#Find next pat to add as rule
	my ($g,$posp,$caughtp,$pp,$nrlp)=@_;
	my $max=0;
	my $maxsize=100;
	my $maxpat="";
	my $maxp="";
	my $found=0;
	@$nrlp=();
	my $nr="";
	foreach my $pat (keys %$posp) {
		my $patp=$posp->{$pat};
		foreach my $p (keys %$patp) {
			my $gtot = $patp->{$p};
			#foreach my $pc (keys %{$patp}) {
			#	next if $pc eq $p;
			#	$gtot-=$patp->{$pc};
			#}
			my $confp=$caughtp->{$pat};
			foreach my $pc (keys %{$confp}) {
				next if $pc eq $p;
				$gtot-= $confp->{$pc};
			}
			my $size=(length $pat)-2;
			if (($gtot>$max)||
			    (($gtot==$max)&&($gtot>0)&&(($size<$maxsize)||
					     (($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
								 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))))) {
				$max=$gtot;
				$maxp=$p;
				$maxpat=$pat;
				$maxsize=$size;
				$found=1;
			}
		}
	}
	if ($found==1) {
		print "$max\t[$maxsize]\t[$maxpat] -> $maxp\n" if $msg;
		$nr=$maxpat;
		$$pp=$maxp;
		@$nrlp=($nr);
		return 1;
	} else {
		return 0;
	}
}


sub get_top_pats_v8($\%\%$\@) {
	#Find next pat to add as rule
	my ($g,$posp,$caughtp,$pp,$nrlp)=@_;
	my $max=0;
	my $maxsize=100;
	my $maxpat="";
	my $maxp="";
	my $found=0;
	@$nrlp=();
	my $nr="";
	foreach my $pat (keys %$posp) {
		my $patp=$posp->{$pat};
		foreach my $p (keys %$patp) {
			my $gtot = $patp->{$p};
			my $confp=$caughtp->{$pat};
			foreach my $pc (keys %{$confp}) {
				next if $pc eq $p;
				$gtot-= $confp->{$pc};
			}
			my $size=(length $pat)-2;

			if ($gtot<=2) {  
				if (($gtot>$max)||
			    	(($gtot==$max)&&($gtot>0)&&(($size<$maxsize)||
						     (($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
									 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))))) {
					$max=$gtot;
					$maxp=$p;
					$maxpat=$pat;
					$maxsize=$size;
					$found=1;
				}
			} else {
				if (($gtot>$max)||
				    (($gtot==$max)&&($gtot>0)&&(($size>$maxsize)||
						     (($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
									 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))))) {
					$max=$gtot;
					$maxp=$p;
					$maxpat=$pat;
					$maxsize=$size;
					$found=1;
				}
			}
		}
	}
	if ($found==1) {
		print "$max\t[$maxsize]\t[$maxpat] -> $maxp\n" if $msg;
		$nr=$maxpat;
		$$pp=$maxp;
		@$nrlp=($nr);
		return 1;
	} else {
		return 0;
	}
}


sub get_top_pats($\%\%$\@) {
	my ($g,$posp,$caughtp,$pp,$nrlp)=@_;
	get_top_pats_v1($g,%$posp,%$caughtp,$pp,@$nrlp);
}

#--------------------------------------------------------------------------

sub find_default(\%$) {
	my ($gpatp,$pat) = @_;
	my $max=0;
	my $maxp="";
	foreach my $p (keys %{$gpatp->{$pat}}) {
		my $cnt = $gpatp->{$pat}{$p}{'total'};
		if ($cnt>$max) {
			$max=$cnt;
			$maxp=$p;
		}
	}
	return $maxp
}

sub get_words_per_pat($\%) {
	my ($pat,$wp)=@_;
	my @wlist=();
	foreach my $w (keys %$wp) {
		if ($w =~ /$pat/) {
			push @wlist,$w;
		}
	}
	return @wlist;
}

sub get_words_per_pat_conflict($\%$) {
	my ($pat,$wp,$p)=@_;
	my @wlist=();
	foreach my $w (keys %$wp) {
		if ((!($wp->{$w} eq $p))&&($w =~ /$pat/)) {
			push @wlist,$w;
		}
	}
	return @wlist;
}

sub get_words_per_pat_match($\%$) {
	my ($pat,$wp,$p)=@_;
	my @wlist=();
	foreach my $w (keys %$wp) {
		if (($wp->{$w} eq $p)&&($w =~ /$pat/)) {
			push @wlist,$w;
		}
	}
	return @wlist;
}

sub rm_from_possiblelist(\%$$) {
	my ($patlp,$nr,$p)=@_;
	return if !(exists $patlp->{$nr}{$p});
	$patlp->{$nr}{$p}--;
	if ($patlp->{$nr}{$p}<=0) {
		delete $patlp->{$nr}{$p};
		my @plist = keys %{$patlp->{$nr}};
		if ((scalar @plist)<=0) {
			delete $patlp->{$nr};
		}
	}
}

sub rm_from_rulelist(\%$$) {
	#Delete rule after rule removed from caughtlist
	my ($words_notp,$nr,$g)=@_;
	my $p  = $rule{$nr};
	delete $rule{$nr};
	foreach my $ri (1..$#{$rorder{$g}}) {
		if ($rorder{$g}[$ri] eq $nr) {
			$rorder{$g}[$ri]=-1;
			last;
		}
	}
	#Add patterns previously conflicting with rule, but now possible
	#(Other patts automatically added in next step.) 
	my @words_possible_nr=get_words_per_pat_conflict($nr,%$words_notp,$p);
	foreach my $w (@words_possible_nr) {
		$pc = $words_notp->{$w};
		$posp->{$nr}{$pc}++;
	}
}


sub rm_from_caughtlist(\%\%$$$) {
	my ($caughtp,$words_notp,$nr,$p,$g)=@_;
	return if !(exists $caughtp->{$nr}{$p});
	$caughtp->{$nr}{$p}--;
	if ($caughtp->{$nr}{$p}<=0) {
		delete $caughtp->{$nr}{$p};
		if ((exists $rule{$nr})&&($rule{$nr} eq $p)) {
			print "About to delete rule $nr\n";
			rm_from_rulelist(%$words_notp,$nr,$g)
		}
		my @plist = keys %{$caughtp->{$nr}};
		if ((scalar @plist)<=0) {
			delete $caughtp->{$nr};
		}
	}
}


sub check_possible_swop($$$$\%) {
	my ($nr,$p,$g,$grulenum,$words_donep) = @_;
	foreach my $ri (1..$grulenum-1) {
		my $OK=0;
		my $posrule = $rorder{$g}[$ri];
		if (($nr =~ /$posrule/)&&($rule{$posrule} eq $p)) {
			print "Possible move:  [$posrule] after [$nr] \n";
			$OK=1;
			foreach my $rii ($ri+1..$grulenum-1) {
				my $conflictrule = $rorder{$g}[$rii];
				my @conflictwords = get_words_per_pat_conflict($conflictrule,%$words_donep,$p);
				foreach my $w (@conflictwords) {
					if ($w =~ /$posrule/) {
						$OK=0;
						last;
					}
				}
				last if ($OK==0);
			}
		}
		if ($OK==1) {
			print "Possible move confirmed! [$posrule] after [$nr] \n";
			return $ri;
		}
	}
	return -1;
}


sub rulegroups_from_pats_olist($$\%\%) {
	#Extract the best <$g>-specific rulegroups based on the set of patterns in <$gpatp>
	#Update globals %rule and %rorder	
	my ($g,$cmax,$possiblep,$words_notp) = @_;
	print "<p>-- Enter rulegroups_from_pats_olist [$g] [$cmax]\n" if $debug;
	my $cwin=2;
	$grulenum=1;
	my %words_done=();
	my %caught=();
	#dbmopen(%words_done,"db_words_done",0666) || die "Cannot open db db_words_done";

	#my $printnum=0;
	#open OH, ">:encoding(utf8)", "errors.tmp.$g" or die;
	
	my $from=1;
	my $to=$cmax;
	my $displaycnt;
	my $busy=get_top_pats($g,%$possiblep,%caught,\$p,@newrules);
	while ($busy==1) {
		foreach my $nr (@newrules){
			#if (($grulenum==0)&&(!($nr eq "-${g}-"))) {
			#	$grulenum++;
			#	my $p2 = find_default(%$gpatp,"-${g}-");
			#	print "Default rule for $g:\t[$grulenum]\t[-$g-] --> [$p2]\n" if $debug;
			#	$rule{"-$g-"}=$p2;
			#	$context{$g}{"-$g-"}=1;
			#	$rulecnt{"-$g-"}=$grulenum;
			#}
			
			print "$g:\t[$grulenum]\t[$nr] --> [$p]"; #if $msg;
			$rule{$nr}=$p;
			$rorder{$g}[$grulenum]=$nr;
			$grulenum++;
			
			my @replacewords=get_words_per_pat_conflict($nr,%words_done,$p);
			my @new_words=get_words_per_pat_match($nr,%$words_notp,$p);
			#my @overwords=get_words_per_pat_match($nr,%words_done,$p);
			$displaycnt = $#new_words-$#replacewords;
			print "\t$displaycnt\n"; #if $msg;
			$numfound{$nr}=$displaycnt;
		
			foreach my $w (@new_words) {
				#print "Rule used for words: [$w] -> [$p]\n" if $msg;
				#print "Words: [$w] -> [$p]\n";
				
				#my $consistent; 
				#if ($#new_words >= 4) {
				#	$consistent=1; 
				#} else {
				#	$consistent=0; 
				#}	
				#$printnum++;
				#print OH "$printnum;$w;$p;$consistent\n";

				$words_done{$w}=$p;
				delete $words_notp->{$w};	
				my @wordpatts = get_all_pats_limit($w,1,$to);
				foreach my $pat (@wordpatts) {
					$caught{$pat}{$p}++;
					rm_from_possiblelist(%$possiblep,$pat,$p);
				}
			}
			
			foreach my $w (@replacewords) {
				my $priorp=$words_done{$w};
				print "Redo word to prevent override: [$w] -> [$priorp]\n" if $msg;	
				delete $words_done{$w};
				$words_notp->{$w}=$priorp;
				my @wordpatts = get_all_pats_limit($w,1,$to);
				foreach my $pat (@wordpatts) {
					rm_from_caughtlist(%caught,%$words_notp,$pat,$priorp,$g);
					if (!(exists $rule{$pat})) {
						$possiblep->{$pat}{$priorp}++;
					}
				}
			}

			#foreach my $w (@overwords) {
			#	my $priorp=$words_done{$w};
			#	print "Previous word now caught by new rule: [$w] -> [$priorp]\n" if $msg;	
			#}
			
			if (exists $possiblep->{$nr}) {
				my $nrp=$possiblep->{$nr};
				my @plist = keys %{$nrp};
				foreach my $pc (@plist) {
					delete $nrp->{$pc};
				}
				delete $possiblep->{$nr};
			}
		}		
		$busy=get_top_pats($g,%$possiblep,%caught,\$p,@newrules);
		my $nr = $newrules[$#newrules];
		
		if ($busy==1){
			#my $swopnum=check_possible_swop($nr,$p,$g,$grulenum,%words_done);
			#if ($swopnum != -1) {
			#	my $prevrule=$rorder{$g}[$swopnum];
			#	$rorder{$g}[$swopnum]=-1;
			#	$nr=$prevrule;
			#	@newrules=($nr);
			#}
		
			my $newlen = (length $nr)-2;
			if ($newlen>($to-$cwin)) {
				if ($newlen < 18) {
					$from = $to+1;
					$to = $to+$cwin;
					print "Adding contexts from [$from] to [$to]\n";
					add_gpatts_limit($from,$to,%words_done,%$words_notp,%$possiblep,%caught);
				} else {
					$busy=0;
				}
			}
		}
		#Quick hack to test removal of tail - new version writes all rules and then manipulates rule set afterwards.
		#Use this one for quick tests (generating tail is slow).
		#if ($displaycnt<3) {
		#	$busy=0;
		#}
	}
	foreach my $w (keys %$words_notp) {
		print "Error: missed $w\n";
	}
	
	#Add 1-g backoff rule, if missed by other rules
	if (!(exists $rule{"-$g-"})) {
		$rule{"-$g-"}=$rule{$rorder{$g}[1]};
		$rorder{$g}[0]="-$g-";
		print "Adding backoff\t[-$g-] -> $rule{$rorder{$g}[1]}\n";
	}	else {
		$rorder{$g}[0]="-1";
	}
	#dbmclose(%words_done);
}


sub rulegroups_from_pats_olist_large($$\%\%$) {
	#Extract the best <$g>-specific rulegroups based on the set of patterns in <$gpatp>
	#Update globals %rule, %rorder and %numfound
	my $find_single=0;
	my $id_single=1;
	#$fromsize usually 1 unless testing with fixed context size, then 0
	my $fromsize=1;
	my $ngram=0;
	
	my ($g,$cmax,$possiblep,$words_notp,$rulefile) = @_;
	print "<p>-- Enter rulegroups_from_pats_olist_large [$g] [$cmax]\n" if $debug;
	
	if ($ngram==1) {
		#temporary file created to write probabilities - integrate better once tested
		open TH, ">:encoding(utf8)", "$rulefile.prob" or die "Error opening $rulefile.prob";
	}

	my $cwin=4;
	$grulenum=1;
	my %words_done=();
	my %caught=();

	#my $printnum=0;
	if ($find_single==1) {
		open EH, ">:encoding(utf8)", "$rulefile.single" or die;
	}

	my $from=1;
	my $to=$cmax;
	my $displaycnt;
	my $busy=get_top_pats($g,%$possiblep,%caught,\$p,@newrules);
	while ($busy==1) {
		foreach my $nr (@newrules){
			print "$g:\t[$grulenum]\t[$nr] --> [$p]"; #if $msg;
			$rule{$nr}=$p;
			$rorder{$g}[$grulenum]=$nr;
			
			my @replacewords=get_words_per_pat_conflict($nr,%words_done,$p);
			my @new_words=get_words_per_pat_match($nr,%$words_notp,$p);
			#my @overwords=get_words_per_pat_match($nr,%words_done,$p);

			#when calculating n-gram probabilities
			if ($ngram==1) {
				my $nummatch = scalar get_words_per_pat_match($nr,%words_done,$p);
				my $numconflict =scalar get_words_per_pat_conflict($nr,%$words_notp,$p);
				$numconflict += scalar @replacewords;
				$nummatch += scalar @new_words;
			}
			$displaycnt = $#new_words-$#replacewords;
			print "\t$displaycnt\n"; #if $msg;
			$numfound{$nr}=$displaycnt;
	
			$nr =~ /^(.*)-.-(.*)$/;
			#print OH "$g;$1;$2;$p;$grulenum;$displaycnt\n";
			$grulenum++;
			if ($ngram==1) {
				my $prob=0;
				if (($nummatch+$numconflict)!=0) {
					$prob = ($nummatch*100.0) / ($nummatch+$numconflict);
				}
				printf TH "%s;%s;%s;%s;%d;%.2f\n",$g,$1,$2,$p,$grulenum,$prob;
			}

			foreach my $w (@new_words) {
				#Used during error detection - to be replaced with proper error detection tool
				#print "Rule used for words: [$w] -> [$p]\n" if $msg;
				if ($find_single==1) {
					if ($displaycnt<=$id_single) {
						my $actcnt = @new_words;
						print EH "$displaycnt;$actcnt;$w;$nr\n";
					}
				}
				#my $consistent; 
				#if ($#new_words >= 4) {
				#	$consistent=1; 
				#} else {
				#	$consistent=0; 
				#}	
				#$printnum++;
				#print OH "$printnum;$w;$p;$consistent\n";

				$words_done{$w}=$p;
				delete $words_notp->{$w};	
				my @wordpatts = get_all_pats_limit($w,$fromsize,$to);
				foreach my $pat (@wordpatts) {
					$caught{$pat}{$p}++;
					rm_from_possiblelist(%$possiblep,$pat,$p);
				}
			}
			
			foreach my $w (@replacewords) {
				my $priorp=$words_done{$w};
				print "Redo word to prevent override: [$w] -> [$priorp]\n" if $msg;	
				delete $words_done{$w};
				$words_notp->{$w}=$priorp;
				my @wordpatts = get_all_pats_limit($w,$fromsize,$to);
				foreach my $pat (@wordpatts) {
					rm_from_caughtlist(%caught,%$words_notp,$pat,$priorp,$g);
					if (!(exists $rule{$pat})) {
						$possiblep->{$pat}{$priorp}++;
					}
				}
			}

			#foreach my $w (@overwords) {
			#	my $priorp=$words_done{$w};
			#	print "Previous word now caught by new rule: [$w] -> [$priorp]\n" if $msg;	
			#}
			
			if (exists $possiblep->{$nr}) {
				my $nrp=$possiblep->{$nr};
				my @plist = keys %{$nrp};
				foreach my $pc (@plist) {
					delete $nrp->{$pc};
				}
				delete $possiblep->{$nr};
			}
		}		
		$busy=get_top_pats($g,%$possiblep,%caught,\$p,@newrules);
		my $nr = $newrules[$#newrules];
		
		if ($busy==1){
			#my $swopnum=check_possible_swop($nr,$p,$g,$grulenum,%words_done);
			#if ($swopnum != -1) {
			#	my $prevrule=$rorder{$g}[$swopnum];
			#	$rorder{$g}[$swopnum]=-1;
			#	$nr=$prevrule;
			#	@newrules=($nr);
			#}
		
			my $newlen = (length $nr)-2;
			my $limit_size=0;
			#don't increase context size while testing effect of limiting context size
			if ($newlen>($to-$cwin)&&($limit_size==0)) {
				if ($newlen < 18) {
					$from = $to+1;
					$to = $to+$cwin;
					print "Adding contexts from [$from] to [$to]\n";
					add_gpatts_limit($from,$to,%words_done,%$words_notp,%$possiblep,%caught);
				} else {
					$busy=0;
				}
			}
		}
		#Quick hack to test removal of tail - new version writes all rules and then manipulates rule set afterwards.
		#Use this one for quick tests (generating tail is slow).
		#if ($displaycnt<3) {
		#	$busy=0;
		#}
	}
	foreach my $w (keys %$words_notp) {
		print "Error: missed $w\n";
	}
	
	#Add 1-g backoff rule, if missed by other rules
	if (!(exists $rule{"-$g-"})) {
		$rule{"-$g-"}=$rule{$rorder{$g}[1]};
		$rorder{$g}[0]="-$g-";
		print "Adding backoff\t[-$g-] -> $rule{$rorder{$g}[1]}\n";
	}	else {
		$rorder{$g}[0]="-1";
	}
	close EH;
	#close OH;
	if ($ngram==1) {	
		close TH;
	}
}

sub rulegroups_from_pats_olist_large_wspecific($$$\%\%$) {
	#Extract the best <$g>-specific rulegroups based on the set of patterns in <$gpatp>
	#Only extract those rules that match a given word 
	#Update globals %rule and %rorder	
	my $find_single=0;
	my $id_single=1;
	#$fromsize usually 1 unless testing with fixed context size, then 0
	my $fromsize=1;
	
	my ($word,$g,$cmax,$possiblep,$words_notp,$rulefile) = @_;
	print "<p>-- Enter rulegroups_from_pats_olist_large_wspecific [$g] [$cmax] [$rulefile]\n" if $debug;
	open OH, ">:encoding(utf8)", "$rulefile" or die "Error opening $rulefile";	
	
	my $cwin=2;
	$grulenum=0;
	my %words_done=();
	my %caught=();
	#dbmopen(%words_done,"db_words_done",0666) || die "Cannot open db db_words_done";

	#my $printnum=0;
	if ($find_single==1) {
		open EH, ">:encoding(utf8)", "$rulefile.single" or die;
	}

	my $from=1;
	my $to=$cmax;
	my $displaycnt;
	my $busy=get_top_pats($g,%$possiblep,%caught,\$p,@newrules);
	while ($busy==1) {
		foreach my $nr (@newrules){
			print "$g:\t[$grulenum]\t[$nr] --> [$p]"; #if $msg;
			$rule{$nr}=$p;
			$rorder{$g}[$grulenum]=$nr;
			
			my @replacewords=get_words_per_pat_conflict($nr,%words_done,$p);
			my @new_words=get_words_per_pat_match($nr,%$words_notp,$p);
			#my @overwords=get_words_per_pat_match($nr,%words_done,$p);
			$displaycnt = $#new_words-$#replacewords;
			print "\t$displaycnt\n"; #if $msg;
			$numfound{$nr}=$displaycnt;
	
			$nr =~ /^(.*)-.-(.*)$/;
			print OH "$g;$1;$2;$p;$grulenum;$displaycnt\n";
			$grulenum++;
			
			foreach my $w (@new_words) {
				#Used during error detection - to be replaced with proper error detection tool
				#print "Rule used for words: [$w] -> [$p]\n" if $msg;
				if ($find_single==1) {
					if ($displaycnt<=$id_single) {
						my $actcnt = @new_words;
						print EH "$displaycnt;$actcnt;$w;$nr\n";
					}
				}
				#my $consistent; 
				#if ($#new_words >= 4) {
				#	$consistent=1; 
				#} else {
				#	$consistent=0; 
				#}	
				#$printnum++;
				#print OH "$printnum;$w;$p;$consistent\n";

				$words_done{$w}=$p;
				delete $words_notp->{$w};	
				my @wordpatts = get_all_pats_limit_wspecific($word,$w,$fromsize,$to);
				foreach my $pat (@wordpatts) {
					$caught{$pat}{$p}++;
					rm_from_possiblelist(%$possiblep,$pat,$p);
				}
			}
			
			foreach my $w (@replacewords) {
				my $priorp=$words_done{$w};
				print "Redo word to prevent override: [$w] -> [$priorp]\n" if $msg;	
				delete $words_done{$w};
				$words_notp->{$w}=$priorp;
				my @wordpatts = get_all_pats_limit_wspecific($word,$w,$fromsize,$to);
				foreach my $pat (@wordpatts) {
					rm_from_caughtlist(%caught,%$words_notp,$pat,$priorp,$g);
					if (!(exists $rule{$pat})) {
						$possiblep->{$pat}{$priorp}++;
					}
				}
			}

			#foreach my $w (@overwords) {
			#	my $priorp=$words_done{$w};
			#	print "Previous word now caught by new rule: [$w] -> [$priorp]\n" if $msg;	
			#}
			
			if (exists $possiblep->{$nr}) {
				my $nrp=$possiblep->{$nr};
				my @plist = keys %{$nrp};
				foreach my $pc (@plist) {
					delete $nrp->{$pc};
				}
				delete $possiblep->{$nr};
			}
		}		
		$busy=get_top_pats($g,%$possiblep,%caught,\$p,@newrules);
		my $nr = $newrules[$#newrules];
		
		if ($busy==1){
			#my $swopnum=check_possible_swop($nr,$p,$g,$grulenum,%words_done);
			#if ($swopnum != -1) {
			#	my $prevrule=$rorder{$g}[$swopnum];
			#	$rorder{$g}[$swopnum]=-1;
			#	$nr=$prevrule;
			#	@newrules=($nr);
			#}
		
			my $newlen = (length $nr)-2;
			my $limit_size=1;
			#don't increase context size while testing effect of limiting context size
			if ($newlen>($to-$cwin)&&($limit_size==0)) {
				if ($newlen < 18) {
					$from = $to+1;
					$to = $to+$cwin;
					print "Adding contexts from [$from] to [$to]\n";
					add_gpatts_limit_wspecific($word,$from,$to,%words_done,%$words_notp,%$possiblep,%caught);
				} else {
					$busy=0;
				}
			}
		}
		#Quick hack to test removal of tail - new version writes all rules and then manipulates rule set afterwards.
		#Use this one for quick tests (generating tail is slow).
		#if ($displaycnt<3) {
		#	$busy=0;
		#}
	}
	#foreach my $w (keys %$words_notp) {
	#	print "Error: missed $w\n";
	#}
	
	#Add 1-g backoff rule, if missed by other rules
	if (!(exists $rule{"-$g-"})) {
		$rule{"-$g-"}=$rule{$rorder{$g}[1]};
		$rorder{$g}[0]="-$g-";
		print "Adding backoff\t[-$g-] -> $rule{$rorder{$g}[1]}\n";
	}	else {
		$rorder{$g}[0]="-1";
	}
	#dbmclose(%words_done);
	close EH;
	close OH;
}

#--------------------------------------------------------------------------

sub fgen_rulegroups_single($$) {
	my ($g,$pattsfile)=@_;
	%rule=();
	%rulecnt=();
	my %gpatts=();
	my %gwords=();
	my $found=0;
	#dbmopen(%gwords,"db_words_not",0666) || die "Cannot open db db_words_not";
	if (-e $pattsfile) {
		#fread_gpatts_full(%gpatts,%gwords,$pattsfile);
		my $tmpFH=select (STDOUT);
		$|=1;
		select($tmpFH);
		fread_gpatts_limit(1,8,%gpatts,%gwords,$pattsfile);
		my @cntwords = keys %gwords;
		if (scalar @cntwords > 0) {
			my $wnum=$#cntwords+1;
			print "Finding best rules for [$g] [$wnum]\n";
			rulegroups_from_pats_olist($g,8,%gpatts,%gwords);
			$found=1;
		}
	}
	if ($found==0) {
		$rule{"-$g-"} = "0";
		$rorder{$g}[0]="-$g-";
		$numfound{"-$g-"} = "0";
		print "$g:\t[0]\t[-$g-] --> 0\n" #if $debug;
	}
	#dbmclose(%gwords);
}

sub fgen_rulegroups_single_large($$$) {
	my ($g,$pattsfile,$rulefile)=@_;
	%rule=();
	%rulecnt=();
	%numfound=();
	
	my %gpatts=();
	my %gwords=();
	my $found=0;
	#dbmopen(%gwords,"db_words_not",0666) || die "Cannot open db db_words_not";
	if (-e $pattsfile) {
		#fread_gpatts_full(%gpatts,%gwords,$pattsfile);
		my $tmpFH=select (STDOUT);
		$|=1;
		select($tmpFH);
		my $fromsize=1;
		my $tosize=8;
		#normal $fromsize=1; $tosize=8 
		#tosize can be larger if sufficient memory available
		#set fromsize=0 only while testing effect of context size
		fread_gpatts_limit($fromsize,$tosize,%gpatts,%gwords,$pattsfile);
		my @cntwords = keys %gwords;
		if (scalar @cntwords > 0) {
			my $wnum=$#cntwords+1;
			print "Finding best rules for [$g] [$wnum]\n";
			rulegroups_from_pats_olist_large($g,$tosize,%gpatts,%gwords,$rulefile);
			$found=1;
		}
	}
	if ($found==0) {
		$rule{"-$g-"} = "0";
		$rorder{$g}[0]="-$g-";
		$numfound{"-$g-"}=0;
		print "$g:\t[0]\t[-$g-] --> 0\n"; #if $debug;
		#open OH, ">:encoding(utf8)", "$rulefile" or die "Error opening $rulefile\n";
		#print OH "$g;;;0;0;0\n";
		#close OH;
	}
	#dbmclose(%gwords);
}

sub fgen_rulegroups_single_large_wspecific($$$$) {
	my ($word,$g,$pattsfile,$rulefile)=@_;
	%rule=();
	%rulecnt=();
	my %gpatts=();
	my %gwords=();
	my $found=0;
	#dbmopen(%gwords,"db_words_not",0666) || die "Cannot open db db_words_not";
	if (-e $pattsfile) {
		#fread_gpatts_full(%gpatts,%gwords,$pattsfile);
		my $tmpFH=select (STDOUT);
		$|=1;
		select($tmpFH);
		my $fromsize=1;
		my $tosize=40;
		#normal $fromsize=1; $tosize=8 
		#tosize can be larger if sufficient memory available
		#set fromsize=0 only while testing effect of context size
		fread_gpatts_limit_wspecific($word,$fromsize,$tosize,%gpatts,%gwords,$pattsfile);
		my @cntwords = keys %gwords;
		if (scalar @cntwords > 0) {
			my $wnum=$#cntwords+1;
			print "Finding best rules for [$g] [$wnum]\n";
			rulegroups_from_pats_olist_large_wspecific($word,$g,$tosize,%gpatts,%gwords,$rulefile);
			$found=1;
		}
	}
	if ($found==0) {
		$rule{"-$g-"} = "0";
		$rorder{$g}[0]="-$g-";
		print "$g:\t[0]\t[-$g-] --> 0\n"; #if $debug;
		open OH, ">:encoding(utf8)", "$rulefile" or die "Error opening $rulefile\n";
		print OH "$g;;;0;0;0\n";
		close OH;
	}
	#dbmclose(%gwords);
}

#--------------------------------------------------------------------------

sub can_link($$) {
	my ($pat1,$pat2) = @_;
	$pat1 =~ s/[\[\]]//g;
	$pat2 =~ s/[\]\[]//g;
	if ($pat1 !~ /^(.*)-.-(.*)$/) {
		die "Error in format: [$pat1]\n";
	} 
	my $v1l = $1;
	my $v1r = $2;
	if ($pat2 !~ /^(.*)-.-(.*)$/) {
		die "Error in format: [$pat2]\n";
	} 
	my $v2l = $1;
	my $v2r = $2;
	if ( (($v1l =~ /.*$v2l$/)||($v2l =~ /.*$v1l$/))
	      &&(($v1r =~ /^$v2r.*/)||($v2r =~ /^$v1r.*/))) {
		return 1;
	}
	return 0;
}	

sub is_superrule($$) {
	my ($pat1,$pat2)=@_;
	#$pat1 =~ s/[\[\]]//g;
	#$pat2 =~ s/[\]\[]//g;
	if ($pat2 =~ /$pat1/) {
		return 1;
	}
	return 0;
}

#--------------------------------------------------------------------------
# incremental olist
#--------------------------------------------------------------------------

sub rulegroups_from_pats_olist_inc($$\%\%\%\%) {
	#Similiar to rulegroups_from_pats_olist: combine once checked
	my ($g,$cmax,$caughtp,$words_donep,$possiblep,$words_notp) = @_;
	print "<p>-- Enter rulegroups_from_pats_olist_inc: [$g] [$cmax]\n" if $debug;
	my $cwin=3;
	my $from=1;
	my $to=$cmax;
	$grulenum++;
	my $busy=get_top_pats($g,%$possiblep,%$caughtp,\$p,@newrules);
	while ($busy==1) {
		foreach my $nr (@newrules){
			print "Next rule for $g:\t[$grulenum]\t[$nr] --> [$p]\n" if $msg;
			$rule{$nr}=$p;
			$rorder{$g}[$grulenum]=$nr;
			$grulenum++;
			
			my @replacewords=get_words_per_pat_conflict($nr,%$words_donep,$p);
			my @new_words=get_words_per_pat_match($nr,%$words_notp,$p);
			#my @overwords=get_words_per_pat_match($nr,%$words_donep,$p);
			
			foreach my $w (@new_words) {
				print "Rule used for words: [$w] -> [$p]\n" if $msg;	
				$words_donep->{$w}=$p;
				delete $words_notp->{$w};	
				my @wordpatts = get_all_pats_limit($w,1,$to);
				foreach my $pat (@wordpatts) {
					$caughtp->{$pat}{$p}++;
					rm_from_possiblelist(%$possiblep,$pat,$p);
				}
			}
			
			foreach my $w (@replacewords) {
				my $priorp=$words_donep->{$w};
				print "Redo word to prevent override: [$w] -> [$priorp]\n" if $msg;	
				delete $words_donep->{$w};
				$words_notp->{$w}=$priorp;
				my @wordpatts = get_all_pats_limit($w,1,$to);
				foreach my $pat (@wordpatts) {
					rm_from_caughtlist(%$caughtp,%$words_notp,$pat,$priorp,$g);
					if (!(exists $rule{$pat})) {
						$possiblep->{$pat}{$priorp}++;
					}
				}
			}

			if (exists $possiblep->{$nr}) {
				my $nrp=$possiblep->{$nr};
				my @plist = keys %{$nrp};
				foreach my $pc (@plist) {
					delete $nrp->{$pc};
				}
				delete $possiblep->{$nr};
			}
		}		
		$busy=get_top_pats($g,%$possiblep,%$caughtp,\$p,@newrules);
		my $nr = $newrules[$#newrules];
		
		if ($busy==1){
			my $newlen = (length $nr)-2;
			if ($newlen>($to-$cwin)) {
				$from = $to+1;
				$to = $to+$cwin;
				print "Adding contexts from [$from] to [$to]\n";
				add_gpatts_limit($from,$to,%$words_donep,%$words_notp,%$possiblep,%caught);
			}
		}
	}
	foreach my $w (keys %$words_notp) {
		print "Error: missed $w\n";
	}
	
	#Add 1-g backoff rule, if missed by other rules
	if (!(exists $rule{"-$g-"})) {
		$rule{"-$g-"}=$rule{$rorder{$g}[1]};
		$rorder{$g}[0]="-$g-";
		print "Adding backoff\t[-$g-] -> $rule{$rorder{$g}[1]}\n";
	} elsif ($rulecnt{"-$g-"} != 0) {
		$rorder{$g}[0]="-1";
	}
}


sub first_out($$) {
	my ($g,$wpat) = @_;
	#print "Entering first_out: [$g],[$wpat]\n" if $debug;
	for (my $rnum=$grulenum;$rnum>=0;$rnum--) {
		my $r = $rorder{$g}[$rnum];
		if (is_superrule($r,$wpat)==1) {
			$vout = $rule{$r};
			return $vout;
		}
	}
	die "No match found\n";
}


sub fappend_gpatts(\%$) {
	my ($patp,$fname) = @_;
	open IH, ">>:encoding(utf8)", "$fname" or die "Error reading IH";
	foreach my $pat (keys %$patp) {
		$out = $patp->{$pat};
		print IH "$out; $pat\n";
	}
}


sub olist_add_word ($$$$) {
	my ($word,$prev_rules_prefix,$patts_prefix,$new_rules_prefix) = @_;

	my @pron = split /;/,$word;
	if (scalar @pron !=3) {
		die "Error in word format: [$word]\n";
	}
	my @graphs = split //,$pron[0];
	my @phons = split //,$pron[1];
	if ($#graphs != $#phons) {
		die "Error in word alignment: [$word]\n";
	}
	
	my %todo = extract_patterns_olist_1word($pron[0],$pron[1]);
	my $cmax=1000;
	my %caught=();
	my %done=();

	foreach my $g (keys %todo) {
		fread_rules_olist("$prev_rules_prefix.$g");
		fread_gpatts_limit(1,$cmax,%caught,%done,"$patts_prefix.$g");
		foreach my $wpat (keys %{$todo{$g}}) {
			my $wout = $todo{$g}{$wpat};
			my @subpats = get_all_pats_limit($wpat,1,$cmax);
			if (exists $done{$wpat}) {
				$prev_out=$done{$wpat};
				if ($prev_out eq $wout) {
					print "Warning: word [$wpat] already added; ignored\n" if $debug;
				} else {
					print "Warning: word [$wpat] already added; prev version removed\n" if $debug;
					delete $done{$wpat};
					$notdone{$wpat}=$wout;
					foreach my $sub (@subpats) {
						$caught{$sub}{$prev_out}--;
						if (!(exists $rule{$sub})) {
							$possible{$sub}{$wout}++;
						}
					}
				}
			} else {
				my $predict_out = first_out($g,$wpat);
				if ($predict_out eq $wout) {
					print "Current rule set OK: $wpat -> $wout\n" if $debug;
					foreach my $sub (@subpats) {
						$caught{$sub}{$wout}++;
					}
				} else {
					print "Updating rule set: $wpat -> $wout\n" if $debug;					
					$notdone{$wpat}=$wout;
					foreach my $sub (@subpats) {
						if (!(exists $rule{$sub})) {
							$possible{$sub}{$wout}++;
						}
					}
				}
			}
		}
		rulegroups_from_pats_olist_inc($g,$cmax,%caught,%done,%possible,%notdone);
		fappend_gpatts(%{$todo{$g}},"$patts_prefix.$g");
		fwrite_rules_olist("$new_rules_prefix.$g");
	}
}


#Same as olist_add_word, but doesn't write to file, and shows if changed. Combine once checked. 
sub olist_add_word2 ($$$) {
	my ($word,$rules_prefix,$patts_prefix) = @_;
	print "Entering olist_add_word2: $word, $rules_prefix, $patts_prefix\n" if $debug;
	
	my @pron = split /;/,$word;
	if (scalar @pron !=3) {
		die "Error in word format: [$word]\n";
	}
	my @graphs = split //,$pron[0];
	my @phons = split //,$pron[1];
	if ($#graphs != $#phons) {
		die "Error in word alignment: [$word]\n";
	}
	
	my %todo = extract_patterns_olist_1word($pron[0],$pron[1]);
	my $cmax=1000;
	my %caught=();
	my %done=();
	my $changed=0;

	foreach my $g (keys %todo) {
		fread_rules_olist("$rules_prefix.$g");
		fread_gpatts_limit(1,$cmax,%caught,%done,"$patts_prefix.$g");
		foreach my $wpat (keys %{$todo{$g}}) {
			my $wout = $todo{$g}{$wpat};
			my @subpats = get_all_pats_limit($wpat,1,$cmax);
			if (exists $done{$wpat}) {
				$prev_out=$done{$wpat};
				if ($prev_out eq $wout) {
					print "Warning: word [$wpat] already added; ignored\n" if $debug;
				} else {
					print "Warning: word [$wpat] already added; prev version removed\n" if $debug;
					delete $done{$wpat};
					$notdone{$wpat}=$wout;
					foreach my $sub (@subpats) {
						$caught{$sub}{$prev_out}--;
						if (!(exists $rule{$sub})) {
							$possible{$sub}{$wout}++;
						}
					}
					$changed=1;
				}
			} else {
				my $predict_out = first_out($g,$wpat);
				if ($predict_out eq $wout) {
					print "Current rule set OK: $wpat -> $wout\n" if $debug;
					foreach my $sub (@subpats) {
						$caught{$sub}{$wout}++;
					}
				} else {
					print "Updating rule set: $wpat -> $wout\n" if $debug;
					$notdone{$wpat}=$wout;
					foreach my $sub (@subpats) {
						if (!(exists $rule{$sub})) {
							$possible{$sub}{$wout}++;
						}
					}
					$changed=1;
				}
			}
		}
		rulegroups_from_pats_olist_inc($g,$cmax,%caught,%done,%possible,%notdone);
		fappend_gpatts(%{$todo{$g}},"$patts_prefix.$g");
		fwrite_rules_olist("$rules_prefix.$g");
	}
	return $changed;
}


sub olist_add_upto_sync($$$$$$$$$$$) {
	my ($prev_dict,$prev_rules_prefix,$prev_patts_prefix,$sync,$use_align,$new_dict,$new_rules_prefix,$new_patts_prefix,$used_dict,$adict,$gnulls) = @_;
	print "Entering olist_add_upto_sync:\nPrev dict: $prev_dict\nPrev rules: $prev_rules_prefix\nPrev patts: $prev_patts_prefix\n";
	print "Sync: $sync\nUse alignments: $use_align\nNew dict: $new_dict\nNew rules: $new_rules_prefix\nNew patts: $new_patts_prefix\n";
	print "Used dict: $used_dict\nAligned dict: $adict\nGnulls: $gnulls\n";
	
	read_graphs(@graphs);
	push @graphs,0;
	
	foreach my $g (@graphs) {
		`cp -v "$prev_rules_prefix.$g" "$new_rules_prefix.$g"`;
		`cp -v "$prev_patts_prefix.$g" "$new_patts_prefix.$g"`;
	}
	
	my $inc=0;
	if ($use_align==0) {
		fprobs_from_aligned($adict);
	}
	open DIH, "<:encoding(utf8)", "$prev_dict" or die "Error opening $prev_dict\n";
	open DOH, ">:encoding(utf8)", "$new_dict" or die "Error opening $new_dict\n";
	open UOH, ">:encoding(utf8)", "$used_dict" or die "Error opening $used_dict\n";
	
	while ($inc < $sync) {
		my $line = <DIH>;
		chomp($line);
		my @parts = split /;/,$line;
		if (scalar @parts != 3) {
			die "Error in line format [$line]\n";
		}
		my $word = $parts[1];
		my $sound = $parts[2];
		$word =~ s/ //g;
		$sound =~ s/ //g;
		if ($use_align==0) {
			$aligntype=4;
			$word =~ s/0//g;
			$sound =~ s/0//g;
			my @gseq = split //,$word;
			my @pseq = split //,$sound;
			align_word(@gseq,@pseq);
			$word = join "",@gseq;
			$sound = join "",@pseq;
		}
		my $changed = olist_add_word2 ("$word;$sound;1",$new_rules_prefix,$new_patts_prefix);
		if ($changed==1) {
			$inc++;
		}
		print UOH "$word;$sound;1\n";
	}
	close UOH;

	my $todo=0;
	while (<DIH>) {
		chomp;
		print DOH "$_\n";
		$todo++;
	}
	close DIH;
	close DOH;
	return $todo;
}

#--------------------------------------------------------------------------
# fast olist - in practise will keep tree in mem (tree read, write, draw to test only)
#--------------------------------------------------------------------------
# Draw functions

sub create_tree_dotfile($$$) {
	my ($gtreep,$gname,$fname)=@_;
	open FH, ">:encoding(utf8)", "$fname" or die "Error writing to $fname\n";
	print FH "digraph G\n {\nlabel=\"$gname\"\n";
	
	my @all_vertices =$$gtreep->vertices();
	print "Tree for $fname: $gname\n";
	while ((scalar @all_vertices)>0) {
		my $v1 = shift @all_vertices;
		my $vout = $$gtreep->get_attribute("outcome",$v1);
		my $vnum = $$gtreep->get_attribute("rulenum",$v1);
		my $vname = "$v1:$vout:$vnum";
		print FH "\t\"$v1\" [label=\"$vname\",color=green,style=filled,fillcolor=green];\n";
	}
	my @all_edges = $$gtreep->edges();
	while ((scalar @all_edges)>0) {
		my $v1 = shift @all_edges;
		my $v2 = shift @all_edges;
		print FH "\t\"$v1\" -> \"$v2\" [color=black];\n";
	}
	print FH "}\n";
	close FH;
}

sub draw_tree($$$){
	my ($gtreep,$gname,$fname)=@_;
	my $textfile = "$fname.dat";
	my $imagefile = "$fname.jpg";
	create_tree_dotfile($gtreep,$gname,$textfile);
	system "dot -Tjpeg $textfile -o $imagefile";
}

#--------------------------------------------------------------------------

sub fwrite_olist_gtree($$) {
	my ($gtreep,$gtreefn) = @_;
	print "Entering fwrite_olist_gtree: $gtreefn\n";
	my @vlist = $$gtreep->source_vertices();
	if (scalar @vlist == 0) {
		@vlist = $$gtreep->vertices();
	}
	my %vdone=();
	open OH, ">:encoding(utf8)", "$gtreefn" || die "Error opening $gtreefn\n";
	while (scalar @vlist>=1) {
		$v = shift @vlist;
		$vout = $$gtreep->get_attribute("outcome",$v);
		$vnum = $$gtreep->get_attribute("rulenum",$v);
		print OH "$v:$vout:$vnum";
		my @vkids = $$gtreep->successors($v);
		foreach my $k (@vkids) {
			print OH ";$k"
		}
		print OH "\n";
		push @vlist,@vkids;
		$vdone{$v}=1;
	}
	close OH;
}


sub fread_olist_gtree($$) {
	my ($gtreefn,$gtreep) = @_;
	print "Entering fread_olist_gtree: $gtreefn\n";
	my %vdone=();
	
	open IH, "<:encoding(utf8)","$gtreefn" || die "Error opening $gtreefn\n";
	while (<IH>) {
		chomp;
		my @line = split /;/,$_;
		my $firstpat = shift @line;
		my ($cont,$out,$num) = split /:/,$firstpat;
		if ($$gtreep->has_vertex($cont)==0) {
			$$gtreep->add_vertex($cont);
		}
		$$gtreep->set_attribute("outcome",$cont,$out);
		$$gtreep->set_attribute("rulenum",$cont,$num);
		foreach my $k (@line) {
			if ($$gtreep->has_edge($cont,$k)==0) {
				$$gtreep->add_edge($cont,$k);
			}
		}
	}
	close IH;
}

sub olist_tree_from_rules ($$) {
	my ($rules_prefix,$tree_prefix) = @_;
	print "Entering olist_tree_from_rules: $rules_prefix,$tree_prefix\n";
	my @graphs;
	read_graphs(@graphs);
	push @graphs,"0";
	foreach my $g (@graphs) {
		my $gtree = Graph->new();
		$gtree->directed(1);
		%rule=();
		%rorder=();
		%rulecnt=();
		fread_rules_olist("$rules_prefix.$g");
		my @rlist = @{$rorder{$g}};
		my $root = shift @rlist;
		$gtree->add_vertex($root);
		$gtree->set_attribute("outcome",$root,$rule{$root});
		$gtree->set_attribute("rulenum",$root,$rulecnt{$root});
		foreach my $r (@rlist) {
			my @vlist = ($root);
			my %vdone=();
			while (scalar @vlist>0) {
				my $v = shift @vlist;
				next if $vdone{$v};
				my @kids = $gtree->successors($v);
				$add_here=1;
				foreach my $k (@kids) {
					if (is_superrule($k,$r)==1) {
						$add_here=0;
						push @vlist, $k;
					}
				} 
				if ($add_here==1) {
					if ($gtree->has_edge($v,$r)==0) {
						print "Adding [$v] -> [$r]\n" if $msg;
						$gtree->add_edge($v,$r);
						$gtree->set_attribute("outcome",$r,$rule{$r});
						$gtree->set_attribute("rulenum",$r,$rulecnt{$r});
					}
				}
				$vdone{$v}=1;
			}
		}
		#draw_tree(\$gtree,"testtree_$g","testtree_$g");
		fwrite_olist_gtree(\$gtree,"$tree_prefix.$g");
	}
}


sub tree_predict($$) {
	my ($gtreep,$w)=@_;
	my @vlist = $$gtreep->source_vertices;
	if (scalar @vlist == 0) {
		@vlist = $$gtreep->vertices();
	}
	my %vdone=();
	my %pos_winner=();
	while (scalar @vlist>0) {
		my $v = shift @vlist;
		my @kids = $$gtreep->successors($v);
		my $keep_thisv=1;
		foreach my $k (@kids) {
			if (can_link($k,$w)==1) {
				push @vlist,$k;
				$keep_thisv=0;
			}
		}
		if ($keep_thisv==1) {
			$pos_winner{$v}=1;
		}
	}
	my $win_rule="";
	if (scalar keys %pos_winner > 1) {
		my $win_num=-1;
		foreach my $pos_rule (keys %pos_winner) {
			my $pos_num = $$gtreep->get_attribute("rulenum",$pos_rule);
			if ($pos_num>$win_num) {
				$win_rule=$pos_rule;
				$win_num=$pos_num;
			}
		}
	} else {
		my @pwlist = keys %pos_winner;
		$win_rule = shift @pwlist;
	}
	return $$gtreep->get_attribute("outcome",$win_rule);
}

sub olist_fast_word ($$) {
	my ($word,$tree_prefix) = @_;
	my $patstr = " ".$word." ";
	my @gstr = split //,$patstr;
	for my $i (1..$#gstr-1) {
		my $g = $gstr[$i];
		my $l = substr ($patstr,0,$i);
		my $r = substr ($patstr,$i+1);
		my $w = $l."-".$g."-".$r;
		$todo{$g}{$w}=$i;
	}
	my @sound=split //,$word;
	foreach my $g (keys %todo) {
		my $gtree = new Graph;
		$gtree->directed(1);
		fread_olist_gtree("$tree_prefix.$g",\$gtree);
		foreach my $wpat (keys %{$todo{$g}}) {
			my $out = tree_predict(\$gtree,$wpat);
			my $index = $todo{$g}{$wpat}-1;
			$sound[$index]=$out;
		}
	}
	my $toreturn = join "",@sound;
	return $toreturn;
}


sub olist_fast_file ($$$$) {
	my ($wordlist,$tree_prefix,$gnullsfn,$newdict) = @_;
	my @graphs;
	read_graphs(@graphs);
	push @graphs,"0";
	my %gtreeset=();
	foreach my $g (@graphs) {
		$gtreeset{$g} = new Graph;
		$gtreeset{$g}->directed(1);
		fread_olist_gtree("$tree_prefix.$g",\$gtreeset{$g});
	}
	
	my %gnulls=();
	fread_gnull_list($gnullsfn,%gnulls);
	
	open IH, "<:encoding(utf8)","$wordlist" or die "Error opening file: $wordlist\n";
	open OH, ">:encoding(utf8)","$newdict" or die "Error opening file: $newdict\n";
	
	while (<IH>) {
		chomp;
		my $newword=add_gnull_word($_,%gnulls);
		my $patstr = " ".$newword." ";
		my @gstr = split //,$patstr;
		my @sound = split //,$newword;
		for my $i (1..$#gstr-1) {
			my $g = $gstr[$i];
			my $l = substr ($patstr,0,$i);
			my $r = substr ($patstr,$i+1);
			my $w = $l."-".$g."-".$r;
			my $out = tree_predict(\$gtreeset{$g},$w);
			$sound[$i-1]=$out;
		}
		my $snd = join "",@sound;
		$snd =~ s/0//g;
		print OH "$_;$snd;0\n";
	}
	close IH;
	close OH;
}

#--------------------------------------------------------------------------
#Previous version of get_top_pats <- remove later
#--------------------------------------------------------------------------

sub get_top_pats_v2($\%\%$\@) {
	#Find next pat to add as rule
	my ($g,$posp,$caughtp,$pp,$nrlp)=@_;
	my $gratio=1;

	my $max=0;
	my %patlist=();
	foreach my $pat (keys %$posp) {
		my $patp=$posp->{$pat};
		my $confp=$caughtp->{$pat};
		foreach my $p (keys %$patp) {
			my $gtot = $patp->{$p};
			foreach my $pc (keys %{$confp}) {
				next if $pc eq $p;
				$gtot-= $confp->{$pc};
			}
			if (($gtot*$gratio)>=$max) {
				$patlist{$gtot}{$pat}=$p;
				if ($gtot>$max) {
					$max=$gtot;
				}
			}
		}
	}
	
	my %candlist=();
	my @alltots = sort {$a <=> $b} keys %patlist;
	my $i=$#alltots;
	while ($i>=0) {
		my $gtot=$alltots[$i];
		last if ($gtot*$gratio) < $max;
		foreach my $pat (keys %{$patlist{$gtot}}) {
			my $p=$patlist{$gtot}{$pat};
			$candlist{$pat}{$p}=$gtot;
			print "";
		}
		$i--;
	}
	my @clist = keys %candlist;
	if ((scalar @clist) > 1) {
		print "Competitors!\n";	
		foreach my $pat (@clist) {
			foreach my $p (keys %{$candlist{$pat}}) {
				print "$pat : $p [$candlist{$pat}{$p}]\n";
			}
		}
	}
	
	$max=-500000;
	my $maxsize=100;
	my $maxpat="";
	my $maxp="";
	my $found=0;
	@$nrlp=();
	my $nr="";
	
	foreach my $pat (keys %candlist) {
		my $patp=$candlist{$pat};
		foreach my $p (keys %{$patp}) {
			my $gtot=$patp->{$p};
			foreach my $pc (keys %{$patp}) {
				next if $pc eq $p;
				$gtot -= $patp->{$pc};
			}
			my $size=(length $pat)-2;
			if (($gtot>$max)||
			    (($gtot==$max)&&($gtot!=-500000)&&(($size<$maxsize)||
					     (($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
								 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))))) {
				$max=$gtot;
				$maxp=$p;
				$maxpat=$pat;
				$maxsize=$size;
				$found=1;
			}
		}
	}	
	
	if ($found==1) {
		print "$max\t[$maxsize]\t[$maxpat] -> $maxp\n" if $msg;
		$nr=$maxpat;
		$$pp=$maxp;
		@$nrlp=($nr);
		return 1;
	} else {
		return 0;
	}
}


sub get_top_pats_v3($\%\%$\@) {
	#Find next pat to add as rule
	my ($g,$posp,$caughtp,$pp,$nrlp)=@_;
	my $gratio=1;

	my $max=0;
	my %patlist=();
	foreach my $pat (keys %$posp) {
		my $patp=$posp->{$pat};
		my $confp=$caughtp->{$pat};
		foreach my $p (keys %$patp) {
			my $gtot = $patp->{$p};
			foreach my $pc (keys %{$confp}) {
				next if $pc eq $p;
				$gtot-= $confp->{$pc};
			}
			if (($gtot*$gratio)>=$max) {
				$patlist{$gtot}{$pat}=$p;
				if ($gtot>$max) {
					$max=$gtot;
				}
			}
		}
	}
	
	my %candlist=();
	my @alltots = sort {$a <=> $b} keys %patlist;
	my $i=$#alltots;
	while ($i>=0) {
		my $gtot=$alltots[$i];
		last if ($gtot*$gratio) < $max;
		foreach my $pat (keys %{$patlist{$gtot}}) {
			my $p=$patlist{$gtot}{$pat};
			$candlist{$pat}{$p}=$gtot;
			print "";
		}
		$i--;
	}
	my @clist = keys %candlist;
	if ((scalar @clist) > 1) {
		print "Competitors!\n";	
		foreach my $pat (@clist) {
			foreach my $p (keys %{$candlist{$pat}}) {
				print "$pat : $p [$candlist{$pat}{$p}]\n" if $debug;
			}
		}
	}
	
	$max=-500000;
	my $maxsize=100;
	my $maxpat="";
	my $maxp="";
	my $found=0;
	@$nrlp=();
	my $nr="";
	
	foreach my $pat (keys %candlist) {
		my $patp=$candlist{$pat};
		foreach my $p (keys %{$patp}) {
			my $gtot=$patp->{$p};
			foreach my $pc (keys %{$posp->{$pat}}) {
				next if $pc eq $p;
				$gtot -= $posp->{$pat}{$pc};
			}
			my $size=(length $pat)-2;
			if (($gtot>$max)||
			    (($gtot==$max)&&($gtot!=-500000)&&(($size<$maxsize)||
					     (($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
								 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))))) {
				$max=$gtot;
				$maxp=$p;
				$maxpat=$pat;
				$maxsize=$size;
				$found=1;
			}
		}
	}	
	
	if ($found==1) {
		print "$max\t[$maxsize]\t[$maxpat] -> $maxp\n" if $msg;
		$nr=$maxpat;
		$$pp=$maxp;
		@$nrlp=($nr);
		return 1;
	} else {
		return 0;
	}
}


sub get_top_pats_v4($\%\%$\@) {
	#Find next pat to add as rule
	my ($g,$posp,$caughtp,$pp,$nrlp)=@_;
	my $max=0;
	my $maxsize=0;
	my $maxpat="";
	my $maxp="";
	my $found=0;
	@$nrlp=();
	my $nr="";
	foreach my $pat (keys %$posp) {
		my $patp=$posp->{$pat};
		foreach my $p (keys %$patp) {
			my $gtot = $patp->{$p};
			#foreach my $pc (keys %{$patp}) {
			#	next if $pc eq $p;
			#	$gtot-=$patp->{$pc};
			#}
			my $confp=$caughtp->{$pat};
			foreach my $pc (keys %{$confp}) {
				next if $pc eq $p;
				$gtot-= $confp->{$pc};
			}
			my $size=(length $pat)-2;
			if (($gtot>$max)||
			    (($gtot==$max)&&($gtot>0)&&(($size>$maxsize)||
					     (($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
								 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))))) {
				$max=$gtot;
				$maxp=$p;
				$maxpat=$pat;
				$maxsize=$size;
				$found=1;
			}
		}
	}
	if ($found==1) {
		print "$max\t[$maxsize]\t[$maxpat] -> $maxp\n" if $msg;
		$nr=$maxpat;
		$$pp=$maxp;
		@$nrlp=($nr);
		return 1;
	} else {
		return 0;
	}
}


sub get_top_pats_v5($\%\%$\@) {
	#Find next pat to add as rule
	my ($g,$posp,$caughtp,$pp,$nrlp)=@_;
	my $max=-500000;
	my $maxsize=100;
	my $maxpat="";
	my $maxp="";
	my $found=0;
	@$nrlp=();
	my $nr="";
	foreach my $pat (keys %$posp) {
		my $patp=$posp->{$pat};
		foreach my $p (keys %$patp) {
			my $gtot = $patp->{$p};
			foreach my $pc (keys %{$patp}) {
				next if $pc eq $p;
				$gtot-=$patp->{$pc};
			}
			my $confp=$caughtp->{$pat};
			foreach my $pc (keys %{$confp}) {
				next if $pc eq $p;
				$gtot-= $confp->{$pc};
			}
			my $size=(length $pat)-2;
			if (($gtot>$max)||
			    (($gtot==$max)&&($gtot!=0)&&(($size<$maxsize)||
					     (($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
								 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))))) {
				$max=$gtot;
				$maxp=$p;
				$maxpat=$pat;
				$maxsize=$size;
				$found=1;
			}
		}
	}
	if ($found==1) {
		print "$max\t[$maxsize]\t[$maxpat] -> $maxp\n" if $msg;
		$nr=$maxpat;
		$$pp=$maxp;
		@$nrlp=($nr);
		return 1;
	} else {
		return 0;
	}
}



sub get_top_pats_v6($\%\%$\@) {
	#Inefficient implementation - to test concept only. Redo later.
	#Find next pat to add as rule
	my ($g,$posp,$caughtp,$pp,$nrlp)=@_;
	my $max=0;
	my $maxsize=100;
	my $maxpat="";
	my $maxp="";
	my $found=0;
	@$nrlp=();
	my $nr="";
	foreach my $pat (keys %$posp) {
		my $patp=$posp->{$pat};
		foreach my $p (keys %$patp) {
			my $gtot = find_variability($pat,$p,%$posp,%$caughtp);
			my $size=(length $pat)-2;
			if (($gtot>$max)||
			    (($gtot==$max)&&($gtot>0)&&(($size<$maxsize)||
					     (($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
								 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))))) {
				$max=$gtot;
				$maxp=$p;
				$maxpat=$pat;
				$maxsize=$size;
				$found=1;
			}
		}
	}
	if ($found==1) {
		print "$max\t[$maxsize]\t[$maxpat] -> $maxp\n" if $msg;
		$nr=$maxpat;
		$$pp=$maxp;
		@$nrlp=($nr);
		return 1;
	} else {
		return 0;
	}
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

