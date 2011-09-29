package g2pMain;

#--------------------------------------------------------------------------

use g2pFiles;
#use g2pArchive;
use g2pDict;
use g2pAlign;
use g2pRules;
use g2pOlist;
#use g2pDec;
#use g2pSound;
#use g2pShow;
use g2pExp;
use g2pRulesHelper;
use g2pVariants;

#--------------------------------------------------------------------------

BEGIN {
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&do_align &do_patts &do_rules &do_dict &do_test &do_prep_set_new &do_prep_set_copy &do_train_set &do_train_set_prealigned &do_test_set &do_result_set &do_test_set_per_n &do_test_var_set &do_full_run_prealigned &do_full_run_new_std &get_align);
}

#--------------------------------------------------------------------------

sub do_align($$$) {
	my ($indict,$outdict,$outnulls)=@_; 
	print "Aligning dictionary\n";
	print "In:\t $indict\n";
	print "Out:\t $outdict\n";
	falign_dict $indict,$outdict,$outnulls,0;
}

sub do_patts($$) {
	my ($indict,$outpatts)=@_; 
	print "Extracting patterns\n";
	print "In:\t $indict\n";
	print "Out:\t $outpatts.*\n";
	system "rm $outpatts.*";
	$rtype="olist";
	my %agd=();
	my %apd=();
	fread_align($indict,%agd,%apd);
	extract_patterns_olist(%agd,%apd,$outpatts);
}

sub do_rules($$$) {
	my ($inpatts,$graphs,$outrules)=@_; 
	print "Extracting rules\n";
	print "In:\t $inpatts.*;\n";
	print "In:\t $graphs\n";
	print "Out:\t $outrules\n";
	
	if ( -e "$outrules" ) {
		system "rm $outrules";
	}
	open RH, ">$outrules" or die "Error opening $outrules";

	$rtype="olist";
	open GH, "$graphs" or die "Error opening $graphs";
	while (my $g=<GH>) {
		chomp $g;
		#%rule=();
		#%rorder=();
		#%numfound=();
		#system("./g2popt extract $g $inpatts.$g $outrules.$g");
		system("time ./g2popt extract $g $inpatts.$g $outrules.$g -u 2 2 current/groups");  	#fix later
		#fgen_rulegroups_single_large($g,"$inpatts.$g","$outrules.$g");
		#fwrite_rules_olist("$outrules.$g");
		open TH, "$outrules.$g";
		while (<TH>) {
			chomp;
			print RH "$_\n";
		}
		close TH;
	}
	close GH;
	#%rule=();
	#%rorder=();
	#%numfound=();
	#fgen_rulegroups_single_large("0","$inpatts.0","$outrules.0");
	#fwrite_rules_olist("$outrules.0");
	#open TH, "$outrules.0";
	#while (<TH>) {
	#	chomp;
	#	print RH "$_\n";
	#}
	#close TH;
	close RH;
}


sub do_dict($$$$) {
	my ($inwords,$inrules,$ingnulls,$outdict)=@_; 
	print "Generating dictionary\n";
	print "In:\t $inwords\n";
	print "In:\t $inrules\n";
	print "In:\t $ingnulls\n";
	print "Out:\t $outdict\n";

	#$rtype = "olist";
	#my (%gnulls,%dict,%stat);
	#fread_rules_olist($inrules);
	#fread_gnull_list($ingnulls,%gnulls);
	#g2p_wordlist("$inwords",%gnulls,%dict,%stat);
	#fwrite_dict("$outdict",%dict,%stat);
	#system ("time ./g2popt predict_file $inwords $inrules $outdict -f semicolon -g $ingnulls -u current/groups"); #fix later
	system ("time ./g2popt predict_file $inwords $inrules $outdict -f semicolon -g $ingnulls"); #fix later
}


sub do_test($$$$$) {
	my ($inrules,$indict,$ingnulls,$inphones,$outresult)=@_; 
	print "Testing rules\n";
	print "In:\t $inrules\n";
	print "In:\t $indict\n";
	print "Out:\t $outresult\n";

	fwlist_fromdict 1000000,0,$indict,"$indict.words";
	do_dict "$indict.words",$inrules,$ingnulls,"$indict.tested";
	fcmp_phoneAcc $indict,"$indict.tested",$inphones,$outresult;
	system "cat $outresult";
}

#--------------------------------------------------------------------------

sub get_align($$$){
	my ($inwords,$indict,$outdict) = @_;
	my @words=();
	my %agd=();
	my %apd=();
	fread_words($inwords,@words);
	fread_align($indict,%agd,%apd);
	my %new_agd=(); 
	my %new_apd=(); 
	my %new_dict=();
	foreach my $word (@words) {
		if (!(exists $agd{$word})) {
			print "Warning: $word not in aligned dictionary\n";
		#} elsif ($dictType==$doubleType{'pos_one'}) {
		#	foreach my $f (keys %{$agd{$word}}) {
		#		$new_dict{$word}{$f} = 1;
		#		@{$new_agd{$word}{$f}} = @{$agd{$word}{$f}};
		#		@{$new_apd{$word}{$f}} = @{$apd{$word}{$f}};
		#	}
		} else {
			$new_dict{$word} = 1;
			@{$new_agd{$word}} = @{$agd{$word}};
			@{$new_apd{$word}} = @{$apd{$word}};
			my $i=1;
			my $nextvar="${word}_$i";
			while (exists $agd{$nextvar}) {
				$new_dict{$nextvar} = 1;
				@{$new_agd{$nextvar}} = @{$agd{$nextvar}};
				@{$new_apd{$nextvar}} = @{$apd{$nextvar}};
				$i++;
				$nextvar="${word}_$i";
			}
		}
	}
	fwrite_align($outdict,%new_dict,%new_agd,%new_apd);
}

sub train_one($$$$$$$$$$$) {
	my ($copy_or_new,$start_from,$etype,$dictid,$wordsid,$ingraphs,$inphon,$p,$nprev,$n,$rulesid)=@_;
	my $ndiff= $n-$nprev;
	print "Training one set: $etype\n";
	print "In:\t from,to,diff = $nprev,$n,$ndiff\n";
	print "In:\t $dictid.$p.$nprev\n";
	print "In:\t $wordsid.$p.$nprev\n";
	print "In:\t $ingraphs,$inphon\n";
	print "Out:\t $dictid.$p.$n\n";
	print "Out:\t $wordsid.$p.$n\n";
	print "Out:\t $rulesid.$p.$n\n";

	if (($copy_or_new eq "copy")&&($start_from eq "patts")) {
		do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
	} else {
		
		fwlist_frommaster "$wordsid.$p","$dictid.$p.$nprev",$ndiff,"evenUncertain","$wordsid.$p.tmp";
		system "cat $wordsid.$p.tmp $wordsid.$p.$nprev > $wordsid.$p.$n";
		system "rm $wordsid.$p.tmp";		
		fdict_subset "$wordsid.$p.$n","$dictid.$p","$dictid.$p.$n";
		
		if ($etype eq "std") {
			
		} elsif ($etype eq "variants") {
			#Now rewrite variants - training set only!
			system "cp $dictid.$p.$n $dictid.orig.$p.$n";
			do_combine "$dictid.$p.$n",$inphon,"$dictid.rewrite.$p.$n";
			do_calc_restrict "$dictid.rewrite.$p.$n.map","$dictid.$p.$n","$dictid.rewrite.$p.$n.dict","$dictid.rewrite.$p.$n.restrict";
			system "mv $dictid.rewrite.$p.$n.dict $dictid.$p.$n";
			system "cp $inphon $inphon.orig";
			system "cat $inphon.orig $dictid.rewrite.$p.$n.phones | sort -u > $inphon";
		} else {
			die "Unknown $etype\n";
		}

		do_align "$dictid.$p.$n","$dictid.aligned.$p.$n","$dictid.gnulls.$p.$n";
		do_patts "$dictid.aligned.$p.$n","$dictid.patts.$p.$n";
		do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
	}
}

sub train_one_prealigned($$$$$$$$$$$$$) {
	my ($copy_or_new,$start_from,$etype,$adict,$gnulls,$dictid,$wordsid,$ingraphs,$inphon,$p,$nprev,$n,$rulesid)=@_;
	my $ndiff= $n-$nprev;
	print "Training one set (pre-aligned): $etype\n";
	print "In:\t $adict\n";
	print "In:\t $gnulls\n";
	print "In:\t from,to,diff = $nprev,$n,$ndiff\n";
	print "In:\t $dictid.$p.$nprev\n";
	print "In:\t $wordsid.$p.$nprev\n";
	print "Out:\t $dictid.$p.$n\n";
	print "Out:\t $wordsid.$p.$n\n";
	print "Out:\t $rulesid.$p.$n\n";

	if (($copy_or_new eq "copy")&&($start_from eq "patts")) {
		do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
		
	} elsif (($copy_or_new eq "copy")&&($start_from eq "aligned_and_words")) {
		
		if ($etype eq "std") {
			#Or should be $adict only if global aligned dict
			get_align "$wordsid.$p.$n","$adict.$p","$dictid.aligned.$p.$n";
			system "cp $gnulls.$p $dictid.gnulls.$p.$n";	
			do_patts "$dictid.aligned.$p.$n","$dictid.patts.$p.$n";
			do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
		} elsif ($etype eq "variants") {
			#Now rewrite variants - training set only!
			get_align "$wordsid.$p.$n","$adict.$p","$dictid.aligned.$p.$n.orig";
			fdict_subset "$wordsid.$p.$n","$dictid.$p","$dictid.$p.$n";
			system "cp $dictid.$p.$n $dictid.$p.$n.orig";
			system "cp $inphon $inphon.orig";
			do_combine "$dictid.$p.$n",$inphon,"$dictid.rewrite.$p.$n";
			do_calc_restrict "$dictid.rewrite.$p.$n.map","$dictid.$p.$n","$dictid.rewrite.$p.$n.dict","$dictid.rewrite.$p.$n.restrict";
			system "mv $dictid.rewrite.$p.$n.dict $dictid.$p.$n";
			system "cat $inphon.orig $dictid.rewrite.$p.$n.phones | sort -u > $inphon";
			system "cp $gnulls $dictid.gnulls.$p.$n";
			
			do_patts "$dictid.aligned.$p.$n","$dictid.patts.$p.$n";
			do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
		}
		
	} elsif (($copy_or_new eq "copy")&&($start_from eq "words")) {

		if ($etype eq "std") {
			get_align "$wordsid.$p.$n","$adict","$dictid.aligned.$p.$n";
			system "cp $gnulls $dictid.gnulls.$p.$n";	
			do_patts "$dictid.aligned.$p.$n","$dictid.patts.$p.$n";
			do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
			
		} elsif ($etype eq "variants") {
			#Now rewrite variants - training set only!
			get_align "$wordsid.$p.$n","$adict","$dictid.aligned.$p.$n.orig";
			fdict_subset "$wordsid.$p.$n","$dictid","$dictid.$p.$n";
			system "cp $dictid.$p.$n $dictid.$p.$n.orig";
			system "cp $inphon $inphon.orig";
			do_combine "$dictid.aligned.$p.$n.orig",$inphon,"$dictid.rewrite.$p.$n";
			
			#do_calc_restrict "$dictid.rewrite.$p.$n.map","$dictid.$p.$n","$dictid.rewrite.$p.$n.dict","$dictid.rewrite.$p.$n.restrict";
			#do_separate "$dictid.$p.$n","$dictid.rewrite.$p.$n.map","$dictid.rewrite.$p.$n.restrict","$dictid.$p.$n.regen";
						
			system "mv $dictid.rewrite.$p.$n.dict $dictid.$p.$n";
			system "mv $dictid.rewrite.$p.$n.aligned $dictid.aligned.$p.$n";
			system "cat $inphon.orig $dictid.rewrite.$p.$n.phones | sort -u > $inphon";
			system "cp $gnulls $dictid.gnulls.$p.$n";
			
			do_patts "$dictid.aligned.$p.$n","$dictid.patts.$p.$n";
			do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
			system "cp $inphon $inphon.$p.$n";;
			system "cp $inphon.orig $inphon";
			
		} else {
			die "Unknown value [$etype] for variiable etype\n";
		}
		
	} else {
		if ($etype eq "std") {
			fwlist_frommaster "$wordsid.$p","$dictid.$p.$nprev",$ndiff,"evenUncertain","$wordsid.$p.tmp";
			system "cat $wordsid.$p.tmp $wordsid.$p.$nprev > $wordsid.$p.$n";
			system "rm $wordsid.$p.tmp";	
			fdict_subset "$wordsid.$p.$n","$dictid.$p","$dictid.$p.$n";
			get_align "$wordsid.$p.$n",$adict,"$dictid.aligned.$p.$n";
			system "cp $gnulls $dictid.gnulls.$p.$n";	
			do_patts "$dictid.aligned.$p.$n","$dictid.patts.$p.$n";
			do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
		} elsif ($etype eq "variants") {
			
		} else {
			die "Unknown value [$etype] for variiable etype\n";
		}
	}
}

sub train_one_new_std($$$$$$$$) {
	my ($dictid,$wordsid,$ingraphs,$inphon,$p,$nprev,$n,$rulesid)=@_;
	my $ndiff= $n-$nprev;
	print "In:\t from,to,diff = $nprev,$n,$ndiff\n";
	print "In:\t $dictid.$p.$nprev\n";
	print "In:\t $wordsid.$p.$nprev\n";
	print "In:\t $ingraphs,$inphon\n";
	print "Out:\t $dictid.$p.$n\n";
	print "Out:\t $wordsid.$p.$n\n";
	print "Out:\t $rulesid.$p.$n\n";

	fwlist_frommaster "$wordsid.$p","$dictid.$p.$nprev",$ndiff,"evenUncertain","$wordsid.$p.tmp";
	system "cat $wordsid.$p.tmp $wordsid.$p.$nprev > $wordsid.$p.$n";
	system "rm $wordsid.$p.tmp";		
	fdict_subset "$wordsid.$p.$n","$dictid.$p","$dictid.$p.$n";
		
	do_align "$dictid.$p.$n","$dictid.aligned.$p.$n","$dictid.gnulls.$p.$n";
	do_patts "$dictid.aligned.$p.$n","$dictid.patts.$p.$n";
	do_rules "$dictid.patts.$p.$n",$ingraphs,"$rulesid.$p.$n";
}

#--------------------------------------------------------------------------

sub do_prep_set_new($$$$) {
	my ($fulldict,$crossval,$outdict,$outwords)=@_;
	print "Split training data\n";
	print "In:\t $fulldict\n";
	print "In:\t Cross-validation value = $crossval\n";
	print "Out:\t $outdict.*\n";
	print "Out:\t $outwords.*\n";

	split_parts $fulldict,$crossval,"$fulldict.split";
	combine_parts "$fulldict.split",$crossval,$outdict;
	foreach $p (1..$crossval) {
		fwlist_fromdict 1000000,0,"$outdict.train.$p","$outwords.train.$p";
		fwlist_fromdict 1000000,0,"$outdict.test.$p","$outwords.test.$p";
	}
	system "rm $fulldict.split.*";
	system "wc $fulldict $outwords.*";
}	


sub link_if_exists($$) {
	my ($iname,$oname)=@_;
	if (-e $iname) {
		system "ln -sfv $iname $oname";					
	} else {
		#die "Error: $iname does not exist\n";
		print "Error: $iname does not exist\n";
		system "touch $oname";
	}
}

sub do_prep_set_copy($$$$$$$$\@\@$$$$$$) {
	my ($start_from,$intrainpatts,$intraindict,$intrainwords,$ingnulls,$intestdict,$intestwords,$graphfn,$plistp,$nlistp,$outtrainpatts,$outtraindict,$outtrainwords,$outgnulls,$outtestdict,$outtestwords)=@_;
	print "Linking data\n";
	print "In:\t $intrainpatts.*\n";
	print "In:\t $intraindict.*\n";
	print "In:\t $intestdict.*\n";
	print "In:\t $intestwords.*\n";
	print "In:\t Cross-validation values = @$plistp; @$nlistp\n";
	print "Out:\t $outtrainpatts.*\n";
	print "Out:\t $outtraindict.*\n";
	print "Out:\t $outtestdict.*\n";
	print "Out:\t $outtestwords.*\n";

	if ($start_from eq "patts") {
		foreach my $p (@$plistp) {
			link_if_exists "$intestdict.$p","$outtestdict.$p";
			link_if_exists "$intestwords.$p","$outtestwords.$p";
			#link_if_exists "$intraindict.$p","$outtraindict.$p";
			fread_array(@graphs,$graphfn);
			foreach my $n (@$nlistp) {
				#link_if_exists "$ingnulls.$p.$n", "$outgnulls.$p.$n";					
				foreach my $g (@graphs) {
					link_if_exists "$intrainpatts.$p.$n.$g","$outtrainpatts.$p.$n.$g";
				}
			}
		}
	} elsif ($start_from eq "aligned_and_words") {
		foreach my $p (@$plistp) {
			link_if_exists "$intestdict.$p","$outtestdict.$p";
			link_if_exists "$intestwords.$p","$outtestwords.$p";
			link_if_exists "$intraindict.$p","$outtraindict.$p";
			link_if_exists "$intrainwords.$p","$outtrainwords.$p";
			foreach my $n (@$nlistp) {
				link_if_exists "$intraindict.$p.$n","$outtraindict.$p.$n";
				link_if_exists "$intrainwords.$p.$n","$outtrainwords.$p.$n";
			}
			link_if_exists "$intraindict.$p.aligned","$outtraindict.aligned.$p";
			link_if_exists "$intraindict.$p.gnulls","$outtraindict.gnulls.$p";
		}
	} elsif ($start_from eq "words") {
		foreach my $p (@$plistp) {
			link_if_exists "$intestwords.$p","$outtestwords.$p";
			foreach my $n (@$nlistp) {
				link_if_exists "$intrainwords.$p.$n","$outtrainwords.$p.$n";
			}
		}
	} else {
		die "Unknown value [$start_from] for variable start_from\n";
	}
}	


sub do_train_set($$$$$$$\@\@$) {
	my ($copy_or_new,$start_from,$etype,$dictid,$wordsid,$ingraphs,$inphon,$plistp,$nlistp,$rulesid)=@_;
	foreach my $p (@$plistp) {
		my $nprev=0;
		system "touch $dictid.$p.0";
		system "touch $wordsid.$p.0";
		foreach my $n (@$nlistp) { 
			train_one $copy_or_new,$start_from,$etype,$dictid,$wordsid,$ingraphs,$inphon,$p,$nprev,$n,$rulesid;
			$nprev=$n;
		}
	}
}

sub do_train_set_prealigned($$$$$$$$$\@\@$) {
	my ($copy_or_new,$start_from,$etype,$adict,$gnulls,$dictid,$wordsid,$ingraphs,$inphon,$plistp,$nlistp,$rulesid)=@_;
	foreach my $p (@$plistp) { 
		my $nprev=0;
		system "touch $dictid.$p.0";
		system "touch $wordsid.$p.0";
		foreach my $n (@$nlistp) { 
			train_one_prealigned $copy_or_new,$start_from,$etype,$adict,$gnulls,$dictid,$wordsid,$ingraphs,$inphon,$p,$nprev,$n,$rulesid;
			$nprev=$n;
		}
	}
}

sub do_test_set($$$$\@\@$) {
	my ($rulesid,$dictid,$gnullsid,$phones,$plistp,$nlistp,$resultid)=@_;
	my $nprev=0;
	foreach my $p (@$plistp) { 
		foreach my $n (@$nlistp) { 
			#do_test "$rulesid.$p.$n","$dictid.$p","$gnullsid.$p.$n",$phones,"$resultid.$p.$n";
			do_test "$rulesid.$p.$n","$dictid.$p","$gnullsid",$phones,"$resultid.$p.$n";
			$nprev=$n;
		}
	}
}

sub do_test_var_set($$$$$$\@\@$) {
	my ($wordsid,$rulesid,$dictid,$rewriteid,$gnullsid,$phonesid,$plistp,$nlistp,$resultid)=@_;
	foreach my $p (@$plistp) { 
		foreach my $n (@$nlistp) { 
			do_dict "$wordsid.$p","$rulesid.$p.$n","$gnullsid.$p.$n","$dictid.$p.$n.tested";
			do_separate "$dictid.$p.$n.tested","$rewriteid.$p.$n.map","$rewriteid.$p.$n.restrict","$dictid.$p.$n.expanded";	
			do_compare "$dictid.$p.$n.expanded","$dictid.$p","$resultid.$p.$n";
						
			#fcmp_phoneAcc "$dictid.$p.$n.expanded","$dictid.$p","$phonesid.$p.$n","$resultid.$p.$n";
			#system "cat $resultid.$p.$n";		
		}
	}
}

sub do_test_set_per_n($$$$\@\@$) {
	my ($rulesid,$dictid,$gnullsid,$phones,$plistp,$nlistp,$resultid)=@_;
	foreach my $p (@$plistp) { 
		foreach my $n (@$nlistp) { 
			do_test "$rulesid.$p.$n","$dictid.$p.$n","$gnullsid.$p.$n",$phones,"$resultid.$p.$n";
		}
	}
}


#--------------------------------------------------------------------------

sub do_full_run_new_std($$$$$$\@\@$$) {
	my ($traindictid,$trainwordsid,$testdictid,$testwordsid,$ingraphs,$inphon,$plistp,$nlistp,$rulesid,$resultid)=@_;
	foreach my $p (@$plistp) { 
		my $nprev=0;
		system "touch $traindictid.$p.0";
		system "touch $trainwordsid.$p.0";
		foreach my $n (@$nlistp) { 
			#train
			train_one_new_std $traindictid,$trainwordsid,$ingraphs,$inphon,$p,$nprev,$n,$rulesid;
			#test
			do_dict "$testwordsid.$p","$rulesid.$p.$n","$traindictid.gnulls.$p.$n","$testdictid.$p.$n.tested";
			fcmp_phoneAcc "$testdictid.$p","$testdictid.$p.$n.tested",$inphon,"$resultid.$p.$n";
			system "cat $resultid.$p.$n";
			$nprev=$n;
		}
	}
}

sub do_full_run_prealigned($$$$$$$$$$$\@\@$$) {
	my ($copy_or_new,$start_from,$etype,$adict,$gnulls,$traindictid,$trainwordsid,$testdictid,$testwordsid,$ingraphs,$inphon,$plistp,$nlistp,$rulesid,$resultid)=@_;
	foreach my $p (@$plistp) { 
		my $nprev=0;
		system "touch $traindictid.$p.0";
		system "touch $trainwordsid.$p.0";
		foreach my $n (@$nlistp) { 
			#train
			train_one_prealigned $copy_or_new,$start_from,$etype,$adict,$gnulls,$traindictid,$trainwordsid,$ingraphs,$inphon,$p,$nprev,$n,$rulesid;
			#test
			if ($etype eq 'std') {
				do_dict "$testwordsid.$p","$rulesid.$p.$n","$gnulls","$testdictid.$p.$n.tested";
				fcmp_phoneAcc "$testdictid.$p","$testdictid.$p.$n.tested",$inphon,"$resultid.$p.$n";
				system "cat $resultid.$p.$n";
			} else {
				die "Error: not yet implemented!\n";
				#do_separate "$dictid.$p.$n.tested","$rewriteid.$p.$n.map","$rewriteid.$p.$n.restrict","$dictid.$p.$n.expanded";	
				#do_compare "$dictid.$p.$n.expanded","$dictid.$p","$resultid.$p.$n";
			}
			$nprev=$n;
		}
	}
}

#--------------------------------------------------------------------------

sub append_results ($$$) {
	my ($inresult,$n,$outresult)=@_;
	open IH, $inresult or die "Error opening $inresult";
	my ($graphacc,$graphcor,$wordacc);
	while (<IH>) {
		chomp;
		if (/WORD/) {
			$graphacc= $_;
			$graphcor= $_;
			$graphacc =~  s/^.*Corr=.*, Acc=(.*) \[H.*$/$1/;
			$graphcor =~  s/^.*Corr=(.*), Acc=(.*) \[H.*$/$1/;
		} elsif (/SENT/) {
			$wordacc= $_;
			$wordacc =~ s/^.*Correct=(.*) \[H=.*$/$1/;
		}
	}
	close IH;
	
	open OH, ">>$outresult" or die "Error opening $outresult\n";
	print OH "$n $graphcor $graphacc $wordacc\n";
	close OH;
}

sub do_result_set ($\@\@$){
	my ($resultid,$plistp,$nlistp,$outresult)=@_;
	foreach my $p (@$plistp) {
		open OH, ">$resultid.$p" or die "Error opening $resultid.$p";
		foreach my $n (@$nlistp) {
			append_results "$resultid.$p.$n",$n,"$resultid.$p";
		}
		print "$resultid.$p\n";
		system "cat $resultid.$p";
	}
	my $plist = join ";",@$plistp;
	combine_results $resultid,$plist,$outresult;
	system "cat $outresult";
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

