package g2pDec;

use g2pFiles;
use g2pAlign;
use g2pDict;
use Time::Local;
use AnyDBM_File;
use g2pRulesHelper;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$maxContext = 20; #if changed, change create_order variations as well
	
	$debug = 0;
	$msg = 0;
	
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&fread_rules &fwrite_rules &fgen_rules &extract_words &update_rules &test_rules &opt_rules &update_rules &cntrules_adict &fcount_rules &fcount_contexts &fwlist_frommaster_predict &fwrite_contexts &fread_contexts &fextract_contexts &frm_certain_contexts &get_next_word &frm_context &create_order_shiftDEC &flatest_rules &extract_patterns &find_rulegroups &fread_rulegroups &fwrite_rulegroups &find_rulepairs &fread_rulepairs &valid_rulepair &fgen_rulegroups &expand_all_rules &find_rulegroups_after &find_rulegroups_before &fgen_rules_after_groups &extract_patterns_full);
}

#--------------------------------------------------------------------------

sub fread_rules($){
	#Read rules from file 
	#Read rules from file <$fname> into global %rule, %context and %rulecnt
	
	my $fname = shift @_;
	print "-- Enter fread_rules: $fname\n" if $debug;
	open RH, "<:encoding(utf8)", $fname or die "Error opening rules file $fname\n";
	%rule = ();
	%context = ();
	%rulecnt=();
	while (<RH>) {
		chomp;
		my @line=split ";";
		if ($#line==3) {push @line,0;}
		elsif ($#line!=4) { die "Error: problem with $fname rule format"}
		my ($grph,$left,$right,$phn,$cnt) = @line;
		my $pattern = "$left-$grph-$right";
		$rule{$pattern} = $phn;
		$context{$grph}{$pattern}=1;
		$rulecnt{$pattern}=$cnt;
	}
	close RH;
	if ($use_rulepairs==1) {
		fread_rulepairs("$fname.rulepairs");
	}
}


sub fwrite_rules($) {
	#Write ruleset to file
	#Write rules from global %rulecnt if set, else from globals %rule and %context
		
	my $fname = shift @_;
	print "-- Enter fwrite_rules: $fname\n" if $debug;
	open OH, ">:encoding(utf8)", "$fname" or die;
	my @rulecntcheck=keys %rulecnt;
	if ($#rulecntcheck==-1) {
		#foreach my $g (sort keys %context){
		#	my @gcont = keys %{$context{$g}};
		#	foreach my $i (0 .. $#gcont){
		#		my ($left,$g,$right) = split /-/,$gcont[$i];
		#		print OH "$g;$left;$right;$rule{$gcont[$i]}\n";
		#	}
		foreach my $r (keys %rule){
			my ($left,$g,$right) = split /-/,$r;
			print OH "$g;$left;$right;$rule{$r}\n";
		}
	} else {
		my @rlist = sort {$rulecnt{$b} <=> $rulecnt{$a}} keys %rulecnt;
		foreach my $r (@rlist) {
			if ($r !~ /(.*)-(.*)-(.*)/) {die "Error in counted rules"};
			print OH "$2;$1;$3;$rule{$r};$rulecnt{$r}\n";
		}	
	}
	close OH;
}


#--------------------------------------------------------------------------

sub valid_rulepair_next($$$) {
	my ($posrule,$i,$word) = @_;
	if (!(exists $rulepairs{$posrule})) {
		return 1;
	}
	my $nextpat = substr($word,0,$i+2) . "-" .  substr($word,$i+2,1) . "-" .  substr($word,$i+3);
	foreach my $r2 (keys %{$rulepairs{$posrule}}) {
		if ($nextpat =~ /$r2/) {
			return (&valid_rulepair_next($r2,$i+1,$word));
		}
	}
	return 0;
}

sub valid_rulepair_previous($$) {
	my ($prevrule,$posrule) = @_;
	if (!(exists $rulepairs{$prevrule})) {
		return 1;
	}
	if (exists $rulepairs{$prevrule}{$posrule}) {
		return 1;
	}
	return 0;
}

#--------------------------------------------------------------------------


sub verify_validrule ($\@$\$){
	#Determine if a rule is valid to extract from a word given a conflicting word list
	#Return 1 if <word> matches <rule> 
	
	my ($word,$cmplistp,$rule,$patp) = @_;
	print "<p>-- Enter verify_validrule $word, $rule, @$cmplistp\n" if $debug;
	my $matched = 0; my $j = 0;
	if ($word =~ /.*($rule).*/) { 
		$$patp = $1;
	} else { 
		print "Context $rule: error matching $word\n" if $debug; 
		return 0;
	}
	while ($j<=$#$cmplistp) {
		print "Context $rule: match [$$cmplistp[$j]] with [$pat]\n" if $debug;
		if ($$cmplistp[$j] =~ /$$patp/) {return 0}
		$j++;
	}
	print "Valid!\n" if $debug;
	return 1;
}

#--------------------------------------------------------------------------

sub next_pat_bounce($\@$$$$){
	my ($patp,$gstrp,$lip,$rip,$rightp,$csizep) = @_;
	my $found=0;
	while ($found==0) {
		if ($$rightp==1) {
			if ($$rip <= $#$gstrp) {
				$$patp = $$patp. $gstrp->[$$rip];
				$$rip++;
				$$csizep++;
				$found=1;
			}
			$$rightp=0;
		} elsif ($$rightp==0) {
			if ($$lip >= 0) {
				$$patp = $gstrp->[$$lip].$$patp;
				$$lip--;
				$$csizep++;
				$found=1;
			}
		$$rightp=1;
		}
	}
}


sub next_pat_shift($$$$$$$$){
	my ($gstr,$g,$gi,$addrightp,$numchangep,$rightp,$csizep,$patp) = @_;
	my $addleft;
	my $glen = length $gstr;
	my $found=0;
	while (($found==0)&&($$csizep<=$glen)) {
		if ($$numchangep == $$csizep-1) {
			$$csizep++;
			$$numchangep=0;
			$$addrightp = int ($$csizep/2);
			$addleft = $$csizep - $$addrightp - 1;
			if ($$addrightp == $addleft) {$$rightp=1}
			else {$$rightp=0}
			
		} else {
			if ($$rightp==1) {
				$$numchangep++;
				$$addrightp+= $$numchangep;
				$$rightp=0;
			} else {
				$$numchangep++;
				$$addrightp-= $$numchangep;
				$$rightp=1;
			}
			$addleft = $$csizep - $$addrightp - 1;
		}
		if (($$addrightp+$gi < $glen)&&($addleft <= $gi)) {
			$found=1;
		}
	}
	if ($found==1) {
		$$patp = (substr($gstr,$gi-$addleft,$addleft)."-$g-".(substr($gstr,$gi+1,$$addrightp)));
		#print "[$$patp]\n";
	} else {
		print "Warning: possible error in next_pat_shift\n";
	}
}

#--------------------------------------------------------------------------

sub fwrite_patts_full(\%$) {
	#Append all patterns in <allp> to pattern files <fname>.<g>
	my ($allp,$fname) = @_;
	foreach my $g (keys %$allp) {
		open OH, ">>:encoding(utf8)", "$fname.$g" or die "Error opening $fname.$g\n";
		my $gp = $allp->{$g}; 
		foreach my $p (keys %$gp) {
			my $pp = $gp->{$p};
			foreach my $pat (keys %$pp) {
				my $wp = $pp->{$pat};
				print OH "$p;$pat";
				foreach my $word (keys %$wp) {
					print OH ";$word";
					delete $wp->{$word};
				}
				print OH "\n";
				delete $pp->{$pat};
			}
			delete $gp->{$p};
		}
		close OH;
	}
}


sub fread_gpatts_full(\%\%$) {
	#Read all patterns from <$fname> (related to a single grapheme)
	#Update <$gp>
	my ($gp,$wp,$fname) = @_;
	open IH, "<:encoding(utf8)", "$fname" or die "Error opening $fname\n";	
	while (<IH>) {
		chomp;
		my ($p,$pat,@words) = split ";";
		$gp->{$pat}{$p}=(scalar @words);
		foreach my $w (@words) {
			$wp->{$w}=$p;
		}
	}
	close IH;
}


sub fwrite_patts(\%$) {
	my ($allp,$fname) = @_;
	foreach my $g (keys %$allp) {
		open OH, ">>:encoding(utf8)", "$fname.$g" or die "Error opening $fname.$g\n";
		my $gp = $allp->{$g}; 
		foreach my $p (keys %$gp) {
			my $pp = $gp->{$p};
			foreach my $pat (keys %$pp) { 
				next if (($pat eq 'words') || ($pat eq 'total'));
				print OH "$p;$pat\n";
				delete $pp->{$pat};
			}
		}
		close OH;
	}
}

#--------------------------------------------------------------------------

sub fwrite_patts_last(\%$) {
	my ($allp,$fname) = @_;
	foreach my $g (keys %$allp) {
		open OH, ">>:encoding(utf8)", "$fname.$g" or die "Error opening $fname.$g\n";
		my $gp = $allp->{$g};
		print OH "TOTAL\n";
		foreach my $p (keys %$gp) {
			my $tot = $gp->{$p}{'total'};
			print OH "$p;$tot\n";
		}
		print OH "WORDS\n";
		foreach my $p (keys %$gp) {
			my @words = keys %{$gp->{$p}{'words'}};
			$" = ";";
			print OH "$p;@words\n";
			$"=" ";
		}
		close OH;
	}
}


sub fread_gpatts(\%$) {
	my ($gp,$fname) = @_;
	open IH, "<:encoding(utf8)", "$fname" or die "Error opening $fname\n";
	
	my $l=<IH>;
	chomp $l;
	while (!($l eq "TOTAL")) {
		my ($p,$pat) = split ";",$l;
		$gp->{$p}{$pat}=1;
		$l=<IH>;
		chomp $l;
	}
	
	$l=<IH>;
	chomp $l;
	while (!($l eq "WORDS")) {
		my ($p,$total) = split ";",$l;
		$gp->{$p}{'total'}=$total;
		$l=<IH>;
		chomp $l;

	}
	
	while (<IH>) {
		chomp;
		my ($p,@words) = split ";";
		foreach my $w (@words) {
			$gp->{$p}{'words'}{$w}=1;
		}
	}
	close IH;
}

sub extract_patterns(\%\%$) {
	my ($agdp,$apdp,$pattsfile) = @_;
	print "<p>-- Enter extract_patterns\n" if $debug;
	my %all = ();
	#system "rm db_all.*";
	#dbmopen(%all,"db_all",0666) || die "Cannot open db db_all";
	my ($ri,$li,$right,$csize,$addright,$numchange);
	my $cnt=0;
	my $max_words=5000;
	frm_patts($pattsfile,$grpt);
	#%word_match=();
	#%pat_match=();
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
			my @tmp_pats=();
			my $g = $gstr[$i];
			my $p = $pstr[$i];
			my $tmpstr = "-".$g."-";
			my $csize = 1;
			$all{$g}{$p}{$tmpstr}=1;
			#$gplp = $all{$g}{$p};
				
			$right=1;
			if ($rtype eq "bounce") {
				my $ri = $i+1;
				my $li = $i-1;
				while ($csize<$wlen) {
					next_pat_bounce(\$tmpstr,@gstr,\$li,\$ri,\$right,\$csize);
					push @tmp_pats,$tmpstr;
				}
			} else {
				$addright=0;
				$numchange=0;
				while ($csize<$wlen) {
					next_pat_shift($patstr,$g,$i,\$addright,\$numchange,\$right,\$csize,\$tmpstr);
					push @tmp_pats,$tmpstr;
				}
			}
			$all{$g}{$p}{'words'}{$tmpstr}=1;
			$all{$g}{$p}{'total'}++;
			#$gplp->{'words'}{$tmpstr}=1;
			#$gplp->{'total'}++;
			foreach my $tp (@tmp_pats){
				#$word_match{$g}{$tp}{$tmpstr}=1;
				#$pat_match{$g}{$tmpstr}{$tp}=1;
				$all{$g}{$p}{$tp}=1
				#$gplp->{$tp}=1;
			}
		}
		$cnt++;
		if ($cnt==$max_words) {
			fwrite_patts(%all,$pattsfile);
			$cnt=0;
		}
		delete $agdp->{$word};
		delete $apdp->{$word};
	}
	fwrite_patts(%all,$pattsfile);
	fwrite_patts_last(%all,$pattsfile);
	#dbmclose(%all);
}


sub extract_patterns_full(\%\%$) {
	my ($agdp,$apdp,$pattsfile) = @_;
	print "<p>-- Enter extract_patterns_full\n" if $debug;
	my %all = ();
	my ($ri,$li,$right,$csize,$addright,$numchange);
	my $cnt=0;
	my $max_words=500;
	frm_patts($pattsfile,$grpt);
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
			my $tmpstr = "-".$g."-";
			my $csize = 1;
			my @tmp_pats=($tmpstr);
				
			$right=1;
			if ($rtype eq "bounce") {
				my $ri = $i+1;
				my $li = $i-1;
				while ($csize<$wlen) {
					next_pat_bounce(\$tmpstr,@gstr,\$li,\$ri,\$right,\$csize);
					push @tmp_pats,$tmpstr;
				}
			} else {
				$addright=0;
				$numchange=0;
				while ($csize<$wlen) {
					next_pat_shift($patstr,$g,$i,\$addright,\$numchange,\$right,\$csize,\$tmpstr);
					push @tmp_pats,$tmpstr;
				}
			}
			#$gplp->{'words'}{$tmpstr}=1;
			#$gplp->{'total'}++;
			#$all{$g}{$p}=();
			#$gplp = $all{$g}{$p};
			foreach my $tp (@tmp_pats){
				$all{$g}{$p}{$tp}{$tmpstr}=1;
			}
		}
		$cnt++;
		if ($cnt==$max_words) {
			fwrite_patts_full(%all,$pattsfile);
			$cnt=0;
		}
		delete $agdp->{$word};
		delete $apdp->{$word};
	}
	fwrite_patts_full(%all,$pattsfile);
}

#extract_words(grapheme,aligned_gdict*,aligned_pdict*,gwords*)
sub extract_words($\%\%\%) {
	#Find all aligned words containing a specific grapheme 
	#in preparation for rule extraction
	#Use aligned dictionary <agdp>,<apdp> to extract all words
	#containing grapheme <$g> and add to word list <gwp> as l-g-r patterns

	my ($g,$agdp,$apdp,$gwp) = @_;
	print "<p>-- Enter extract_words $g\n" if $debug;
	%$gwp = ();
	foreach $word (keys %{$agdp}) {
		my @gstr = @{$agdp->{$word}};
		my $tmpstr = join "",@gstr;
		if ($tmpstr =~ /$g/) {
			for my $i ( 0 .. $#gstr ) {
				if ($gstr[$i] eq $g) {
					my $l = substr $tmpstr,0,$i;
					my $r =  substr $tmpstr,$i+1;
					$pat = " ".$l."-$g-".$r." ";
					$gwp->{$pat} = ${$apdp->{$word}}[$i];
					print "New word:  $pat --> $gwp->{$pat} \n" if $debug;
				}
			}
		}
	}
}

#--------------------------------------------------------------------------

sub add_backoff(\%$\%) {
	my ($gbp,$g,$gpatp)=@_;
	foreach my $posrule (keys %$gbp) {
		if (!(exists $rule{$posrule})) {
			#my @posphones = keys %{$gbp->{$posrule}};
			my @posphones = keys %{$patp};
			my $bestcnt=0;
			foreach my $posp (@posphones) {
				my $cnt=0;
				foreach my $posw (keys %{$gpatp->{$posp}{'words'}}) {
					if ($posw =~ /$posrule/) {
						$cnt++;
					}
				}
				if ($cnt>$bestcnt) {
					$bestcnt=$cnt;
					$bestp=$posp;		
				}
			}
			if ($bestcnt>0) {
				$rule{$posrule}=$bestp;
				$context{$g}{$posrule}=1;
			}
		}
	}
}

sub numpats { $gpatp->{$b}{'total'}<=>$gpatp->{$a}{'total'};}


sub rules_from_pats_bounce($\%) {
	#Extract the best grapheme-specific rules based on the set of patterns in <patp>
	#Results in <grp>
	
	my $g = shift @_;
	local $gpatp = shift @_;	#local since used in numpats
	print "<p>-- Enter rules_from_pats_bounce $g\n" if $debug;
	
	my @pdone = ();
	my @porder = sort numpats keys %$gpatp;
	print "Phone order: @porder\n" if $debug;
	
	$p = shift @porder;
	$rule{"-$g-"} = $p;
	$context{$g}{"-$g-"}=1;
	push @pdone, $p;
	print "Next rule for $g : -$g- --> $p " if $debug;
		
	while ($#porder >= 0) {
		$p = shift @porder;
		@words = keys %{$gpatp->{$p}{'words'}};
		print "Finding best rules for $p\n" if $debug;	
		my ($posrule,@gstr,$ri,$li,$addright,$numchange);
		@pconflict = @pdone;
		
		foreach my $word (@words) {			
			my $valid=0;
			print "Add new rule to diff $word from patterns associated with phones in [@pconflict]\n" if $debug;
			my $wlen = (length $word)-2;
			my $csize = 1;
			my $right = 1;
			my $gpos = index $word,"-$g-";
			$posrule = "-$g-";
		
			@gstr = split //,$word;
			$ri = $gpos+3;
			$li = $gpos-1;
			
			while ($csize<$wlen) {
				next_pat_bounce(\$posrule,@gstr,\$li,\$ri,\$right,\$csize);
							
				$match=0;
				print "Testing [$posrule]\n" if $debug;
				foreach my $pc (@pconflict) {
					if (exists $gpatp->{$pc}{$posrule}) {
						$match=1;
						last;
					}
				}
				if ($match==0) {
					$rule{$posrule}=$p;
					$context{$g}{$posrule}=1;
					$valid=1;	
					print "Next rule for $g : [$posrule] --> $p\n" if $debug;
					last;
				}
			}
			if (!($valid)) {
				print "Error - need larger context for $g : $word --> $p\n";
			}
		}
		push @pdone,$p;
	}
}


sub rules_from_pats_win($\%$) {
	#Extract the best grapheme-specific rules based on the set of patterns in <patp>
	#Results in <grp>
	
	my $g = shift @_;
	local $gpatp = shift @_;	#local since used in numpats
	my $num = shift @_;
	print "<p>-- Enter rules_from_pats_win $g, extracting $num rule(s)\n" if $debug;
	
	my @porder = sort numpats keys %$gpatp;
	#print "Phone order: @porder\n" if $debug;
	#foreach my $p (@porder) {
	#	print "$g -> $p [$gpatp->{$p}{'total'}]\n";
	#}
	my %pcmp =();
	foreach my $pc (@porder) {$pcmp{$pc}=1;}
	
	my $p;
	my $deftresh=0;
	if ($#porder==0) {
		$p = shift @porder;
	} else {
		#if (($gpatp->{$porder[0]}{'total'}/$gpatp->{$porder[1]}{'total'})>$defthres) {
			$p = shift @porder;
		#} else {
		#	$p = $porder[0];
		#}
	}
	$rule{"-$g-"} = $p;
	$context{$g}{"-$g-"}=1;
	print "Next rule for $g : -$g- --> $p " if $debug;
	
	my %gbackoff=();

	while ($#porder >= 0) {
		$p = shift @porder;
		@words = keys %{$gpatp->{$p}{'words'}};
		print "Finding best rules for $p\n" if $debug;	
		
		my %tmpcmp = %pcmp;
		delete $tmpcmp{$p};
		@pconflict = keys %tmpcmp;
		
		foreach my $word (@words) {			
			print "Add new rule to diff $word from patterns associated with phones in [@pconflict]\n" if $debug;
			my $gpos = index $word,"-$g-";
			my $posrule = "-$g-";
			$word=~ s/-//g;
			my $wlen = length $word;
			
			my $valid=0;
			my $csize = 1;
			my $right = 1;
			my $addright=0;
			my $numchange=0;
			my $fix=100;
			while ($csize<=$wlen) {							
				$match=0;
				print "Testing [$posrule]\n" if $debug;
				foreach my $pc (@pconflict) {
					if (exists $gpatp->{$pc}{$posrule}) {
						$match=1;
						#if ((!(exists $rule{$posrule}))&&($fix==100)) {
						#	$gbackoff{$posrule}=1;
						#}
						last;
					}
				}
				if ($match==0) {
					$rule{$posrule}=$p;
					$context{$g}{$posrule}=1;
					$valid=1;	
					print "Next rule for $g : [$posrule] --> $p\n" if $debug;
					if ($num eq "one") {
						last;
					} else {
						if ($fix==100) {$fix=$csize;}
					}
				}
				if ($csize<$wlen) {
					next_pat_shift($word,$g,$gpos,\$addright,\$numchange,\$right,\$csize,\$posrule);
				} else { $csize++};
				last if ($csize>$fix);
			}
			if (!($valid)) {
				print "Error - need larger context for $g : $word --> $p\n";
			}
		}
	}
	#add_backoff(%gbackoff,$g,%$gpatp);
}


sub cnt_gpats ($\%) {
	#Calculate the rule probability: number of times each rule holds / number of time each rule-pattern observed
	#Use global %rule, %context
	#Result in global %rulecnt
	my ($g,$gp) = @_;
	my %truecnt=();
	my %totalcnt=();
	foreach my $r (keys %{$context{$g}}) {
		my $p = $rule{$r};
		my @postrue = keys %{$gp->{$p}{'words'}};
		foreach my $word (@postrue) {
			if ($word =~ /$r/) {
				$truecnt{$r}++;
				$totalcnt{$r}++;
			}
		}
		foreach my $notp (keys %$gp) {
			if ((!($notp eq $p)) && (exists $gp->{$notp}{$r})) {
				my @posfalse = keys %{$gp->{$notp}{'words'}};
				foreach my $word (@posfalse) {
					if ($word =~ /$r/) {
						$totalcnt{$r}++;
					}
				}
			}		
		}

		if (!(exists $truecnt{$r})) {$truecnt{$r}=0;}
		if (!(exists $totalcnt{$r})) {$totalcnt{$r}=0;}
		$rulecnt{$r} = $truecnt{$r}/($totalcnt{$r}+1);
	}
}


sub opt_grules ($\%) {
	#Calculate the rule probability: number of times each rule holds / number of time each rule-pattern observed
	#Optimise according to rule coverage per window
	#Use global %rule, %context
	#Result in global %rulecnt
	my ($g,$gp) = @_;
	my %truecnt=();
	my %totalcnt=();
	my %wlist=();
	foreach my $r (keys %{$context{$g}}) {
		my $p = $rule{$r};
		my @postrue = keys %{$gp->{$p}{'words'}};
		foreach my $word (@postrue) {
			if ($word =~ /$r/) {
				$truecnt{$r}++;
				$totalcnt{$r}++;
				$wlist{$p}{$r}{$word} = 1;
			}
		}
		foreach my $notp (keys %$gp) {
			if ((!($notp eq $p)) && (exists $gp->{$notp}{$r})) {
				my @posfalse = keys %{$gp->{$notp}{'words'}};
				foreach my $word (@posfalse) {
					if ($word =~ /$r/) {
						$totalcnt{$r}++;
					}
				}
			}		
		}

		if (!(exists $truecnt{$r})) {$truecnt{$r}=0;}
		if (!(exists $totalcnt{$r})) {$totalcnt{$r}=0;}
		$rulecnt{$r} = $truecnt{$r}/($totalcnt{$r}+1);
	}
	
	foreach my $p (keys %wlist) {
		@toprules = sort { $truecnt{$b} <=> $truecnt{$a} } keys %{$wlist{$p}};

		foreach my $r (@toprules) {
			if ($truecnt{$r}<1)  {
				#print "Removing $key\n" if $debug;
				delete $rulecnt{$r};
				delete $wlist{$p}{$r};
			} else {
				foreach my $word (keys %{$wlist{$p}{$r}}) {
					foreach my $other (keys %{$wlist{$p}}) {
						if ((!($r eq $other))&&(exists $wlist{$p}{$other}{$word})&&((length $r) == (length $other))) {
						#if ((!($r eq $other))&&(exists $wlist{$p}{$other}{$word})) { 
							delete $wlist{$p}{$other}{$word};
							$truecnt{$other}--;
						}
					}
				}
			}	
		}
	}
}


sub opt_rules(\%\%) {
	#Delete unnecessary rules from rulecnt global var - other rule vars not updated
	#Find all words that match rules, order rules according to most matching words
	#Delete rules already specified by earlier rules
	my ($agdp,$apdp) = @_;
	print "<p>Enter opt_rules\n" if $debug;
	my %tmpcontext=();
	
	read_graphs(@graphs);
	push @graphs,"0";
			
	foreach my $g ( @graphs ) {
		my %wlist=();
		my %rlist=();
		my %gwords=();
				
		foreach my $pat (keys %{$context{$g}}) {
			push @{$rlist{$rule{$pat}}},$pat;
		}
		extract_words($g,%$agdp,%$apdp,%gwords);
		while (my ($word,$phn) = each %gwords) {
			push @{$wlist{$phn}},$word;
		}
			
		foreach $phone (keys %wlist) {
			my %newlist=();
			my %newcount=();
			my %symcount=();
			print "<p>Entering $g->$phone @{$wlist{$phone}}\n" if $debug;
			foreach my $rule (@{$rlist{$phone}}) {
				$newcount{$rule} = 0;
				foreach $word (@{$wlist{$phone}}) {
					if ($word =~ /$rule/) { 
						$newcount{$rule}++;
						$newlist{$rule}{$word} = 1;
						$symcount{$rule} = get_sym($rule);
					}
				}
			}	
			@nkeys = sort { $newcount{$b}<=>$newcount{$a} || $symcount{$a}<=>$symcount{$b}} keys %newlist;
						
			foreach my $key (@nkeys) {
				if ($newcount{$key}<1)  {
					#print "Removing $key\n" if $debug;
					delete $rulecnt{$key};
					delete $newlist{$key};
				} else {
					foreach $word (keys %{$newlist{$key}}) {
						foreach my $cmp (@{$rlist{$phone}}) {
							#if ((!($cmp eq $key))&&(exists $newlist{$cmp}{$word})) { 
							if ((!($cmp eq $key))&&(exists $newlist{$cmp}{$word})&&((length $cmp)==(length $key))) { 
								delete $newlist{$cmp}{$word};
								$newcount{$cmp}--;
							}
						}
					}
				}
			}
		}
	}
}	

#--------------------------------------------------------------------------

sub fgen_rules($$$$) {
	#Generate a new rule set
	#If <pre> read alignments from <aname>
	#If !<pre> generate alignments and write to <aname>
	#Generate a new rule set of type <rtype> based on dictionary <dname> 
	
	my ($dname,$pre,$aname,$gname) = @_;
	print "<p>-- Enter fgen_rules $dname,$pre,$aname,$rtype \n" if $debug;
	my (%agd,%apd,@graphs);

	if ($pre) {
		print "<p>-- Reading pre-aligned dictionary --\n" if $msg;
		fread_align($aname,%agd,%apd);
	} else {
		print "<p>-- Aligning dictionary --\n" if $msg;
		falign_dict($dname,$aname,$gname,0);
		fread_align($aname,%agd,%apd);
	}
	
	my $t = gmtime();
	print "TIME\tgen_rules initialised:\t$t\n";
	
	my $pattsfile;
	if ($rtype eq "bounce") {
		$pattsfile="$dname.patts.bounce";
	} else {
		$pattsfile="$dname.patts.win";
	}
	
	my $prepatts=1;
	if ($prepatts==0) {
		extract_patterns(%agd,%apd,$pattsfile);
	}
	
	$t = gmtime();
	print "TIME\tpatterns extracted:\t$t\n";

	%rule=();
	%rulecnt=();
	read_graphs(@graphs);
	push @graphs,"0";
	
	foreach my $g ( @graphs ) {
		my %gpatts=();
		if (-e "$pattsfile.$g") {
			fread_gpatts(%gpatts,"$pattsfile.$g");
			print "<p>-- Finding best rules for $g --\n" if $msg;
			if ($rtype eq "bounce") {
				rules_from_pats_bounce($g,%gpatts);
			} elsif ($rtype eq "win") {
				rules_from_pats_win($g,%gpatts,'one');
				cnt_gpats($g,%gpatts);
			} elsif ($rtype eq "win_max") {
				rules_from_pats_win($g,%gpatts,'max');
				cnt_gpats($g,%gpatts);
			} elsif ($rtype eq "win_min") {
				rules_from_pats_win($g,%gpatts,'max');
				opt_grules($g,%gpatts);
			}
		} else {
			$rule{"-$g-"} = "0";
			$context{$g}{"-$g-"}=1;
			if (!($rtype eq "bounce")) {
				$rulecnt{"-$g-"}=0.5;
			}
		}
	}
	
	$t = gmtime();
	print "TIME\trules generated:\t$t\n";
	
	#$t = gmtime();
	#print "TIME\trules counted:\t\t$t\n";
}

#--------------------------------------------------------------------------

sub can_expand($) {
	my $r=shift @_;
	if ($r =~ /<.*>/) {
		return 1;
	}
	return 0;
}

sub expand_rule($\%) {
	my ($newr,$newrp)=@_;
	my @rlist=split //,$newr;
	my $i=0;
	my %newrules=();
	$newrules{""}=1;
	while ($i<=$#rlist) {
		if ($rlist[$i] eq "<") {
			$i++;
			my $setstr="";
			while (!($rlist[$i] eq ">")) {
				$setstr=$setstr.$rlist[$i];
				$i++;
			}
			#if using numbers for setnames - easier to order
			#my $setnum = int $setstr;
			foreach my $rpart (keys %newrules) {
				#foreach my $g (keys %{$inset{$setnum}}) {
				if ($setstr eq " ") {$setstr="_";}
				foreach my $g (keys %{$inset{$setstr}}) {
					if ($g eq "_") {$g=" ";}
					my $rnext = $rpart.$g;
					$newrules{$rnext}=1;
				}
				delete $newrules{$rpart};
			}
		} else {
			foreach my $rpart (keys %newrules) {
				my $rnext = $rpart.$rlist[$i];
				$newrules{$rnext}=1;
				delete $newrules{$rpart};
			}
		}
		$i++;
	}
	%$newrp = %newrules;
	my @numrules = keys %newrules;
	return (scalar @numrules);
}


sub expand_all_rules() {
	foreach my $origr (keys %rule) {
		my $p = $rule{$origr};
		my %newrules=();
		if (can_expand($origr)==1) {
			expand_rule($origr,%newrules);
			foreach my $newr (keys %newrules) {
				$rule{$newr}=$p;
			}
			delete $rule{$origr}
		}
	}
}

sub word_matches_rule($$) {
	my ($word,$pat) = @_;
	my %rulelist=();
	if (can_expand($pat)==1) {
		expand_rule($pat,%rulelist);
	} else {
		$rulelist{$pat}=1;
	}
	foreach my $rpat (keys %rulelist) {
		if ($word =~ /$rpat/) {
			return 1;
		}
	} 
	return 0;
}


sub next_grpat_bounce($\@$$$$$){
	my ($patp,$gstrp,$lip,$rip,$rightp,$csizep,$wgp) = @_;
	my $found=0;
	while ($found==0) {
		if ($$rightp==1) {
			if ($$rip <= $#$gstrp) {
				$$wgp = $gstrp->[$$rip];
				$$patp = $$patp.'.';
				$$rip++;
				$$csizep++;
				$found=1;
			}
			$$rightp=0;
		} elsif ($$rightp==0) {
			if ($$lip >= 0) {
				$$wgp = $gstrp->[$$lip];
				$$patp = '.'.$$patp;
				$$lip--;
				$$csizep++;
				$found=1;
			}
		$$rightp=1;
		}
	}
}

sub fix_rule($$) {
	my ($rulep,$word)=@_;
	if ($word !~ /^(.*-).-.*$/) {
		die "Error matching word in fix_rule\n";
	}
	my $wg = length $1;
	if ($$rulep =~ /^(.*-.-)(.*)\.(.*)$/) {
		$wr = $wg+1+(length $2)+1;
		$$rulep = $1.$2.(substr $word,$wr,1).$3;
	} elsif ($$rulep =~ /(.*)\.(.*)(-.-.*)/) {
		$wr = $wg-1-(length $2)-1;
		$$rulep = $1.(substr $word,$wr,1).$2.$3;
	} else {
		die "Error replacing wildcard in fix_rule\n";
	}
}

sub fix_rule_g($$) {
	my ($rulep,$g)=@_;
	if ($$rulep =~ /^(.*)\.(.*)$/) {
		$$rulep = $1.$g.$2;
	} else {
		die "Error replacing wildcard in fix_rule\n";
	}
}


sub set_exists_exact(\%\%) {
	use List::Compare;
	my ($inp,$outp) =@_;
	my @inlist = keys %$inp;
	my @outlist = keys %$outp;
	
	foreach my $i (1..$setnum) {
		my @in_i = keys %{$inset{$i}};
		my $lc = List::Compare->new(\@inlist, \@in_i);
		my @indiff = $lc->get_symmetric_difference;
		if ((scalar @indiff) == 0) {
			my @out_i = keys %{$outset{$i}};
			$lc = List::Compare->new(\@outlist, \@out_i);
			my @outdiff = $lc->get_symmetric_difference;
			if ((scalar @outdiff) == 0) {
				return $i;
			}
		}
	}
	return 0;
}


sub set_exists_inmatch(\%\%) {
	use List::Compare;
	my ($inp,$outp) =@_;
	my @inlist = keys %$inp;
	
	foreach my $i (1..$setnum) {
		my @in_i = keys %{$inset{$i}};
		my $lc = List::Compare->new(\@inlist, \@in_i);
		my @indiff = $lc->get_symmetric_difference;
		if ((scalar @indiff) == 0) {
			foreach my $out (keys %$outp) {
				if (!(exists $confset{$i}{$out})) {
					$outset{$i}{$out}=1;
				}
			}
			return $i;
		}
	}
	return 0;
}

sub find_set_fix_rule($$$\@\%\@) {
	my ($posrulep,$p,$word,$pcp,$gpatp,$graphp) = @_;
	print "Testing [$$posrulep]\n" if $debug;
	
	$posnum = $setnum;
	$posnum++;
	%posin =();
	%posout=();
	%posconf=();
	foreach my $g (@$graphp) {
		my $testrule = $$posrulep;
		$testrule =~ s/\./$g/;
		if (exists $gpatp->{$p}{$testrule}) {
			if (exists $posout{$g}) {
				$posconf{$g}=1;
			} else {
				$posin{$g}=1;
			}
		}
		foreach my $pc (@$pcp) {
			if (exists $gpatp->{$pc}{$testrule}) {
				if (exists $posin{$g}) {
					$posconf{$g}=1;
				} else {
					$posout{$g}=1;
				}
			}
		}
	}
	foreach my $g (keys %posconf) {
		if (exists $posin{$g}) {delete $posin{$g}};
		if (exists $posout{$g}) {delete $posout{$g}};
	}
	
	my @inlist = keys %posin;
	if ((scalar @inlist)>1) {
		my $foundset = set_exists_inmatch(%posin,%posout);
		if ($foundset!=0) {
			$tmpr = $$posrulep;
			$tmpr =~ s/\./<$foundset>/;
			if (word_matches_rule($word,$tmpr)==1) {
				$$posrulep = $tmpr;
				return 1;
			}
		} else {
			$setnum++;
			foreach my $gi (keys %posin) {
				$inset{$setnum}{$gi}=1;
			}
			foreach my $go (keys %posout) {
				$outset{$setnum}{$go}=1;
			}
			foreach my $gc (keys %posconf) {
				$confset{$setnum}{$gc}=1;
			}
			$tmpr = $$posrulep;
			$tmpr =~ s/\./<$setnum>/;
			if (word_matches_rule($word,$tmpr)==1) {
				$$posrulep = $tmpr;
				return 1;
			} 
		}
	} elsif ((scalar(@inlist))==1)  {
		my $tmpr = $$posrulep;
		fix_rule_g(\$tmpr,$inlist[0]);
		if (word_matches_rule($word,$tmpr)==1) {
			$$posrulep = $tmpr;
			return 1;
		} 
	}
	fix_rule($posrulep,$word);
	return 0;
}

sub rule_match_pats($$\@\%) {
	#Returns 1 if rule <posrule> matching <g> in the wildcard pos does not match any phone in <pcconflictp>
	#according to patterns in <gpatp>
	my ($posrule,$g,$pcp,$gpatp) = @_;
	my $tmprule=$posrule;
	fix_rule_g(\$tmprule,$g);
	foreach my $pc (@$pcp) {
		if (exists $gpatp->{$pc}{$tmprule}) {
			return 0;
		}
	}
	return 1;
}	


sub match_set_fix_rule($$$\@\%\@) {
	my ($posrulep,$wg,$p,$pcp,$gpatp,$graphp) = @_;
	print "Testing [$$posrulep]\n" if $debug;
	
	if (rule_match_pats($$posrulep,$wg,@$pcp,%$gpatp)!=1) {
		fix_rule_g($posrulep,$wg);
		return 0;
	}
	
	foreach $g (keys %{$inset{$wg}}) {
		next if $g eq $wg;
		if (rule_match_word($$posrulep,$g,@$pcp,%$gpatp)!=1) {
			fix_rule_g($posrulep,$wg);
			return 1;
		}
	}
	$$posrulep =~ s/\./<$wg>/;
	return 1;
}


sub rulegroups_from_pats_bounce($\%) {
	#Extract the best grapheme-specific rules based on the set of patterns in <patp>
	#Results in <grp>
	
	my $g = shift @_;
	local $gpatp = shift @_;	#local since used in numpats
	print "<p>-- Enter rules_from_pats_bounce $g\n" if $debug;
	
	my @pdone = ();
	my @porder = sort numpats keys %$gpatp;
	print "Phone order: @porder\n" if $debug;
	
	my %pcmp=();
	foreach my $pc (@porder) {
		$pcmp{$pc}=1;
	}
	
	$p = shift @porder;
	$rule{"-$g-"} = $p;
	$context{$g}{"-$g-"}=1;
	push @pdone, $p;
	print "Next rule for $g : -$g- --> $p " if $debug;
	
	read_graphs(@graphs);
	push @graphs,"0";
	push @graphs," ";
	
	while ($#porder >= 0) {
		$p = shift @porder;
		@words = keys %{$gpatp->{$p}{'words'}};
		print "Finding best rules for $p\n" if $debug;	
		my ($posrule,@gstr,$ri,$li,$addright,$numchange);
		#my %tmpcmp = %pcmp;
		#delete $tmpcmp{$p};
		#@pconflict = keys %tmpcmp;
		@pconflict = @pdone;
		
		%alreadydone=();
		foreach my $word (@words) {
			next if (exists $alreadydone{$word});
			my $valid=0;
			print "Add new rule to diff $word from patterns associated with phones in [@pconflict]\n" if $debug;
			my $wlen = (length $word)-2;
			my $csize = 1;
			my $right = 1;
			my $gpos = index $word,"-$g-";
			$posrule = "-$g-";
		
			my @gstr = split //,$word;
			$ri = $gpos+3;
			$li = $gpos-1;
			
			my $dummy="";
			while ($csize<$wlen) {
				next_grpat_bounce(\$posrule,@gstr,\$li,\$ri,\$right,\$csize,\$dummy);
				if (find_set_fix_rule(\$posrule,$p,$word,@pconflict,%$gpatp,@graphs)==1) {
					$rule{$posrule}=$p;
					$context{$g}{$posrule}=1;
					$valid=1;	
					print "Next rule for $g : [$posrule] --> $p\n" if $debug;
					last;
				}
			}
			if (!($valid)) {
				print "Error - need larger context for $g : $word --> $p\n";
			}
			foreach my $w (@words) {
				next if ($w eq $word);
				if (word_matches_rule($w,$posrule)==1) {
					$alreadydone{$w}=1;
					print "Rule also used for $w\n" if $debug;
				}
			}
		}
		push @pdone,$p;
	}
}


sub csize_extract_rules($\@\%\%) {
	my ($maxc,$clp,$gcntp,$nrp)=@_;
	%{$nrp}=();
	foreach my $c (@$clp) {
		$nrp->{$c}=1;
	}
}
	

sub rm_newrules_from_pats($\%\%\%$) {
	my ($g,$nrp,$gppatp,$cpatp,$leftp) = @_;
	my @matchwords=();
	foreach my $nr (keys %$nrp) {
		foreach my $w (keys %{$word_match{$g}{$nr}}) {
			if (exists $gppatp->{$w}) {
				push @matchwords,$w;
			}
		}
		foreach my $w (@matchwords) {
			foreach my $pat (keys %{$pat_match{$g}{$w}}) {
				$csize = (length $pat)-2;
				$pat =~ /(.*)-.-(.*)/;
				$i = length $2;
				if (exists $cpatp->{$csize}{$i}{$pat}) {
					delete $cpatp->{$csize}{$i}{$pat};
					$$leftp--;
				}
			}
			print "Rule also used for $w\n" if $debug;
		}
	}
}

sub csize_count_pats(\@\%) {
	my ($clp,$gcntp)=@_;
	my $tot=0;
	my $ci;
	foreach my $c (@$clp) {
		my $tmpc=$c;
		$tmpc =~ s/-.-//g;
		my @cstr=split //,$tmpc;
		$ci=$#cstr;
		foreach my $i (0..$ci){
			$gcntp->{$i}{$cstr[$i]}++;			
		}
		$tot++;
		
	}
	my $score=1;
	foreach my $i (0..$ci) {
		my @gilist=keys %{$gcntp->{$i}};
		my $numgi = scalar @gilist;
		$score = $score * $numgi;
	}
	$score = ($score/$tot);
	return $score;
}

sub get_all_pats($) {
	my $w=shift @_;
	if ($w !~ /(.*)-(.)-(.*)/) {
		die "Error: rule format error in get_all_pats [$w]\n";
	}
	my @patlist=();
	my $left=$1;
	my $g=$2;
	my $right=$3;
	my $leftlen=length $left;
	my $rightlen=length $right;
	foreach my $l (0..$leftlen) {
		$newleft=substr($left,$leftlen-$l,$l);
		foreach my $r (0..$rightlen) {
			$newright=substr($right,0,$r);
			push @patlist,"${newleft}-${g}-${newright}";
		}
	}
	return @patlist;	
}

sub rm_newrules_from_pats_full($$\@\%\%) {
	my ($g,$p,$nrp,$gpatp,$gdonep) = @_;
	
	foreach my $nr (@$nrp) {
		my $wordp=$gpatp->{$nr}{$p};
		foreach my $w (keys %{$wordp}) {
			next if $w eq 'total';
			print "Used for word:\t[$w]\n" if $debug;
			@wordpats = get_all_pats($w);
			foreach my $pat (@wordpats) {
				if (exists $gpatp->{$pat}) {
					$patp=$gpatp->{$pat};
					if ((exists $patp->{$p})&&(exists $patp->{$p}{$w})) {
						delete $patp->{$p}{$w};
						$patp->{$p}{'total'}--;
						$gdonep->{$pat}{$p}{$w}=1;
						$gdonep->{$pat}{$p}{'total'}++;
						if ($patp->{$p}{'total'}==0) {
							delete $patp->{$p}{'total'};
							delete $patp->{$p};
							my @pclist = keys %{$patp};
							if (scalar @pclist==0) {
								delete $gpatp->{$pat};
							}
						}
					}
				}
			}
		}
		foreach my $pc (keys %{$gpatp->{$nr}}) {
			next if $p eq $pc;
			delete $gpatp->{$nr}{$pc};
			$gdonep->{$nr}{$pc}=1;
			print "Disqualified rule:\t[$nr] -> [$pc]\n" if $debug;
		}
		delete $gpatp->{$nr};
	}
}

#--------------------------------------------------------------------------

sub get_info(\@) {
	my ($varp) = shift @_;
	my $sum=0;
	foreach my $i (0..$#$varp) {
		$sum -= $varp->[$i] * Log $varp->[$i];
	}
}

#--------------------------------------------------------------------------

sub find_variability($$\%\%) {
	my ($pat,$p,$posp,$caughtp)=@_;

	my $netmove = $posp->{$pat}{$p};
	foreach my $pc (keys %{$caughtp->{$pat}}) {
		next if $pc eq $p;
		$netmove -= $caughtp->{$pat}{$pc};
	}
	if ($netmove<=0) {return 0}

	my %right=();
	my %left=();	
	my %rightc=();
	my %leftc=();
	my %cntpc=();
	
	foreach my $pat2 (keys %$posp) {
		if (exists $posp->{$pat2}{$p}) {
			if ($pat2 =~ /$pat(.)/) {
				$right{$1}=1;
			}
			if ($pat2 =~ /(.)$pat/) {
				$left{$1}=1;
			}
		}
		 
	}
	foreach my $pat2 (keys %$caughtp) {
		foreach my $pc (keys %{$caughtp->{$pat2}}) {
			next if $pc eq $p;
			if ($pat2 =~ /$pat(.)/) {
				$rightc{$pc}{$1}=1;
			}
			if ($pat2 =~ /(.)$pat/) {
				$leftc{$pc}{$1}=1;
			}
			$cntpc{$pc}=1;
		}
			
	}
	
	my $numright = scalar keys %right;
	my $numleft = scalar keys %left;		
	#my $numrightc = scalar keys %rightc;
	#my $numleftc = scalar keys %leftc;
	#my $varcnt = $numleft*$numright*$netmove;
	
	my $varcnt = min($numleft,$numright);
	foreach my $pc (keys %cntpc) {
		my $numrightc = scalar keys %{$rightc{$pc}};
		my $numleftc = scalar keys %{$leftc{$pc}};
		$varcnt-=min($numleftc,$numrightc);
	}
	return $varcnt;
}


#--------------------------------------------------------------------------

sub rules_after_groups_bounce($\%) {
	#Extract the best grapheme-specific rules based on the set of patterns in <patp>
	#Results in <grp>
	
	my $g = shift @_;
	local $gpatp = shift @_;	#local since used in numpats
	print "<p>-- Enter rules_after_groups_bounce $g\n" if $debug;
	
	my @pdone = ();
	my @porder = sort numpats keys %$gpatp;
	print "Phone order: @porder\n" if $debug;
	
	my %pcmp=();
	foreach my $pc (@porder) {
		$pcmp{$pc}=1;
	}
	
	$p = shift @porder;
	$rule{"-$g-"} = $p;
	$context{$g}{"-$g-"}=1;
	push @pdone, $p;
	print "Next rule for $g : -$g- --> $p " if $debug;
	
	read_graphs(@graphs);
	push @graphs,"0";
	push @graphs," ";
	
	while ($#porder >= 0) {
		$p = shift @porder;
		@words = keys %{$gpatp->{$p}{'words'}};
		print "Finding best rules for $p\n" if $debug;	
		my ($posrule,@gstr,$ri,$li,$addright,$numchange);
		#my %tmpcmp = %pcmp;
		#delete $tmpcmp{$p};
		#@pconflict = keys %tmpcmp;
		@pconflict = @pdone;
		
		%alreadydone=();
		foreach my $word (@words) {
			next if (exists $alreadydone{$word});
			my $valid=0;
			print "Add new rule to diff $word from patterns associated with phones in [@pconflict]\n" if $debug;
			my $wlen = (length $word)-2;
			my $csize = 1;
			my $right = 1;
			my $gpos = index $word,"-$g-";
			$posrule = "-$g-";
		
			my @gstr = split //,$word;
			$ri = $gpos+3;
			$li = $gpos-1;
			
			while ($csize<$wlen) {
				next_grpat_bounce(\$posrule,@gstr,\$li,\$ri,\$right,\$csize,\$wg);
				if (match_set_fix_rule(\$posrule,$wg,$p,@pconflict,%$gpatp,@graphs)==1) {
					$rule{$posrule}=$p;
					$context{$g}{$posrule}=1;
					$valid=1;	
					print "Next rule for $g : [$posrule] --> $p\n" if $debug;
					last;
				}
			}
			if (!($valid)) {
				print "Error - need larger context for $g : $word --> $p\n";
			} else {
				#redundant checking - opt later
				my %rulelist=();
				if (can_expand($posrule)==1) {
					expand_rule($posrule,%rulelist);
				} else {
					$rulelist{$posrule}=1;
				}
				foreach my $rpat (keys %rulelist) {
					foreach my $w (@words) {
						next if ($w eq $word);
						if ($w =~ /$rpat/) {
							$alreadydone{$w}=1;
							print "Rule also used for $w\n" if $debug;
						}
					}	
				}
			}
		}
		push @pdone,$p;
	}
}

sub fgen_rules_after_groups($$$$) {
	my ($dname,$pre,$aname,$gname)=@_;
	#Generate a new rule set
	#If <pre> read alignments from <aname>
	#If !<pre> generate alignments and write to <aname>
	#Generate a new rule set of type <rtype> based on dictionary <dname> 
	
	print "<p>-- Enter fgen_rules $dname,$pre,$aname,$rtype \n" if $debug;
	my (%agd,%apd,@graphs);

	if ($pre) {
		print "<p>-- Reading pre-aligned dictionary --\n" if $msg;
		fread_align($aname,%agd,%apd);
	} else {
		print "<p>-- Aligning dictionary --\n" if $msg;
		falign_dict($dname,$aname,$gname,0);
		fread_align($aname,%agd,%apd);
	}
	
	my $t = gmtime();
	print "TIME\tgen_rules initialised:\t$t\n";
	
	my $pattsfile;
	if ($rtype eq "bounce") {
		$pattsfile="$dname.patts.bounce";
	} else {
		$pattsfile="$dname.patts.win";
	}
	
	my $prepatts=0;
	if ($prepatts==0) {
		extract_patterns(%agd,%apd,$pattsfile);
	}
	
	$t = gmtime();
	print "TIME\tpatterns extracted:\t$t\n";

	%rule=();
	%rulecnt=();
	read_graphs(@graphs);
	push @graphs,"0";
	
	foreach my $g ( @graphs ) {
		my %gpatts=();
		if (-e "$pattsfile.$g") {
			fread_gpatts(%gpatts,"$pattsfile.$g");
			print "<p>-- Finding best rules for $g --\n" if $msg;
			if ($rtype eq "bounce") {
				rules_after_groups_bounce($g,%gpatts);
			}
			#elsif ($rtype eq "win") {
			#	rules_from_pats_win($g,%gpatts,'one');
			#	cnt_gpats($g,%gpatts);
			#} elsif ($rtype eq "win_max") {
			#	rules_from_pats_win($g,%gpatts,'max');
			#	cnt_gpats($g,%gpatts);
			#} elsif ($rtype eq "win_min") {
			#	rules_from_pats_win($g,%gpatts,'max');
			#	opt_grules($g,%gpatts);
			#}
		} else {
			$rule{"-$g-"} = "0";
			$context{$g}{"-$g-"}=1;
			if (!($rtype eq "bounce")) {
				$rulecnt{"-$g-"}=0.5;
			}
		}
	}
	$t = gmtime();
	print "TIME\trules generated:\t$t\n";	
}


sub fgen_rulegroups($$$$) {
	#Generate a new rule set
	#If <pre>==0, generate alignments and pattern files
	#If <pre>==1 read alignments from <aname>, generate pattern files
	#If <pre>==2 read patts from $pattsfile
	#If !<pre> generate alignments and write to <aname>
	#Generate a new rule set of type <rtype> based on dictionary <dname> 
	
	my ($dname,$pre,$aname,$gname) = @_;
	print "<p>-- Enter fgen_rules $dname,$pre,$aname,$rtype \n" if $debug;
	my (%agd,%apd,@graphs);

	if (!($rtype eq 'olist')) {die "Wrong ruletype ($rtype) for extracting groups\n";}

	%inset=();
	%outset=();
	%confset=();
	$setnum=0;
	my $pattsfile="$dname.patts.olist";

	my $t = gmtime();
	print "TIME\tgen_rules initialised:\t$t\n";
	
	if ($pre==0) {
		print "<p>-- Aligning dictionary --\n" if $msg;
		falign_dict($dname,$aname,$gname,0);
	}
	if (($pre==0)||($pre==1)) {
		print "<p>-- Reading pre-aligned dictionary --\n" if $msg;
		fread_align($aname,%agd,%apd);
		print "<p>-- Extracting patterns --\n" if $msg;
		extract_patterns_olist(%agd,%apd,$pattsfile);
		foreach my $ag (keys %agd) {delete $agd{$ag}};
		foreach my $ap (keys %apd) {delete $apd{$ap}};	
	} elsif ($pre==2) {
		print "<p>-- Using pre-extracted patterns --\n" if $msg;
	} else {
		print "Error: unknown type for <pre>\n";
	}
	
	$t = gmtime();
	print "TIME\tpatterns extracted:\t$t\n";

	%rule=();
	%rorder=();
	read_graphs(@graphs);
	push @graphs,"0";
	
	foreach my $g ( @graphs ) {
		my %gpatts=();
		if (-e "$pattsfile.$g") {
			fread_gpatts_full(%gpatts,%gwords,"$pattsfile.$g");
			print "<p>-- Finding best rules for $g --\n" if $msg;
			rulegroups_from_pats_olist($g,100,%gpatts,%gwords);
		} else {
			$rule{"-$g-"} = "0";
			$rorder{$g}[0]="-$g-";
			print "Next rule for $g:\t[0]\t[-$g-] --> 0\n" if $debug;
		}
	}
	
	$t = gmtime();
	print "TIME\trules generated:\t$t\n";
}


#--------------------------------------------------------------------------

sub cntrules_adict (\%\%) {
	#Calculate the rule probability: number of times each rule holds / number of time each rule-pattern observed
	#Use global %rule, %context
	#Returns counts in $rulecntp
	my ($agdp,$apdp) = @_;
	%rulecnt=();
	my %truecnt=();
	my %totalcnt=();
	foreach my $word (keys %{$agdp}) {
		#print "$word\n";
		my @graphs=@{$agdp->{$word}};
		my $l = " "; 
		my $g = $graphs[0]; 
		my $r = substr(join("",@graphs),1)." "; 
		foreach my $i (0..$#graphs) {
			my $template = $l."-".$g."-".$r;
			if (!(exists $context{$graphs[$i]})) {print "Warning: no rules for graph $graphs[$i] (see $template)\n";}
			else {
				@posrules = keys %{$context{$graphs[$i]}};				
				foreach $posrule (@posrules) {
					if ($template =~ /.*($posrule).*/) {
						if ($rule{$posrule} eq $apdp->{$word}->[$i]) {
							$truecnt{$posrule}++;
						} 
						$totalcnt{$posrule}++;
					}
				}
			}
			$l = $l.$g;
			$g = substr $r,0,1; 
			$r=substr $r,1; 
		}	
	}
	foreach my $r (keys %rule) {
		if (!(exists $truecnt{$r})) {$truecnt{$r}=0;}
		if (!(exists $totalcnt{$r})) {$totalcnt{$r}=0;}
		$rulecnt{$r} = $truecnt{$r}/($totalcnt{$r}+1);
	}
}

#--------------------------------------------------------------------------

sub add_word_contexts($$\%){
	my ($word,$cut,$cp) = @_;
	#print "<p>-- Enter add_word_contexts: $word, $cut\n" if $debug;
	$word = " ".$word." ";
	my $num = length $word; 
	foreach my $i (0..$num-$cut) {
		my $newcut = substr $word,$i,$cut;
		if (! exists $cp->{$cut}{$newcut}) {$cp->{$cut}{$newcut} = 1}
		else {$cp->{$cut}{$newcut} = $cp->{$cut}{$newcut}+1 }
	}
}

sub fextract_contexts($$$\%){
	my ($mname,$vis,$cmax,$chashp) = @_;
	print "<p>-- Enter fextract_contexts: $mname, $vis, $cmax\n" if $debug;
	local (@wlist);
	fread_words($mname,@wlist);
	
	my $wnum=1; my $cut; 
	foreach my $word (@wlist) {
		if ($vis) {
			if ($wnum==50) {$wnum=1;print ".\n"}
			$wnum++;
		}
		my $wlength = length $word;
		$cut = 1;
		while (($cut <= $wlength+2)&&($cut<=$cmax)) {
			add_word_contexts($word,$cut,%$chashp);
			$cut++;
		}
	}
}

sub fwrite_contexts($\%$$){
	my ($cname,$chashp,$cmax,$exact) = @_;
	print "<p>-- Enter fwrite_contexts: $cname, $cmax, $exact\n" if $debug;
	if ($exact) {
		#`rm $cname.*`;
		foreach my $cut (1..$cmax) {
			local @wlist=();
			if (exists $chashp->{$cut}) {
				@wlist = sort { $chashp->{$cut}{$b} <=> $chashp->{$cut}{$a} } keys %{$chashp->{$cut}};
			} 
			fwrite_words("$cname.$cut",@wlist);
		}
	} else {
		#`rm $cname.*`;
		%fullstore = ();
		for my $cut (1..$cmax) {
			if (exists $chashp->{$cut}) {
				%fullstore = (%fullstore,%{$chashp->{$cut}});
			}
		}
		local @wlist = ();
		@wlist = sort {$fullstore{$b} <=> $fullstore{$a}} keys %fullstore;
		fwrite_words("$cname.1",@wlist);
	}
}


sub fread_context($$\%){
	my ($cname,$csize,$wlp) = @_;
	local @words;
	fread_words("$cname.$csize",@words);
	my $pos=$#words+1;
	foreach $word (@words) {
		$wlp->{$word}=$pos;
		$pos--;
	}
}

sub fread_contexts($$$\%){
	my ($cname,$cmax,$exact,$chashp) = @_;
	print "<p>-- Enter fread_contexts: $cname, $cmax, $exact\n" if $debug;
	foreach my $csize (1..$cmax) {
		%{$chashp->{$csize}} = ();
	}
	if ($exact) {
		foreach my $csize (1..$cmax) {
			my %clist = ();
			fread_context($cname,$csize,%clist);
			while ( my ($ctxt,$pos) = each %clist) {
				$chashp->{$csize}{$ctxt} = $pos
			}
		}
	} else {
		my %clist = ();
		fread_context($cname,1,%clist);
		foreach my $ctxt (keys %clist) {
			my $csize=length $ctxt;
			if ($csize <= $cmax) {
				$chashp->{$csize}{$ctxt} = $clist{$ctxt}
			}
		}
	}
}

#--------------------------------------------------------------------------

#remove all contexts satisfied by word from chash
sub frm_context($\%$) {
	my ($word,$chashp,$cmax)= @_;
	print "-- Enter frm_contexts: $word, $cmax\n" if $debug;
	$word = " ".$word." ";
	foreach my $cut (1..$cmax) {
		my $wlength = length $word;
		if ($cut <= $wlength+2) {
			my $num = length $word; 
			foreach my $i (0..$num-$cut) {
				$newc = substr $word,$i,$cut;
				my $cmd;
				#print "Removing [$newc] \n" if $debug;
				if (exists $chashp->{$cut}{$newc}) {delete $chashp->{$cut}{$newc}}
			}
		}
	}
}


#remove all contexts satisfied by stat
sub frm_certain_contexts(\%\%$) {
	my ($sp,$chashp,$cmax)= @_;
	print "-- Enter frm_certain_contexts: $cmax\n" if $debug;
	foreach $word (keys %$sp){
		if ($sp->{$word}==1){
			frm_context($word,%$chashp,$cmax)
		}
	}
}

sub get_next_context(\%$$) {
	my ($chashp,$cmax,$exact)= @_;
	print "<p>-- Enter get_next_context: $cmax,$exact\n" if $debug;
	#show_chash($chashp,$cmax);
	my $found=0; my $i=1; my $newname=""; my @clist=();
	if ($exact) {
		while ((!$found)&&($i<=$cmax)) { 
			@clist = keys %{$chashp->{$i}};
			if ($#clist<0) { $i++ }
			else {
				@clist = sort { $chashp->{$i}{$b} <=> $chashp->{$i}{$a}} keys %{$chashp->{$i}};
				$newname = shift @clist;
				$found=1;
			}
		}
	} else {
		%fullstore = ();
		for my $cut (1..$cmax) {
			if (exists $chashp->{$cut}) {
				%fullstore = (%fullstore,%{$chashp->{$cut}});
			}
		}
		@clist = sort { $fullstore{$b} <=> $fullstore{$a}} keys %fullstore;
		if ($#clist>=0) { 
			$newname = shift @clist;
			$found=1;
		}
	}

	if ($found) { 
		print "Next [$newname][$found]\n" if $debug;
		return $newname 
	} else {return 'none'}
}


#get the shortest word containing the next missing context
sub get_next_word($\%$$\%) {
	my ($mname,$chashp,$cmax,$exact,$sp) = @_;
	print "<p>-- Enter get_next_word: $mname, $cmax\n" if $debug;
	my $found=0; my $tofind=" "; my $fword=" "; my @wlist = ();
	
	fread_words($mname,@wlist);
	@wlist = sort {length $b <=> length $a} @wlist;
	while ((!$found)&&(!($tofind eq "none"))) {
		#my $max=1000;
		$tofind = get_next_context(%$chashp,$cmax,$exact);
		print "missing context: $tofind\n" if $debug;
		foreach $word (@wlist) {
			my $tmpword = " ".$word." ";
			if (((!exists $sp->{$word})||($sp->{$word}==0))&&($tmpword=~/$tofind/)){
				#if (length $word < $max) {
					$fword=$word; 
					#$max=length $word;
					$found=1; 
					next;
				#}
			}
		}
		if (!$found) {
			print "About to remove [$tofind] - no words matching context\n" if $debug;
			my $csize = length $tofind;
			if (exists $chashp->{$csize}{$tofind}) { delete $chashp->{$csize}{$tofind} }
		}
	}
	if ($found) {print "Found: $fword\n" if $debug; return $fword}
	else {return 'none'}
}

sub show_chash(\%$) {
	my ($cp,$cmax) = @_;
	print "<p>Current context hash ($cmax):\n";
	foreach my $c (1..$cmax) {
		while (my ($cont,$num) = each %{$cp->{$c}}) {
			print "[$c] $cont = $num\n";
		}
	}
}
	

sub fwlist_frommaster_predict($$$$$$$) {
	my ($mname,$cname,$dname,$max,$otype,$done,$wname) = @_;
	print "<p>-- Enter fwlist_frommaster_predict: $mname, $cname, $dname, $max, $otype, $done, $wname,$cmax\n" if $debug;
	if ($otype eq 'mostFrequent') { $exact=0 } else { $exact=1 };
	local %dict=(); local %stat=(); local %chash=();
	fread_dict($dname,%dict,%stat);
	if ($done==0) { 
		fextract_contexts($mname,1,$cmax,%chash); 
		frm_certain_contexts(%stat,%chash,$cmax);
		fwrite_contexts($cname,%chash,$cmax,$exact);
	} elsif ($done==1) { 
		fread_contexts($cname,$cmax,$exact,%chash);
		frm_certain_contexts(%stat,%chash,$cmax);
		fwrite_contexts($cname,%chash,$cmax,$exact);
	} elsif ($done==2) { 
		fread_contexts($cname,$cmax,$exact,%chash);
	} else {
		die "Unknown preparation type $done\n";
	}

	my $tsize=0;
	my @words = ();
	while ($tsize<$max) {
		my $newword = get_next_word($mname,%chash,$cmax,$exact,%stat);
		if ($newword eq 'none') { last }
		else {
			push @words,$newword;
			$tsize++;
			frm_context($newword,%chash,$cmax);
			print "<p>HERE [$tsize] $newword\n"
		}
	}
	fwrite_words($wname,@words);
	#show_chash(%chash,$cmax);
	return $tsize;
}

#--------------------------------------------------------------------------

sub fcount_rules($\%) {
	my ($fname,$statp) = @_;
	%$statp = ();
	print "-- Enter fcount_rules $fname" if $debug;
	fread_rules($fname);
	for my $i (0 .. $maxContext) {$statp->{$i} = 0}
	$statp->{'total'} = 0;
	foreach my $pat (keys %rule){
		if (length $pat > 1){
			$statp->{(length $pat) - 2}++;
			$statp->{'total'}++;
		}
	}
}


sub find_all_templates($) {
	#find all templates of size up to <$csize>
	my $csize=shift @_;
	my @order=();
	foreach my $l (0..$csize) {
		foreach my $r (0..($csize-$l)) {
			my $tmpstr="";
			foreach my $li (0..$l) {
				$tmpstr = $tmpstr.".";
			}
			$tmpstr = $tmpstr."-.-";
			foreach my $ri (0..$r) {
				$tmpstr = $tmpstr.".";
			}
			push @order, $tmpstr;
		}
	}
}

sub fcount_contexts ($\%) {
	my ($fname,$statp) = @_;
	%$statp = ();
	print "-- Enter fcount_context $fname" if $debug;
	fread_rules($fname);
 	my @order = find_all_templates(5);
        foreach my $pat (@order) {$statp->{$pat} = 0;}
       	foreach my $arule (keys %rule) {
		foreach my $pat (@order) {
			if ($arule =~ /$pat/) {$statp->{$pat}++;}
		}
	}
}

#test_rules(dname,result*) - uses global %context,%rule
sub test_rules($\%) {
	my ($dname,$resultp) = @_;
	my (%dict,%stat);
	print "-- Enter test_rules $dname" if $debug;
	fread_dict($dname,%dict,%stat);
	$resultp->{missing} = (); $resultp->{extra} = ();
	my (@same, @diff); $#same=-1;$#diff=-1;
	foreach $word (keys %dict) {
		local $sound;
		g2p_word($word,\$sound);
		if ($dict{$word} eq $sound) { push @same,$word } 
		else { push @diff, $word."(".$dict{$word}."|".$sound.")" }
	}
	$resultp->{same} = join " ",@same; 
	$resultp->{diff} = join " ",@diff;
}


#--------------------------------------------------------------------------
#POSSIBLY UNNECESSARY - CHECK THESE

sub replace_rules($) {
	#add $newrule to global $rule
	#remove all rules matched by $newrule
	my ($newrule) = @_;
	my %rulelist;
	if (can_expand_rule($newrule)==0) {
		expand_rule($newrule,%rulelist);
		my @patlist = keys %rulelist;
		my $p = $rule{$patlist[0]};
		foreach my $newpat (@patlist) {
			if (exists $rule{$newpat}) {
				delete $rule{$newpat};
			} else {
				print "Warning: possible error in replace_rules\n";
			}
		}
	}
	$rule{$newrule}=$p;
}


sub check_valid($$\%) {
	my ($newrule,$p,$gpatp)=@_;
	my %rulelist;
	expand_rule_v1($newrule,%$ginp,%rulelist);
	foreach my $r (keys %rulelist) {
		foreach my $cp (keys %gpatp) {
			next if ($cp eq $p);
			foreach my $r2 (keys %{$gpatp->{$cp}}) {
				if ($r2 =~ /$r/) {
					return 0;
				}
			}
		}
	}
	return 1;
}


sub find_group($\%\%\%\%$$) {
	my ($g,$gcntp,$gpatp,$ginp,$goutp,$setp,$newrp) = @_;
	my $found=0;
	my $valid=0;
	my %vallist=();
	my $numcheck;
	my $csize;
	foreach my $p (keys %$gcntp) {
		my @ilist = keys %{$gcntp->{$p}};
		$numcheck = $#ilist+1;
		$csize=$numcheck+1;
		foreach my $i (@ilist) {
			my @glist= keys %{$gcntp->{$p}{$i}};
			if ((scalar @glist)==1) {
				my $gi = pop @glist;
				if ($gcntp->{$p}{$i}{$gi}!=1) {
					$valid++;
					$vallist{$i}=1;
				}
			} 
		}
		if ($numcheck-$valid<=1) {
			$numleft=int(($csize-1)/2);
			$numright=$csize-1-$numleft;
			my @rlist=();
			foreach my $j (0..$numleft-1) {
				my @tmplist = keys %{$gcntp->{$p}{$j}};
				if (exists $vallist{$j}) {
					push @rlist, (pop @tmplist);
				} else {
					$$setp++;
					push @rlist,"<$$setp>";
					foreach my $gin (@tmplist) {
						$ginp->{$$setp}{$gin}=1;
					}
				}
			}
			push @rlist, "-$g-"; 
			foreach my $j ($numleft+3..$numleft+$numright+2) {
				my @tmplist = keys %{$gcntp->{$p}{$j}};
				if (exists $vallist{$j}) {
					push @rlist, (pop @tmplist);
				} else {
					$$setp++;
					push @rlist,"<$$setp>";
					foreach my $gin (@tmplist) {
						$ginp->{$$setp}{$gin}=1;
					}
				}
			}
			$$newrp = join "",@rlist;
			$found=1;
			#if (check_valid($newrule,$p,%$gpatp)==1) {
			#	$found=1;
			#}	
		}
		
	}
	return $found;
}


sub add_wildpat(\%$) {
	my ($wp,$r) = @_;
	if ($r !~ /(.*)(-.-)(.*)/) {
		die "Error in add_wildpat\n";
	}
	$numleft=length $1;
	$numright=length $3;
	@rstr = split //,$r;
	foreach my $i (0..$numleft-1) {
		@tmpstr = @rstr;
		$tmpstr[$i]= ".";
		$tmprule = join "",@tmpstr;
		$wp->{$tmprule}{$rstr[$i]}=1;
	}
	foreach my $i ($numleft+3..$numleft+$numright+2) {
		@tmpstr = @rstr;
		$tmpstr[$i]= ".";
		$tmprule = join "",@tmpstr;
		$wp->{$tmprule}{$rstr[$i]}=1;
	}
}	
	
	
sub g_match_g(\%$$$) {
	my ($matchp,$pat,$gi,$gj) =@_;
	my $pati=$pat;
	my $patj=$pat;
	fix_rule_g(\$pati,$gi);
	fix_rule_g(\$patj,$gj);
	if ((!(exists $matchp->{$pati}))||(!(exists $matchp->{$patj}))) {
		return 0;
	}
	foreach my $pi (keys %{$matchp->{$pati}}) {
		if (!(exists $matchp->{$patj}{$pi})) {
			return -1;
		}
	}
	return 1;
}

	
sub g_distance(\%\@$$) {
	my ($matchp,$patlistp,$gi,$gj)=@_;
	my $pos=0;
	my $neg=0;
	foreach my $pat (@$patlistp) {
		my $gscore=g_match_g(%$matchp,$pat,$gi,$gj);
		if ($gscore>0) {
			$pos++;
		} elsif ($gscore<0) {
			$neg++;
		}
	}
	if (($pos+$neg)==0) {
		return 0;
	}
	my $gdist = ($pos-$neg)/($pos+$neg);
	return $gdist;
}


sub do_merge_gsets($$\%) {
	my ($s1,$s2,$glistp)=@_;
	foreach my $g (keys %{$glistp->{$s2}}) {
		$glistp->{$s1}{$g}=1;
		delete $glistp->{$s2}{$g};
	}
	delete $glistp->{$s2};
}
	
	
sub update_gsets(\%\%) {
	my ($patlistp,$glistp) = @_;
	# update graph sets in $glistp list according to distance wrt pats in $patlistp list
	# $glistp->{gsetindex}{gsetmember}
	# $patlistp->{wildpat}
	
	my $gthreshold=1;
	my @patlist=keys %{$patlistp};
	
	my %trackmerge=();
	foreach my $s1 (keys %$glistp) {
		my %tomerge=();
		next if exists $trackmerge{$s1};
		foreach my $s2 (keys %$glistp) {
			next if $s2<=$s1;
			my $gcnt=0;
			my $gtot=0;
			foreach my $gi (keys %{$glistp->{$s1}}) {
				foreach my $gj (keys %{$glistp->{$s2}}) {
					$gcnt+=g_distance(%rule,@patlist,$gi,$gj);
					$gtot++;
				}
			}
			if ($gtot !=0) {
				my $gscore = $gcnt/$gtot;
				if ($gscore >= $gthreshold) {
					$tomerge{$s2}=1;
				}
			}
		}
		foreach my $s2 (keys %tomerge) {
			my @g1=keys %{$glistp->{$s1}};
			my @g2=keys %{$glistp->{$s2}};
			print "Merge: [@g1] [@g2] [@patlist]\n";
			do_merge_gsets($s1,$s2,%$glistp);
			$trackmerge{$s2}=1;
		}
	}
}

sub show_sets_per_patnum($\%\%){
	my ($patnum,$patsetp,$gsetp)=@_;
	print "show_sets $patnum:\t";
	#foreach my $pat (keys %$patsetp) {
	#	print "$pat\t";
	#}
	foreach my $n (keys %$gsetp) {
		my @gset = keys %{$gsetp->{$n}};
		print "[@gset]\t";
	}
	print "\n";
}


sub show_all_sets(\%){
	my ($gsetp)=@_;
	print "show_all_sets";
	foreach my $patnum (keys %$gsetp) {
		print "$patnum:\t";
		foreach my $n (keys %{$gsetp->{$patnum}}) {
			my @gset = keys %{$gsetp->{$patnum}{$n}};
			print "[@gset]\t";
		}
		print "\n";
	}
}

sub find_rulegroups_after($){
	my ($pname) = shift @_;
	
	my %wildpats=();
	foreach my $r (keys %rule) {
		my $len = length $r;
		if ($len>3) {add_wildpat(%wildpats,$r);}
	}
	
	my %patsets=();
	my $patnum=0;
	foreach my $pat (keys %wildpats) {
		$patnum++;
		$patsets{$patnum}{$pat}=1;
		
	}
	
	my @graphs;
	read_graphs(@graphs);
	push @graphs,0;
	push @graphs," ";
	
	foreach my $patnum (keys %patsets) {
		foreach my $pat (keys %{$patsets{$patnum}}) {
			$gnum=0;
			foreach my $g (@graphs) {
				my $testpat = $pat;
				fix_rule_g(\$testpat,$g);
				if (exists ($rule{$testpat})) {
					$gnum++;
					$gsets{$patnum}{$gnum}{$g}=1;
				}
			}
		}
	}
		
	my $converged=0;
	while ($converged!=1) {
		foreach my $patnum (keys %patsets) {
			#next if ($patnum!=2349);
			update_gsets(%{$patsets{$patnum}},%{$gsets{$patnum}});
			show_sets_per_patnum($patnum,%{$patsets{$patnum}},%{$gsets{$patnum}});
		}
		#update_patsets;
		$converged=1;
	}
	show_all_sets(%gsets);
	#rewrite_rules();
}


sub find_rulegroups_before($$$){
	my ($pattsfile,$maxc,$gthreshold) = @_;
	my @graphs;
	read_graphs(@graphs);
	push @graphs,0;
	
	%inset=();
	%outset=();
	%confset=();
	
	my %realpats=();
	foreach my $g (@graphs) {
		my %gpatts=();
		if (-e "$pattsfile.$g") {
			fread_gpatts(%gpatts,"$pattsfile.$g");
			foreach my $p (keys %gpatts) {
				foreach my $pat (keys (%{$gpatts{$p}})) {
					next if (($pat eq 'words')||($pat eq 'total'));
					my $len=(length $pat)-2;
					$realpats{$len}{$pat}{$p}=1;
				}
			}
		}
	}
	
	my $csize=2;
	my $done=0;
	push @graphs," ";
	print "Using max context size [$maxc]\n";
	
	my %gscore=();
	foreach my $gi (@graphs) {
		foreach my $gj (@graphs) {
			$gscore{$gi}{$gj}{'pos'}=0;
			$gscore{$gi}{$gj}{'neg'}=0;
		}
	}
	while ($csize<=$maxc) {
		my %wildpats=();
		foreach my $pat (keys %{$realpats{$csize}}) {
			add_wildpat(%wildpats,$pat);
		}
		foreach my $pat (keys %wildpats) {
			my $pp=$wildpats{$pat};
			my %gdone=();
			foreach my $gi (keys %$pp) {
				$gdone{$gi}=1;
				foreach my $gj (keys %$pp) {
					next if exists $gdone{$gj};
					my $gcnt = g_match_g(%{$realpats{$csize}},$pat,$gi,$gj);
					if ($gcnt>0) {
						$gscore{$gi}{$gj}{'pos'}++;
					} elsif ($gcnt<0) {
						$gscore{$gi}{$gj}{'neg'}++;
					}
				}
			}
		}
		$csize++;
	}
	my %toprint=();
	foreach my $gi (keys %gscore) {
		foreach my $gj (keys %{$gscore{$gi}}) {
			my $num=$gscore{$gi}{$gj}{'pos'}-$gscore{$gi}{$gj}{'neg'};
			my $den=$gscore{$gi}{$gj}{'pos'}+$gscore{$gi}{$gj}{'neg'};
			my $gcnt=0;
			if ($den!=0) {$gcnt=$num/$den;}
			#if ($den>5) {
				$toprint{$gcnt}{$gi}{$gj}=1;
			#}
		}
	}
	foreach my $gcnt (sort {$b<=>$a} keys %toprint) {
		foreach my $gi (sort keys %{$toprint{$gcnt}}) {
			foreach my $gj (sort keys %{$toprint{$gcnt}{$gi}}) {
				print "[$gcnt] [$gi] [$gj] [$gscore{$gi}{$gj}{'pos'}] [$gscore{$gi}{$gj}{'neg'}]\n";
				#print "${gi}_$gj $gscore{$gi}{$gj}{'pos'} $gscore{$gi}{$gj}{'neg'}\n";
				if (($gcnt>$gthreshold)) {
					$rgroup{$gi}{$gj}=1;
					$rgroup{$gj}{$gi}=1;
				}
			}
		}
	}
	foreach my $gi (sort @graphs) {
		if ($gi eq " ") {$gi = "_";}
		$inset{$gi}{$gi}=1;
		foreach my $gj (sort keys %{$rgroup{$gi}}) {
			$inset{$gi}{$gj}=1;
		}
		@gi_set=sort keys %{$inset{$gi}};
		map s/ /_/, @gi_set;
		print "Set $gi: @gi_set\n";
	}
}

#--------------------------------------------------------------------------

sub fread_rulegroups($){
	my ($iname)=@_;
	open IH, "<:encoding(utf8)", "$iname" or die "Error opening $iname\n";
	%inset=();
	%outset=();
	%confset=();
	while (<IH>) {
		chomp;
		my @line=split /;/;
		$setnum=$line[0];
		if (!($line[1] eq "")) {
			foreach my $g (split / /,$line[1]) {
				if ($g eq " ") {$g = "_"}
				$inset{$setnum}{$g}=1;
			}
		}
		if ((exists $line[2])&&(!($line[2] eq ""))) {
			foreach my $g (split / /,$line[2]) {
				if ($g eq " ") {$g = "_"}
				$confset{$setnum}{$g}=1;
			}
		}
		if ((exists $line[3])&&(!($line[3] eq ""))) {
			foreach my $g (split / /,$line[2]) {
				if ($g eq " ") {$g = "_"}
				$outset{$setnum}{$g}=1;
			}
		}
	}
	close IH;
}


sub fwrite_rulegroups($){
	my ($oname)=@_;
	open OH, ">:encoding(utf8)", "$oname" or die "Error opening $oname\n";
	foreach my $setnum (sort keys %inset) {
		my @inlist = sort keys %{$inset{$setnum}};
		map s/ /_/g, @inlist;
		my @outlist = sort keys %{$outset{$setnum}};
		map s/ /_/g, @outlist;
		my @conflist = sort keys %{$confset{$setnum}};
		map s/ /_/g, @conflist;
		print OH "$setnum;@inlist;@conflist;@outlist\n";
	}
	close OH;
}


#--------------------------------------------------------------------------

sub find_rulepairs(\%$){
	my ($dictp,$oname)=@_;
	open OH, ">:encoding(utf8)", "$oname" or die "Error opening $oname\n";
	my %rulepairs;
	my %bigrams;
	foreach my $word (keys %$dictp) {
		my @rinfo=();
		my $sound="";
		g2p_word_info($word,\$sound,@rinfo);
		foreach my $i (0..($#rinfo-1)) {
			$bigrams{$rinfo[$i]}{$rule{$rinfo[$i+1]}}{$rinfo[$i+1]}++;
		}
	}

	foreach my $r1 (keys %bigrams) {
		my $valid=0;
		my ($r1l, $r1g, $r1r);
		my ($r2g, $p);
		my ($r1ml,$r1mr);
		
		$r1p = $bigrams{$r1};
		my @posp = keys %{$r1p};
		if ((scalar @posp) == 1) {
			$p=$posp[0];
			foreach my $r2 (keys %{$r1p->{$p}}) {
				if ($r1 !~ /^(.*)-(.)-(.*)$/) {
					die "Error matching $r1\n";
				}
				$r1l = $1;
				$r1g = $2;
				
				if ((length $3)>0) {$r1r=substr $3,0,1;}
				else {$r1r = "";}
				$r1ml = $r1l.$r1g.$r1r;
				$r1mr = $3;
				if ($r2 !~ /^(.*)-(.)-(.*)$/) {
					die "Error matching $r2\n";
				}
				$r2g = $2;
				my $r2l = "";
				if ((length $1)>0) {$r2l = substr $1,-1,1;}
				if ( ($r1g eq $r2l)&&($r1r eq $r2g)&&
				     (($r1g eq "0")||($r2g eq "0")||($rule{$r1} eq "0")||($rule{$r2} eq "0"))
				     ) {
					$valid=1;
				}
			}
			if ($valid==1) {
				foreach my $posrule (keys %{$context{$r2g}}) {
					if ($rule{$posrule} eq $p) {
						if ($posrule !~ /^(.*)-(.)-(.*)$/) {
							die "Error matching $posrule\n";
						}
						$posrml = $1.$2;
						$posrmr = $2.$3;
						
						if ( (($posrml =~ /$r1ml/)||($r1ml =~ /$posrml/)) &&
							(($posrmr =~ /$r1mr/)||($r1mr =~ /$posrmr/)) ) {
							$rulepairs{$r1}{$posrule}=1;
							print OH "$r1;$rule{$r1};$p;$posrule\n";
						}
					}
				}
			}		
		}
        }
	close OH;
}


sub fread_rulepairs($) {
	my ($rname)=shift @_;
	open IH, "<:encoding(utf8)", "$rname" or die "Error opening $rname\n";
	%rulepairs=();
	while (<IH>) {
		chomp;
		if (!(/^(.*);.;.;(.*)$/)) {
			die "Error reading rulepairs $rname\n";
		} else {
			$rulepairs{$1}{$2}=1;
		}
	}
	close IH;
}


#--------------------------------------------------------------------------
#NOT USED CURRENTLY
#--------------------------------------------------------------------------

sub g2p_word_shift($$\@){
	($word,$soundp,$infop) = @_;

	chomp $word;
	my $wordend = (length $word)-1;
	my $l = " "; 
	my $g = substr $word,0,1;
	my $r="";
	if ($wordend>0) {
		$r = (substr $word,1)." ";
	} 
	my @slist=();
	my @order=();
	my $wordstr = " ".$word." ";
	
	#print "WORD: $word\n";
	#foreach graph->phone
	foreach my $i (0 .. $wordend) {
		my $pat = $l."-".$g."-".$r;
		my $gi = $i+2;
		my $patend = (length $pat) - 1;
		print "[$i] Testing: [$pat]\n" if $debug;
		my $csize=$patend;
		my $numchange=0;
		my $addright=0;
		$right=0;
		#for contexts from largest down - while not found
		#remove from right side if $right==1
		my $bestp="";
		my $bestcnt=0;
		my $besttemp="";
		my $found=0;
		my $found_all=0;
		my $past_last=0;
		while (($csize>=1)&&($found_all==0)) {
			#find best match at this sized context
			my $found_pat=0;
			while (($found_pat==0)&&($csize>1)) {
				if ($addright==0){
					if ($found==1) {
						$found_all=1;
						$found_pat=1;
						$past_last=1;
					} else {
						$csize--;
						if ($csize==1) {
							$found_pat=1;
							$found_all=1;
						}
						$numchange=0;
						$addright = int ($csize/2);
						$addleft = $csize-$addright-1;
						if ($addleft==$addright) {
							$right=1;
						} else {
							$right=0;
						}
					}
				} else {
					if ($right==1) {
						$numchange++;
						$addright+= $numchange;
						$right=0;
					} else {
						$numchange++;
						$addright-= $numchange;
						$right=1;
					}
					$addleft = $csize - $addright - 1;
				}
				if (($addright+$gi<$patend)&&($addleft<$gi)) {
					#print "Possible match for $addleft,1,$addright\n";
					$found_pat=1;
				} else {
					#print "No match for $addleft,1,$addright\n";
				}
			}
			if ($past_last==0) {
				if ($found_pat==1) {
					$posrule = (substr($wordstr,$i+1-$addleft,$addleft)."-$g-".(substr($wordstr,$i+2,$addright)));
				} else {
						print "Warning: possible error in g2p_word_shift\n";
				}
			
				print "Testing: [$csize][$posrule]\n" if $debug;
				if (exists $rule{$posrule}) {
					#if ($found==0) {
							#print "First rule: [$posrule] [$rulecnt{$posrule}] [$rule{$posrule}]\n";
						#} else {
							#print "Alternative: [$posrule] [$rulecnt{$posrule}] [$rule{$posrule}]\n";
							#if (!($rule{$posrule} eq $bestp)) {
							#	print "Conflicting rules!!\n";
							#}
						#}
					if (($found!=1)||($rulecnt{$posrule}>$bestcnt)) {
						if ( ($use_rulepairs==0) ||
						     ( (($i==$wordend)||(valid_rulepair_next($posrule,$i,$wordstr)))
						       && (($i==0)||(valid_rulepair_previous($infop->[$i-1],$posrule))) )
						   ) {
							$found=1;
							$bestp=$rule{$posrule};
							$bestcnt=$rulecnt{$posrule};
							$bestrule=$posrule;
						} else {
							print "Not valid rulepair [$word] $posrule\n";
						}
					}
				}
			}
		}
		if ($found==1) {
			$slist[$i]=$bestp;
			$infop->[$i]=$bestrule;
			print "[$bestrule] -> $bestp\n" if $msg;
		} else {
			print "ERROR " if $debug;
			return -1;
		}
		$l = $l.$g; 
		$g = substr $r,0,1; 
		$r=substr $r,1; 
	}
	$$soundp=join "",@slist;
	#$$soundp =~ s/0//g;
	#$$soundp =~ s/ //g;
	print "<p>Result: $word -> [$$soundp]\n" if $debug;
	return 0;
}


sub g2p_word_bounce($$\@){
	($word,$soundp,$infop) = @_;
	chomp $word;
	my $wordend = (length $word)-1;
	my $l = " "; 
	my $g = substr $word,0,1; 
	my $r="";
	if ($wordend>0) {
		$r = (substr $word,1)." ";
	}
	my @slist=();
	my @order=();
	
	#foreach graph->phone
	foreach my $i (0 .. $wordend) {
		my $pat = $l."-".$g."-".$r;
		my $gi = $i+2;
		my $patend = (length $pat) - 1;
		my $found=0;
		my $csize=$patend-1;
		my $ri = $patend;
		my $li = 0;
		my $right;
		
		my $addright = $ri-$gi-1;
		my $addleft = $gi-$li-1;
		
		if ($addright>$addleft) {
			$right=1;
		} else {
			$right=0;
		}
		
		#for contexts from largest down - while not found
		while (($csize>=1)&&($found!=1)) {
			#find best match at this sized context
			print "Testing [$pat]\n" if $debug;
			if (exists $rule{$pat}) {
				$found=1;
				$slist[$i]=$rule{$pat};
				$infop->[$i]=$pat;
				print "[$pat] -> $slist[$i]\n" if $debug;
				last;
			} else {
				my $cfound=0;
				while (($cfound==0)&&($csize>=1)) {
					if ($right==1) {
						if ($ri >= $gi+2) {
							$csize--;
							$pat = substr ($pat,0,$csize+2);
							$ri--;
							$addright--;
							if ($addright>$addleft) { 
								$right=1;
							} else {
								$right=0;
							}
							$cfound=1;
						}
					} elsif ($right==0) {
						if ($li <= $gi-2) {
							$pat = substr ($pat,1);
							$li++;
							$csize--;
							$addleft--;
							if ($addright>$addleft) { 
								$right=1;
							} else {
								$right=0;
							}
							$cfound=1;
						}
					}
				}
			}
		}
		if (!$found) {
			print "ERROR ";
			return -1;
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


#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

