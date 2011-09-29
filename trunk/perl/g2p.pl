#!/usr/bin/perl
# -w
# -d:DProf

#--------------------------------------------------------------------------
use g2pFiles;
use g2pArchive;
use g2pDict;
use g2pAlign;
use g2pRules;
use g2pOlist;
use g2pDec;
use g2pSound;
use g2pShow;
use g2pExp;
#use g2pTrees;
use Time::Local;
use g2pRulesHelper;
use g2pGroups;

#--------------------------------------------------------------------------

sub cl_g2p ($$$) {
	my ($word,$rf,$gf) = @_;
	my $sound = "";
	fread_gnull_list($gf,%gnulls);
	my $newword=add_gnull_word($word,%gnulls);
	if ($rtype eq "olist") {
		fread_rules_olist($rf);
	} else {
		fread_rules($rf);
	}
	g2p_word($newword,\$sound);
	#print "$word ($newword) -> $sound\n";
	print "$sound\n";
}

sub cl_g2p_rtype ($$$$) {
	$rtype = $_[3];
	cl_g2p($_[0],$_[1],$_[2]);
}


sub cl_g2p_info ($$$$) {
	my ($word,$rf,$gf,$rt) = @_;
	$rtype=$rt;
	my $sound = "";
	fread_gnull_list($gf,%gnulls);
	my $newword=add_gnull_word($word,%gnulls);
	if ($rtype eq "olist") {
		fread_rules_olist($rf);
	} else {
		fread_rules($rf);
	}
	my @info=();
	g2p_word_info($newword,\$sound,@info);
	foreach my $i (@info) {
		print "$i;$rule{$i};$rulecnt{$i};$numfound{$i}\n";
	}
}

sub cl_g2p_file ($$$$) {
	my ($wf,$rf,$gf,$df) = @_;
	print "Generating pronunciations:\nWord file:\t$wf\n";
	print "Rules file:\t$rf\nGnulls file:\t$gf\nDict file:\t$df\n";
	my (%gnulls,%dict,%stat);
	if ($rtype eq "olist") {
		fread_rules_olist($rf);
	} else {
		fread_rules($rf);
	}
	fread_gnull_list($gf,%gnulls);
	g2p_wordlist($wf,%gnulls,%dict,%stat);
	fwrite_dict($df,%dict,%stat);
}

sub cl_g2p_file_rtype ($$$$$) {
	$rtype = $_[4];
	cl_g2p_file($_[0],$_[1],$_[2],$_[3]);
}

sub cl_g2p_file_rtype_nulls ($$$$$) {
	$rtype = $_[4];
	fg2p_wordlist_align($_[0],$_[1],$_[2],$_[3]);
}

sub cl_find_rulepairs ($$$$) {
	my ($rf,$df,$gf,$of)=@_;
	my %dict=();
	my %stat=();
	my %gnulls=();
	my $keep = $use_rulepairs;
	$use_rulepairs=0;
	fread_rules($rf);
	fread_gnull_list($gf,%gnulls);
	fread_dict($df,%dict,%stat);
	add_gnull_list(%dict,%gnulls);
	find_rulepairs(%dict,$of);
	$use_rulepairs=$keep;
}

sub cl_conv_rules_olist ($$) {
	my ($irf,$orf)=@_;
	fread_rules($irf);
	conv_rules_olist;
	fwrite_rules_olist($orf);
}

sub cl_restrict_rules ($$$$) {
	my ($irf,$numseen,$cutoff,$orf)=@_;
	read_graphs(@graphs);
	push @graphs,0;
	if ( -e $orf) {
		system ("rm -v $orf"); 
	}
	foreach my $g (sort @graphs) {
		 if (-e "$irf.$g") {
			fread_rules_olist("$irf.$g");
			restrict_rules($g,$numseen,$cutoff);
			fwrite_rules_olist("$orf.$g");
			 system ("cat $orf.$g >> $orf");
		}
	}
	print "Created $orf\n";
}


sub cl_id_pos_errorwords ($$$$$) {
	my ($singlesfn,$netcnt,$actcnt,$cutoff,$errfn)=@_;
	print "Identifying words creating errors:\nSingles file:\t$sf\n";
	print "count if less than (net move):\t$netcnt\ncount if less than (matching words):\t$actcnt\ncutoff (num of single rules):\t\t$cutoff\n";
	print "Error list:\t$errfn\n";

	my %errors=();
	id_pos_errors($singlesfn,$netcnt,$actcnt,$cutoff,%errors);
	
	my @errlist = sort keys %errors;
	map s/0//g, @errlist;
	fwrite_words($errfn,@errlist);
}	

sub cl_id_pos_errors ($$$$$$$) {
	my ($rf,$sf,$netcnt,$actcnt,$cutoff,$errf,$newrf)=@_;
	print "Identifying errors:\nRules file:\t$rf\nSingles file:\t$sf\n";
	print "count if (net):\t$netcnt\ncount if (act):\t$actcnt\ncutoff:\t\t$cutoff\n";
	print "Error list:\t$errf\nNew rules:\t$newrf\n";

	fread_rules_olist($rf);
	my %errors=();
	id_pos_errors($sf,$netcnt,$actcnt,$cutoff,%errors);
	
	my @errlist = sort keys %errors;
	fwrite_words($errf,@errlist);
	
	foreach my $w (@errlist) {
		foreach my $r (keys %{$errors{$w}}) {
			if (exists $rule{$r}) {
				my $i = $rulecnt{$r};
				if ($i>0) {
					print "Deleting rule $r\n";
					$r =~ /.*-(.)-.*/;
					my $g = $1;
					delete $rule{$r};
					delete $rulecnt{$r};
					delete $numfound{$r};
					$rorder{$g}[$i]=-1;
				}
			}
		}
	}
	fwrite_rules_olist($newrf);
}

sub cl_find_rulegroups_before ($$$$$) {
	my ($df,$clrt,$csize,$threshold,$of)=@_;
	print "Generating rule groups before rules extracted\n";
	print "Ruletype:\t$clrt\nMaximum context:\t$csize\nThreshold:\t$threshold\n";
	$rtype=$clrt;
	print "Assumes $df.patts.$rtype files exist\n";
	my $keep = $use_rulepairs;
	$use_rulepairs=0;
	find_rulegroups_before("$df.patts.$rtype",$csize,$threshold);
	fwrite_rulegroups($of);
	$use_rulepairs=$keep;
}


sub cl_find_rulegroups_after ($$$$) {
	my ($rf,$df,$clrt,$of)=@_;
	print "Generating rule groups after rules have been extracted\n";
	print "rtype=$clrt\n";
	$rtype=$clrt;
	print "Assumes $df.patts.$rtype files exist\n";
	my $keep = $use_rulepairs;
	$use_rulepairs=0;
	fread_rules($rf);
	find_rulegroups_after("$df.patts.$rtype");
	fwrite_rules($of);
	fwrite_rulegroups("$of.rulegroups");
	$use_rulepairs=$keep;
}


sub cl_do_rulegroups($$$$){
	my ($df,$rf,$pre,$newrtype) = @_;
	$rtype = $newrtype;
	print "Generating rule set - using groups:\n";
	print "Dict file:\t$df\nPre_aligned:\t$pre\nType:\t\t$rtype\nRules file:\t$rf\n";
	my %g2ptypes=("bounce"=>1,"olist"=>1);
	
	if (exists $g2ptypes{$rtype}) {
		fgen_rulegroups($df,$pre,"$df.aligned","$df.gnulls");
	} else {
		die "Unknown rule type $rtype";
	}
	fwrite_rules_olist($rf);
	fwrite_rulegroups("$rf.rulegroups");
	$t = gmtime();
	print "TIME\trules written:\t\t$t\n";
}

sub cl_find_rulegroups_single ($$$$) {
	my ($g,$pattsf,$newrtype,$rf) = @_;
	print "Generating rule set for single g:\n";
	print "g:\t$g\nPattsfile:\t$pattsf\nType:\t\t$newrtype\nRules file:\t$rf\n";
	my %g2ptypes=("olist"=>1);
	$rtype=$newrtype;
	if (exists $g2ptypes{$rtype}) {
		fgen_rulegroups_single($g,$pattsf);
	}
	fwrite_rules_olist($rf);
	$t = gmtime();
	print "TIME\trules written [$g]:\t\t$t\n";
}

sub cl_find_rulegroups_single_large ($$$$) {
	my ($g,$pattsf,$newrtype,$rf) = @_;
	print "Generating rule set for single g:\n";
	print "g:\t$g\nPattsfile:\t$pattsf\nType:\t\t$newrtype\nRules file:\t$rf\n";
	my %g2ptypes=("olist"=>1);
	$rtype=$newrtype;
	if (exists $g2ptypes{$rtype}) {
		fgen_rulegroups_single_large($g,$pattsf,$rf);
		fwrite_rules_olist($rf);
	}
	$t = gmtime();
	print "TIME\trules written [$g]:\t\t$t\n";
}

sub cl_olist_add_word ($$$$) {
	my ($word,$prev_rules_prefix,$patts_prefix,$new_rules_prefix) = @_;
	olist_add_word($word,$prev_rules_prefix,$patts_prefix,$new_rules_prefix);
}

sub cl_olist_add_upto_sync ($$$$$$$$$$$) {
	my ($prev_dict,$prev_rules_prefix,$prev_patts_prefix,$sync,$use_align,$new_dict,$new_rules_prefix,$new_patts_prefix,$used_dict,$adict,$gnulls) = @_;
	olist_add_upto_sync($prev_dict,$prev_rules_prefix,$prev_patts_prefix,$sync,$use_align,$new_dict,$new_rules_prefix,$new_patts_prefix,$used_dict,$adict,$gnulls);
}

sub cl_olist_tree_from_rules ($$) {
	my ($rules_prefix,$tree_prefix) = @_;
	olist_tree_from_rules($rules_prefix,$tree_prefix);
}

sub cl_olist_fast_word ($$$) {
	my ($word,$tree_prefix,$gnullsfn) = @_;
	fread_gnull_list($gnullsfn,%gnulls);
	my $newword=add_gnull_word($word,%gnulls);
	my $sound = olist_fast_word($word,$tree_prefix);
	print "$word ($newword) -> $sound\n";
}

sub cl_olist_fast_file ($$$$) {
	my ($wordlist,$tree_prefix,$gnulls,$newdict) = @_;
	olist_fast_file($wordlist,$tree_prefix,$gnulls,$newdict);
}

sub cl_find_rules_after_groups ($$$$$) {
	my ($df,$pre,$newrtype,$rgf,$rf) = @_;
	$rtype = $newrtype;
	print "Generating rule set - using groups:\n";
	print "Dict file:\t$df\nPre_aligned:\t$pre\nType:\t$rtype\nRules file:\t$rf\n";
	my %g2ptypes=("bounce"=>1,"win"=>1,"win_max"=>1,"win_min"=>1);
	
	fread_rulegroups("$rgf");
	if (exists $g2ptypes{$rtype}) {
		fgen_rules_after_groups($df,$pre,"$df.aligned","$df.gnulls");
	} else {
		die "Unknown rule type $rtype";
	}
	fwrite_rules($rf);
	$t = gmtime();
	print "TIME\trules written:\t\t$t\n";
}

sub cl_build_tree($$$) {
	my ($g,$pattsfn,$rulesfn) = @_;
	print "Generating tree for single g:\n";
	print "g:\t$g\nPattsfile:\t$pattsfn\nRulesfile:\t$rulesfn\n";
	fbuild_tree($g,$pattsfn,$rulesfn);
}

sub cl_expand_rulegroups($$$) {
	my ($inrf,$grf,$outrf) = @_;
	fread_rules($inrf);
	fread_rulegroups($grf);
	expand_all_rules();
	foreach my $r (keys %rulecnt) {delete $rulecnt{$r}}
	fwrite_rules($outrf);
}

sub cl_cntrules_adict ($$$) {
	my ($rf,$adf,$rcntf) = @_;
	print "Counting rules applicable to an aligned dictionary:\n";
	print "Rules file:\t$rf\nAligned dict file:\t$adf\nRule countn file:\t$rcntf\n";
	local (%agd,%apd)=((),());
	fread_rules($rf);
	fread_align($adf,%agd,%apd);
	cntrules_adict(%agd,%apd);
	fwrite_rules($rcntf);
}

sub cl_rules ($$$$) {
	my ($df,$rf,$pre,$newrtype) = @_;
	$rtype = $newrtype;
	print "Generating rule set:\n";
	print "Dict file:\t$df\nPre_aligned:\t$pre\nType:\t$rtype\nRules file:\t$rf\n";
	my %g2ptypes=("bounce"=>1,"win"=>1,"win_max"=>1,"win_min"=>1);
	
	if ($rtype eq "win_min") {	
		my $inrf = $rf;
		$inrf =~ s/win_min/win_max/g;		
		if ((-e $inrf)&&(!($rf eq $inrf))) {
			fread_rules($inrf);
			fread_align("$df.aligned",%agd,%apd);
			#opt_rules_v2($df,%agd,%apd,1);  #Assumes $df.patts.* exists
			opt_rules(%agd,%apd);  #Assumes $df.patts.* exists
		} else {
			fgen_rules($df,$pre,"$df.aligned","$df.gnulls");
		}		
	} elsif (exists $g2ptypes{$rtype}) {
		fgen_rules($df,$pre,"$df.aligned","$df.gnulls");
	} else {
		die "Unknown rule type $rtype";
	}
	$t = gmtime();
	print "TIME\trules written:\t\t$t\n";
	fwrite_rules($rf);
}


sub cl_align ($$$$) {
	my ($df,$af,$gf,$pre) = @_;
	print "Aligning dictionary:\n";
	print "Dict file:\t$df\nAligned dict file:\t$af\nGnulls file:\t$gf\n";
	falign_dict($df,$af,$gf,$pre);
}

sub cl_extract ($$$) {
	my ($adf,$rt,$pf) = @_;
	my %agd=();
	my %apd=();
	print "Extracting patterns:\n";
	print "Aligned dict file:\t$adf\nPatterns file prefix:\t$pf\nRule type:\t$rt\n";
	$rtype=$rt;
	fread_align($adf,%agd,%apd);
	if ($rtype eq "olist") {
		extract_patterns_olist(%agd,%apd,$pf);
	} else {
		extract_patterns(%agd,%apd,$pf);
	}
}

sub cl_align_acc ($$$) {
	my ($d1name,$d2name,$resname) = @_;
	print "Comparing word-level alignment accuracy: $d1name and $d2name\n";
	print "Results in: $resname\ni\n";
	fcmp_aligned($d1name,$d2name,$resname);
	print `cat $resname`; 
}

sub cl_analyse_dict2 ($$$) {
	my ($ad1name,$ad2name,$resname) = @_;
	print "Analyse results for comparison: $ad1name and $ad2name\n";
	print "Results in: $resname\n";
	open OH, ">$resname" or die "Error opening $resname\n";
	fread_align($ad1name,%agd1,%apd1);
	fread_align($ad2name,%agd2,%apd2);
	my %diff=();
	my %same=();
	foreach my $w (keys %agd1) {
		my @w1=@{$agd1{$w}};
		my @s1=@{$apd1{$w}};
		if (exists $agd2{$w}) {
			my @w2=@{$agd2{$w}};
			my @s2=@{$apd2{$w}};
			if ($#w1 != $#w2) {
				print "Warning - different gnull usage - ignored\n"
			} else {
				foreach my $l (0..$#w1) {
					if ($s1[$l] eq $s2[$l]) {
						$same{$w1[$l]}{$s1[$l]}++;
					} else {
						$diff{$w1[$l]}{$s1[$l]}{$s2[$l]}++;
					}
				}
			}
		}
	}
	print OH "Correct:\n";
	foreach my $g (sort keys %same) {
		foreach my $p (sort keys %{$same{$g}}) {
			print OH "$g\t$p\t$same{$g}{$p}\n";
		}
	}
	print OH "Wrong:\n";
	foreach my $g (sort keys %diff) {
		my $gtot=0;
		foreach my $p (sort keys %{$diff{$g}}) {
			foreach my $p2 (sort keys %{$diff{$g}{$p}}) {
				$gtot+=$diff{$g}{$p}{$p2};
				print OH "$g\t$p\t$p2\t$diff{$g}{$p}{$p2}\n";
			}
		}
		print OH "$g\t\t\t[$gtot]\n";
	}
}


sub cl_phone_acc ($$$$) {
	my ($d1name,$d2name,$pname,$resname) = @_;
	print "Comparing phone-level accuracy: $d1name and $d2name (using $pname)\n";
	print "Results in: $resname\n";
	fcmp_phoneAcc($d1name,$d2name,$pname,$resname);
	print `cat $resname`; 
}


sub cl_acc ($$$$$$$) {
	my ($d1name,$d2name,$phonfn,$conf,$apairs,$var,$resname) = @_;
	print "Comparing phone-level accuracy: $d1name and $d2name (confusion_matrix=$conf; aligned_pairs=$apairs; variant_info=$var)\n";
	print "Results in: $resname*\n";
	compare_accuracy($d1name,$d2name,$phonfn,$conf,$apairs,$var,$resname);
	print `cat $resname`; 
}


sub cl_word_acc ($$) {
	my ($d1name,$d2name) = @_;
	print "Comparing word-level accuracy: $d1name and $d2name\n";
	local %result=();
	cmp_dicts($d1name,$d2name,%result);
	show_result(%result);	
}

sub cl_dict_gettype ($$$) {
	my ($dname,$type,$oname) = @_;
	print "Extract dictionary from $dname consisting of all words of type $type\n";
	my %dict=(); my %stat=(); my %outdict=(); my %outstat=();
	fread_dict($dname,%dict,%stat);
	foreach my $word (keys %dict) {
		if ($stat{$word}==$verdictValue{$type}) {
			$outdict{$word} = $dict{$word};
			$outstat{$word} = $stat{$word};
		}
	}
	fwrite_dict($oname,%outdict,%outstat);
}

sub cl_dict_getagree ($$$) {
	my ($d1name,$d2name,$oname) = @_;
	print "Extract dictionary from $d1name and $d2name consisting of all words marked 'Correct' that agree\n";
	my %dict1=(); my %stat1=(); my %dict2=(); my %stat2=(); my %outdict=(); my %outstat=();
	fread_dict($d1name,%dict1,%stat1);
	fread_dict($d2name,%dict2,%stat2);
	foreach my $word (keys %dict1) {
		if (exists $dict2{$word}) {
			if (($stat1{$word}==$verdictValue{'Correct'})
			  &&($stat2{$word}==$verdictValue{'Correct'})
			  &&($dict1{$word} eq $dict2{$word})) {
				$outdict{$word} = $dict1{$word};
				$outstat{$word} = $stat1{$word};
			}
		}
	}
	fwrite_dict($oname,%outdict,%outstat);
}

sub cl_write_contexts ($$$$) {
	my ($mname,$cname,$cmax,$otype) = @_;
	local %chash=();
	fextract_contexts($mname,1,$cmax,%chash); 
	if ($otype eq 'mostFrequent') { $exact=0 } 
	elsif ($otype eq 'growingContext') { $exact=1 } 
	else { die "Unknown ordering type\n" } 
	fwrite_contexts($cname,%chash,$cmax,$exact);
}

sub cl_clean_contexts ($$$$) {
	my ($cname,$dname,$cmax,$otype) = @_;
	local %dict=(); local %stat=(); local %chash=();
	if ($otype eq 'mostFrequent') { $exact=0 } 
	elsif ($otype eq 'growingContext') { $exact=1 } 
	else { die "Unknown ordering type\n" } 
	fread_dict($dname,%dict,%stat);
	fread_contexts($cname,$cmax,$exact,%chash);
	frm_certain_contexts(%stat,%chash,$cmax);
	fwrite_contexts($cname,%chash,$cmax,$exact);
}

sub cl_wlist_frommaster ($$$$$$$) {
	my ($mname,$dname,$cmax,$max,$otype,$done,$wname) = @_;
	print "Creating new word list: $wname\n";
	print "Based on master list $mname, dictionary $dname, max context $cmax, max number $max, available $done and ordering type $otype\n";
        if (($otype eq 'mostFrequent')||($otype eq 'growingContext')) {
        	fwlist_frommaster_predict($mname,"$mname.context",$dname,$max,$otype,$done,$wname);
	} elsif (($otype eq 'evenUncertain')||($otype eq 'firstUncertain')||($otype eq 'even')||($otype eq 'first')){
		fwlist_frommaster($mname,$dname,$max,$otype,$wname); 
	} else {die "Unknown ordering type";}
}

sub cl_wlist_fromdict ($$$$) {
	my ($dname,$max,$otype,$wname) = @_;
	print "Creating new word list: $wname\n";
	print "Based on dictionary $dname, max number $max and ordering type $otype\n";
        if ($otype eq 'first') {fwlist_fromdict($max,0,$dname,$wname);}
	elsif($otype eq 'firstUncertain') {fwlist_fromdict($max,1,$dname,$wname);}
	else { die "Unknown ordering type"; }
}

sub cl_wlist_rmwlist ($$$) {
	my ($oname,$rmname,$newname) = @_;
	print "Creating new word list: $newname\n";
	print "Removing $rmname from $oname\n";
	local (@ohash,@rmhash);
	fread_words($oname,@ohash);
	fread_words($rmname,@rmhash);
	my %rmlist = (); 
	foreach my $name (@rmhash) {$rmlist{$name}=1};
	my @newhash = ();
	foreach my $i (0..$#ohash) { 
		my $name = $ohash[$i];
		if (!(exists $rmlist{$name})) { 
			push @newhash,$name;
		}
	}
	fwrite_words($newname,@newhash);
}


sub cl_dict_from_wlist ($$$) {
	my ($wname,$oldname,$newname) = @_;
	print "Creating new dictionary: $newname\n";
	print "Using word list $wname and existing dictionary $oldname\n";
	fdict_subset($wname,$oldname,$newname);
}

sub cl_dict_add ($$$) {
	my ($d1name,$d2name,$dnewname) = @_;
	print "Creating new dictionary: $dnewname\n";
	print "Using existing dictionaries $d1name and $d2name\n";
	`cp $d2name $dnewname`;
	fadd_dict($d1name,$dnewname);
}

sub cl_analyse_tlog ($) {
	my $lname = shift @_;
	analyse_tlog($lname);
}

sub cl_analyse_vlog ($) {
	my ($lname,$dname) =  @_;
	analyse_vlog($lname);
	#print "Currently not using dict - if needed, call analyse_vlog_dict instead\n";
}


sub cl_analyse_overlap($$$){
	my ($rf, $gf,$wf)=@_;
	my %bigrams=();
	my @words=();
	my $sound="";
	fread_rules $rf;
	fread_words($wf,@words);
	fread_gnull_list($gf,%gnulls);
	foreach my $word (@words) {
		my $newword=add_gnull_word($word,%gnulls);
		my @rinfo=();
		g2p_word_info($newword,\$sound,@rinfo);
		foreach my $i (0..($#rinfo-1)) {
			$rinfo[$i] =~ /^(.*)-(.)-(.*)$/;
			my $r1g = $2;
			my $r1r = substr $3,0,1;
			$rinfo[$i+1] =~ /^(.*)-(.)-(.*)$/;
			my $r2g = $2;
			my $r2l = substr $1,-1,1;
			if (($r1g eq $r2l)&&($r1r eq $r2g)) {
				$bigrams{$rinfo[$i]}{$rule{$rinfo[$i+1]}}++;
			}
		}
	}
	foreach my $r1 (keys %bigrams) {
		my $rtot=0;
		$r1p = $bigrams{$r1};
		foreach my $r2 (keys %{$r1p}) {
			$rtot+=$r1p->{$r2};
		}
		foreach my $r2 (keys %{$r1p}) {
			my $rprob = $r1p->{$r2} / $rtot;
			#my $rval = "[$r1:$rule{$r1}]\t[$r2:$rule{$r2}]\t$rtot\t$r1p->{$r2}";
			my $rval = "[$r1:$rule{$r1}]\t[$r2]\t$rtot\t$r1p->{$r2}";
			$overlap{$rprob}{$rval}=1;
		}
        }
	foreach my $p (sort {$b<=>$a} keys %overlap) {
		foreach my $v (keys %{$overlap{$p}}) {
			print "$p\t$v\t\n";
		}
	}
}


sub cl_analyse_rules ($) {
	my ($rname) = shift @_;
	local %cstat=();
        fcount_rules $rname,%cstat;
        #my @patts = sort {$cstat{$b} <=> $cstat{$a}} keys %cstat;
	print "Total:\t$cstat{'total'}\n";
	delete $cstat{'total'};
	my @patts = sort {$a <=> $b} keys %cstat;
	print "Counting rules $rname\n";
        foreach my $pat (@patts) {
                if ($cstat{$pat}!=0) {print "$pat $cstat{$pat}\n";}
        }
}

sub cl_analyse_wlist ($$$) {
	my ($rname, $gname, $wname) = @_;
	fread_rules($rname);
	analyse_wordlist($wname,$gname);
}

sub cl_id_gnulls($){
	my $dname = shift @_;
	id_gnulls($dname);
}


sub cl_analyse_g2p($$) {
	my ($aname,$oname)=@_;
	open OH,">$oname" or die "Error opening $oname";
	my %agd=();
	my %apd=();
	my %cnt=();
	fread_align($aname,%agd,%apd);
	foreach my $w (keys %agd) {
		my @gstr = @{$agd{$w}};
		my @pstr = @{$apd{$w}};
		foreach my $i (0..$#gstr) {
			$cnt{$gstr[$i]}{$pstr[$i]}++;
			$cnt{$gstr[$i]}{'tot'}++;
		}
	}
	foreach my $g (sort keys %cnt) {
		foreach my $p (sort {$cnt{$g}{$b}<=>$cnt{$g}{$a}} keys %{$cnt{$g}}) {
			next if $p eq 'tot';
			my $val1 = $cnt{$g}{$p};
			my $val2 = $val1/$cnt{$g}{'tot'};
			print OH "$g\t$p\t$val1\t$val2\n";
		}
	}
}


#STILL CHECK
sub cl_rmdoubles($$$){
	my ($type,$oname,$nname) = @_;
	if ($type eq 'aligned') {
		fread_align($oname,%agd,%apd);
		my %new_dict=(); 
		foreach my $word (keys %agd) {
			$new_dict{$word} = 1;
		}
		fwrite_align($nname,%new_dict,%agd,%apd);
	} elsif ($type eq 'general') {
		my %dict=(); my %stat=();
		fread_dict($oname,%dict,%stat);
		fwrite_dict($nname,%dict,%stat);
	} else {
		print "Type $type not supported\n";
	}
}

sub cl_adddoubles($$$){
	my ($type,$oname,$nname) = @_;
	if ($type eq 'aligned') {
		my %agd=(); my %apd=();
		fread_align($oname,%agd,%apd);
		my %new_dict=(); 
		foreach my $word (keys %agd) {
			$new_dict{$word} = 1;
		}
		fwrite_align($nname,%new_dict,%agd,%apd);
	} elsif ($type eq 'general') {
		my %dict=(); my %stat=();
		fread_dict($oname,%dict,%stat);
		fwrite_dict($nname,%dict,%stat);
	} else {
		print "Type $type not supported\n";
	}
}

sub cl_getalign($$$){
	my ($wname,$dname,$nname) = @_;
	my @words=();
	fread_words($wname,@words);
	fread_align($dname,%agd,%apd);
	my %new_agd=(); my %new_apd=(); my %new_dict=(); 
	foreach my $word (@words) {
		if (!(exists $agd{$word})) {
			print "Warning: $word not in aligned dictionary\n";
		} elsif ($dictType==$doubleType{'pos_one'}) {
			foreach my $f (keys %{$agd{$word}}) {
				$new_dict{$word}{$f} = 1;
				@{$new_agd{$word}{$f}} = @{$agd{$word}{$f}};
				@{$new_apd{$word}{$f}} = @{$apd{$word}{$f}};
			}
		} else {
			$newword = $word;
			$newi=0;
			while (exists $agd{$newword}) {
				$new_dict{$newword} = 1;
				@{$new_agd{$newword}} = @{$agd{$newword}};
				@{$new_apd{$newword}} = @{$apd{$newword}};
				$newi++;
				$newword="${word}_$newi";
			}
		}
	}
	fwrite_align($nname,%new_dict,%new_agd,%new_apd);
}

sub cl_dict_getdisagree ($$$) {
	my ($d1,$d2,$wname) = @_;
	#Extract word list <$wname> from <$d1> and <$d2> consisting of all words with different predictions - irrespective of verdict
	my %dict1=(); my %stat1=();
	my %dict2=(); my %stat2=();
	fread_dict($d1,%dict1,%stat1);
	fread_dict($d2,%dict2,%stat2);
	while (my($key,$val)=each %dict1) {
		if ((exists($dict2{$key}))&&(!($dict2{$key} eq $val))) {
			push @wlist,$key;
		}
	}
	fwrite_words($wname,@wlist);
}

sub fread_analyse ($\%\%) {
	my ($fname,$dictp,$rulep) = @_;
	open IH,$fname or die "Error opening $fname";
	my $word="";
	while (<IH>) {
		chomp;
		if (/word: \[(.*)\]/) {
			$word=$1;
			$word=~s/0//g;
		} elsif (/\[(.*)\] -> (.*)/) {
			push @{$dictp->{$word}},$1;
			$rulep->{$1}=$2;
		}
	}
}

sub cl_cmpdicts($$$$$) {
	my ($words,$d1,$d2,$dref,$result)=@_;
	#Assumes an analyse_file exists for each dict, and a diff word list;
	open IH1, ">$result.OK1" or die "Error opening $result.OK1";
	open IH2, ">$result.OK2" or die "Error opening $result.OK2";
	open IH3, ">$result.none" or die "Error opening $result.none";
	my %dictref=(); my %statref=();
	my %dict1=(); my %arule1=();
	my %dict2=(); my %arule2=();
	fread_dict($dref,%dictref,%statref);
	fread_analyse($d1,%dict1,%arule1);
	fread_analyse($d2,%dict2,%arule2);
	fread_words($words,@wlist);
	print IH1 "Correct in $d1\nWrong in $d2\n";
	print IH2 "Correct in $d2\nWrong in $d1\n";
	print IH3 "Wrong in $d1\nWrong in $d2\n";
	foreach my $word (@wlist) {
		my @sound1=();
		my @sound2=();
		my ($snd1,$snd2);
		foreach my $l (0..$#{$dict1{$word}}) {
			$sound1[$l] = $arule1{$dict1{$word}[$l]};
		}
		$snd1 = join "",@sound1;
		$snd1 =~ s/0//g;
		foreach my $l (0..$#{$dict2{$word}}) {
			$sound2[$l] = $arule2{$dict2{$word}[$l]};
		}
		$snd2 = join "",@sound2;
		$snd2 =~ s/0//g;
		
		if ($snd1 eq $dictref{$word}) {
			detail_diff_dicts($word,$snd1,@sound1,@{$dict1{$word}},$snd2,@sound2,@{$dict2{$word}},$dictref{$word},IH1);
		} elsif ($snd2 eq $dictref{$word}) {
			detail_diff_dicts($word,$snd2,@sound2,@{$dict2{$word}},$snd1,@sound1,@{$dict1{$word}},$dictref{$word},IH2);
		} else {
			detail_diff_dicts($word,$snd1,@sound1,@{$dict1{$word}},$snd2,@sound2,@{$dict2{$word}},$dictref{$word},IH3);
		}
	}
}

sub cl_cmpresults($$$) {
	my ($f1,$f2,$ignore)=@_;
	compare_results_3col($f1,$f2,$ignore);
}

#--------------------------------------------------------------------------

sub cl_pos_groups_from_rules($$$) {
	my ($inrules,$mingroupsize,$outgroups)=@_;
	id_pos_groups_from_rules($inrules,$mingroupsize,$outgroups);
}

sub cl_pos_groups_from_pats($$$$) {
	my ($inpats,$maxcontext,$mingroupsize,$outgroups)=@_;
	id_pos_groups_from_pats($inpats,$maxcontext,$mingroupsize,$outgroups);
}


sub cl_fgen_rules_withgroups_single_large($$$$) {
        my ($g,$groupsfile,$pattsfile,$rulefile)=@_;
	fgen_rules_withgroups_single_large($g,$groupsfile,$pattsfile,$rulefile);
	fwrite_rules_olist($rulefile);
}

sub cl_kmeans($$$) {
	my ($infile,$numgroups,$outfile)=@_;
	do_kmeans($infile,$numgroups,$outfile);
}

#--------------------------------------------------------------------------

sub print_usage () {
	print "Usage: g2p <word> <rules> <gnulls> {<rtype>}\n";
	print "       g2p_info <word> <rules> <gnulls> <rtype>\n"; 
	print "       rules <dict> <newrules> <pre_aligned> [dec|bounce|win|win_max|win_min]\n";
	print "       align <dict> <aligneddict> <gnullfile> {pre} \n"; 
	print "       extract <dict> <rtype> <patts_prefix>\n"; 
	print "       g2pfile <words> <rules> <gnulls> <newdict> {<rtype>}\n";
	print "       g2pfile nulls <words> <rules> <gnulls> <newdict> <rtype>\n";
	print "       accuracy <dict_ref> <dict_tested> [word|phone phones <resultfile>]>\n";
	print "       acc2 <dict_ref> <dict_tested> <phones> <confusion=0|1> <aligned_pairs=0|1> <variant_info=0|1> <result_prefix>\n";
	print "       align_accuracy <dict_ref> <dict_tested> <resultfile]>\n";
	print "       wlist master <master_wlist> <current_dict> <contextmax> <maxnum> [growingContext|mostFrequent|first|firstUncertain|even|evenUncertain] [0|1|2] <new_wlist>\n"; 
	print "       wlist dict <dict> <maxnum> [first|firstUncertain] <new_wlist>\n"; 
	print "       wlist wlist_rm <originalwlist> <removewlist> <new_wlist>\n"; 
	print "       dict <wlist> <dict_old> <dict_new>\n";
	print "       dict_add <dict1> <dict2> <dict_new>\n"; 
	print "       dict_getagree <dict1> <dict2> <dict_new>\n";
	print "       dict_getdisagree <dict1> <dict2> <wordlist>\n"; 
	print "       dict_gettype <dict1> [Correct|Invalid|Uncertain|Ambiguous] <dict_new>\n"; 
	print "       write_contexts <master_wlist> <contextprefix> <contextmax> [growingContext|mostFrequent]\n"; 
	print "       clean_contexts <contextprefix> <dict> <contextmax> [growingContext|mostFrequent]\n"; 
	print "       splitdata <infile> <extracted> <left> <nth> <num>\n";
	print "       splitparts <infile> <n> <outprefix>\n";
	print "       combineparts <inprefix> <n> <outprefix>\n";
	print "       combineresults <iname> <;-separated parts> <oname>\n";
	print "       getalign <wordlist> <fulldict> <newdict>\n";
	print "       rmdoubles [aligned|general] <olddict> <newdict>\n";
	print "       adddoubles [aligned|general] <olddict> <newdict>\n";
	print "       id_gnulls <dictname>\n";
	print "       analyse timelog <logname>\n";
	print "       analyse verdictlog <logname>\n";
	print "       analyse wlist <rules> <gnulls> <words>\n"; 
	print "       analyse rules <rules> <gnulls> <words>\n";
	print "       analyse overlap <rules> <gnulls> <words>\n";
	print "       analyse dict2 <dict1> <dict2> <result>\n";
	print "       cntrules <rulesname> <aligneddict> <outcountfile>\n";
	print "       cmpdicts <diffwords> <dict1.analyse> <dict2.analyse> <dictref> <result>\n";
	print "       cmpresults <file1> <file2> <lines_to_ignore>\n";
	print "       find_rulepairs <rules> <dict> <gnulls> <pairs>\n";
	#print "       find_rulegroups_before <dict> <rtype> <groups>\n";
	#print "       find_rulegroups_after <rules> <dict> <rtype> <groups>\n";
	#print "       find_rulegroups_with <dict> <newrules> [0|1|2] olist\n";
	print "       find_rulegroups_single <g> <pattsfile> <rtype> <newrules>\n";
	#print "       find_rules_after_groups <dict> <pre> <rtype> <groups> <newrules>\n";
	#print "       expand_rulegroups <rules> <newrules>\n";
	#print "       conv_rules_olist <inrules> <outrules>\n";
	print "       build_tree <g> <pattsfile> <rulesfile>\n";
	print "       olist_add_word <word> <prev_rules_prefix> <patts_prefix> <new_rules_prefix>\n";
	print "       olist_add_upto_sync <prev_dict> <prev_rules_prefix> <prev_patts_prefix> <sync> <use_align=0|1> <new_dict> <new_rules_prefix> <new_patts_prefix> <used_dict> [ <prev_aligned> <prev_gnulls>] \n";
	print "       olist_tree_from_rules <rules_prefix> <tree_prefix>\n";
	print "       olist_fast_word <word> <tree_prefix> <gnulls>\n";
	print "       olist_fast_file <wordlist> <tree_prefix> <gnulls> <newdict>\n";
	print "       restrict_rules <in_rules> <numseen> <cutoff> <out_rules>\n";
	print "       id_pos_errors <in_rules> <in_singles> <cntif_net_lessthan> <cntif_match_lessthan> <cutoff_numrules> <out_errors> <out_rules>\n";
	print "       id_pos_errorwords <in_singles> <cntif_net_lessthan> <cntif_match_lessthan> <cutoff_numrules> <out_errors>\n";
	print "       pos_groups_from_rules <in_rules> <mingroupsize> <out_groups>\n";
	print "       pos_groups_from_pats <in_rules> <maxcontext> <mingroupsize> <out_groups>\n";
	print "       find_rules_withgroups_single_large <g> <in_groups> <in_patts> <out_rules>\n";
	print "       kmeans <in_groups> <numgroups> <out_groups>\n";
}

#--------------------------------------------------------------------------

if (@ARGV < 1) {
	print_usage;
	exit;
}

if ($ARGV[0] eq "g2p") {
	if ($#ARGV ==3) { cl_g2p $ARGV[1],$ARGV[2],$ARGV[3] }
	elsif ($#ARGV==4) { cl_g2p_rtype $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4] }
	else {print "Usage: g2p <word> <rules> <gnulls> [<rtype>]\n"} 
} elsif ($ARGV[0] eq "g2p_info") {
	if ($#ARGV==4) { cl_g2p_info $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4] }
	else {print "Usage: g2p_info <word> <rules> <gnulls> <rtype>\n"} 
} elsif ($ARGV[0] eq "g2pfile") {
	if (($ARGV[1] eq "nulls")&&($#ARGV==6)) {cl_g2p_file_rtype_nulls $ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5],$ARGV[6]}	
	elsif ((!($ARGV[1] eq "nulls"))&&($#ARGV ==4)) {cl_g2p_file $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4]}	
	elsif ((!($ARGV[1] eq "nulls"))&&($#ARGV==5)) {cl_g2p_file_rtype $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5]}	
	else {print "Usage: g2pfile <words> <rules> <gnulls> <newdict> [<rtype>]\n";
	      print "       g2pfile nulls <words> <rules> <gnulls> <newdict> <rtype>\n";}
} elsif ($ARGV[0] eq "rules") {
	if ($#ARGV !=4) { print "Usage: rules <dict> <newrules> <pre_aligned> [dec|bounce|win|win_max|win_min]\n"} 
	else {cl_rules $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4]}
} elsif ($ARGV[0] eq "align") {
	if ($#ARGV==3) {cl_align $ARGV[1],$ARGV[2],$ARGV[3],0}
	elsif ($#ARGV==4) {cl_align $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4]}
	else { print "Usage: align <dict> <aligneddict> <gnullfile> {pre}\n"} 
} elsif ($ARGV[0] eq "extract") {
	if ($#ARGV !=3) { print "Usage: extract <dict> <rtype> <patts_prefix>\n"} 
	else {cl_extract $ARGV[1],$ARGV[2],$ARGV[3]}
} elsif ($ARGV[0] eq "acc2") {
	if ($#ARGV==7) { cl_acc $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5],$ARGV[6],$ARGV[7] } 
	else { print "Usage: acc2 <dict_ref> <dict_tested> <phones> <confusion=0|1> <aligned_pairs=0|1> <variant_info=0|1> <result_prefix>\n"}
} elsif ($ARGV[0] eq "accuracy") {
	if (($#ARGV==3)&&($ARGV[3] eq 'word')) { cl_word_acc $ARGV[1],$ARGV[2] } 
	elsif (($#ARGV==5)&&($ARGV[3] eq 'phone')) { cl_phone_acc $ARGV[1],$ARGV[2],$ARGV[4],$ARGV[5] } 
	else { print "Usage: accuracy <dict_ref> <dict_tested> [ word|phone <phones> <resultfile> ]\n"}
} elsif ($ARGV[0] eq "align_accuracy") {
	if ($#ARGV==3) { cl_align_acc $ARGV[1],$ARGV[2],$ARGV[3];} 
	else {print "Usage: align_accuracy <dict_ref> <dict_tested> <resultfile]>\n";}
} elsif ($ARGV[0] eq "dict") {
	if ($#ARGV !=3) { print "Usage: dict <wlist> <dict_old> <dict_new>\n"} 
	else {cl_dict_from_wlist $ARGV[1],$ARGV[2],$ARGV[3]}
} elsif ($ARGV[0] eq "dict_add") {
	if ($#ARGV !=3) { print "Usage: dict_add <dict1> <dict2> <dict_new>\n"} 
	else {cl_dict_add $ARGV[1],$ARGV[2],$ARGV[3]}
} elsif ($ARGV[0] eq "dict_gettype") {
	if ($#ARGV !=3) { print "Usage: dict_gettype <dict1> [Correct|Invalid|Uncertain|Ambiguous]  <dict_new>\n"} 
	else {cl_dict_gettype $ARGV[1],$ARGV[2],$ARGV[3]}
} elsif ($ARGV[0] eq "dict_getagree") {
	if ($#ARGV !=3) { print "Usage: dict_getagree <dict1> <dict2> <dict_new>\n"} 
	else {cl_dict_getagree $ARGV[1],$ARGV[2],$ARGV[3]}
} elsif ($ARGV[0] eq "dict_getdisagree") {
	if ($#ARGV !=3) { print "Usage: dict_getagree <dict1> <dict2> <wordlist>\n"} 
	else {cl_dict_getdisagree $ARGV[1],$ARGV[2],$ARGV[3]}
} elsif ($ARGV[0] eq "write_contexts") {
	if ($#ARGV==4) { cl_write_contexts $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4] }
	else { print "Usage: write_contexts <master_wlist> <contextprefix> <contextmax> [growingContext|mostFrequent]\n"} 
} elsif ($ARGV[0] eq "clean_contexts") {
	if ($#ARGV==4) { cl_clean_contexts $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4] }
	else { print "Usage: clean_contexts <contextprefix> <dict> <contextmax> [growingContext|mostFrequent\n"} 
} elsif ($ARGV[0] eq "wlist") {
	if (($ARGV[1] eq 'master')&&($#ARGV ==8)) {
		cl_wlist_frommaster $ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5],$ARGV[6],$ARGV[7],$ARGV[8];
	} elsif (($ARGV[1] eq 'dict')&&($#ARGV ==5)) {
		cl_wlist_fromdict $ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5];
	} elsif (($ARGV[1] eq 'wlist_rm')&&($#ARGV ==4)) {
		cl_wlist_rmwlist $ARGV[2],$ARGV[3],$ARGV[4];
	} else {
 		print "Usage: wlist master <master_wlist> <current_dict> <contextmax> <maxnum> [growingContext|mostFrequent|first|firstUncertain|even|evenUncertain] [0|1|2] <new_wlist>\n"; 
 		print "Usage: wlist dict <dict> <maxnum> [first|firstUncertain] <new_wlist>\n"; 
		print "Usage: 0=contexts from scratch, 1=full contexts available, 2=remaining contexts available\n"; 
	        print "Usage: wlist wlist_rm <original_wlist> <remove_wlist> <new_wlist>\n";}
} elsif ($ARGV[0] eq "analyse") {
	if (($ARGV[1] eq 'timelog')&&($#ARGV==2)) { cl_analyse_tlog $ARGV[2] } 
	elsif (($ARGV[1] eq 'verdictlog')&&($#ARGV==2)) { cl_analyse_vlog $ARGV[2]} 
	elsif (($ARGV[1] eq 'rules')&&($#ARGV==2)) { cl_analyse_rules $ARGV[2] } 
	elsif (($ARGV[1] eq 'wlist')&&($#ARGV==4)) { cl_analyse_wlist $ARGV[2],$ARGV[3],$ARGV[4] } 
	elsif (($ARGV[1] eq 'overlap')&&($#ARGV==4)) { cl_analyse_overlap $ARGV[2],$ARGV[3],$ARGV[4] }
	elsif (($ARGV[1] eq 'dict2')&&($#ARGV==4)) { cl_analyse_dict2 $ARGV[2],$ARGV[3],$ARGV[4] } 
	elsif (($ARGV[1] eq 'g2p')&&($#ARGV==3)) { cl_analyse_g2p $ARGV[2],$ARGV[3] } 
	else { 	print "Usage: analyse timelog <logname>\n";
	 	print "Usage: analyse verdictlog <logname> <refdict>\n";
	 	print "Usage: analyse rules <rules>\n";
		print "Usage: analyse overlap <rules> <gnulls> <words>\n";
		print "Usage: analyse wlist <rules> <gnulls> <words>\n";
		print "Usage: analyse dict2 <dict1> <dict2> <result>\n";
		print "Usage: analyse g2p <aligned_dict> <result>\n";
	}
} elsif ($ARGV[0] eq "id_gnulls") {
	if ($#ARGV ==1) {cl_id_gnulls $ARGV[1]}
	else { print "Usage: id_gnulls <dictname>\n" }
} elsif ($ARGV[0] eq "getalign") {
	if ($#ARGV ==3) {cl_getalign $ARGV[1],$ARGV[2],$ARGV[3]}
	else { print "Usage: getalign <wordlist> <fulldict> <newdict>\n" }
} elsif ($ARGV[0] eq "rmdoubles") {
	if ($#ARGV ==3) {cl_rmdoubles $ARGV[1],$ARGV[2],$ARGV[3]}
	else { print "Usage: rmdoubles [aligned|general] <olddict> <newdict>\n" }
} elsif ($ARGV[0] eq "adddoubles") {
	if ($#ARGV ==3) {cl_adddoubles $ARGV[1],$ARGV[2],$ARGV[3]}
	else { print "Usage: adddoubles [aligned|general] <olddict> <newdict>\n" }
} elsif ($ARGV[0] eq "splitdata") {
	if ($#ARGV ==5) { 
		split_data $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5];
	} else { 
		print "Usage: splitdata <infile> <nth> <num> <extracted> <left>\n";
		print"        writes every <nth> line from <infile> to <extracted> and the rest to <left>\n";
		print"        up to a maximum of size <num> in <extracted>\n";
	}
} elsif ($ARGV[0] eq "splitparts") {
	if ($#ARGV ==3) { 
		split_parts $ARGV[1],$ARGV[2],$ARGV[3];
	} else { 
	        print "Usage: splitparts <infile> <n> <outprefix>\n";
	        print"        Splits <infile> into <n> separate files of equal size - lines selected randomly\n";
	}
} elsif ($ARGV[0] eq "combineparts") {
	if ($#ARGV==3) { 
		combine_parts $ARGV[1],$ARGV[2],$ARGV[3];
	} else { 
	        print "Usage: combineparts <inprefix> <n> <outprefix>\n";
	        print"        Combines <inprefix>.<x> files into <outprefix>.train.<x> and <outprefix>.test.<x> files\n";
	}
} elsif (($ARGV[0] eq "combineresults")&&($#ARGV==3)) { 
		combine_results $ARGV[1],$ARGV[2],$ARGV[3];
} elsif ($ARGV[0] eq "cntrules") {
	if ($#ARGV!=3) { print "Usage: cntrules <rulesfile> <aligneddict> <outcntfile>\n"} 
	else {cl_cntrules_adict $ARGV[1],$ARGV[2],$ARGV[3]}
} elsif ($ARGV[0] eq "cmpdicts") {
	if ($#ARGV!=5) { print "Usage: cmpdicts <diffwords> <dict1.analyse> <dict2.analyse> <dictref> <result>\n"} 
	else {cl_cmpdicts $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5]}
} elsif ($ARGV[0] eq "cmpresults") {
	if ($#ARGV!=3) { print "Usage: cmpresults <file1> <file2> <lines_to_ignore>\n"} 
	else {cl_cmpresults $ARGV[1],$ARGV[2],$ARGV[3]}
} elsif ($ARGV[0] eq "find_rulepairs") {
	if ($#ARGV==4) {
		cl_find_rulepairs $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage: find_rulepairs <rules> <dict> <gnulls> <pairs>\n";
	}
} elsif ($ARGV[0] eq "find_rulegroups_with") {
	if ($#ARGV==4) {
		cl_do_rulegroups $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage: find_rulegroups_with <dict> <newrules> [0|1|2] olist\n";
	}
} elsif ($ARGV[0] eq "find_rulegroups_before") {
	if ($#ARGV==5) {
		cl_find_rulegroups_before $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5];
	} else {
		print "Usage: find_rulegroups_before <dict> <rtype> <maxcontext> <threshold> <groups>\n";
	}
} elsif ($ARGV[0] eq "find_rulegroups_after") {
	if ($#ARGV==4) {
		cl_find_rulegroups_after $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage: find_rulegroups_after <rules> <dict> <rtype> <groups>\n";
	}
} elsif ($ARGV[0] eq "find_rules_after_groups") {
	if ($#ARGV==5) {
		cl_find_rules_after_groups $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5];
	} else {
		print "Usage: find_rules_after_groups <dict> <pre> <rtype> <groups> <newrules>\n";
	}
} elsif ($ARGV[0] eq "expand_rulegroups") {
	if ($#ARGV==3) {
		cl_expand_rulegroups $ARGV[1],$ARGV[2],$ARGV[3];
	} else {
		print "Usage: expand_rulegroups <rules> <groups> <newrules>\n";
	}
} elsif ($ARGV[0] eq "find_rulegroups_single") {
	if ($#ARGV==4) {
		cl_find_rulegroups_single_large $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage: find_rulegroups_single <g> <pattsfile> <rtype> <newrules>\n";
	}
} elsif ($ARGV[0] eq "conv_rules_olist") {
	if ($#ARGV==2) {
		cl_conv_rules_olist $ARGV[1],$ARGV[2];
	} else {
		print "Usage: conv_rules_olist <inrules> <outrules>\n";
	}
} elsif ($ARGV[0] eq "build_tree") {
	if ($#ARGV==3) {
		cl_build_tree $ARGV[1],$ARGV[2],$ARGV[3];
	} else {
		print "Usage: build_tree <g> <pattsfile> <rulesfile>\n";
	}
} elsif ($ARGV[0] eq "olist_add_word") {
	if ($#ARGV==4) {
		cl_olist_add_word $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage: olist_add_word <word> <prev_rules_prefix> <patts_prefix> <new_rules_prefix>\n";
	}
} elsif ($ARGV[0] eq "olist_add_upto_sync") {
	if (($ARGV[5]==1)&&($#ARGV==9)) {
		cl_olist_add_upto_sync $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5],$ARGV[6],$ARGV[7],$ARGV[8],$ARGV[9],"na","na";
	} elsif (($ARGV[5]==0)&&($#ARGV==11)) {
		cl_olist_add_upto_sync $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5],$ARGV[6],$ARGV[7],$ARGV[8],$ARGV[9],$ARGV[10],$ARGV[11];	
	} else {
		print "Usage: olist_add_upto_sync <prev_dict> <prev_rules_prefix> <prev_patts_prefix> <sync> <use_align=[0|1]> <new_dict> <new_rules_prefix> <new_patts_prefix> <used_dict> [ <prev_aligned> <prev_gnulls>] \n";
	}
} elsif ($ARGV[0] eq "olist_tree_from_rules") {
	if ($#ARGV==2) {
		cl_olist_tree_from_rules $ARGV[1],$ARGV[2];
	} else {
		print "Usage: olist_tree_from_rules <rules_prefix> <tree_prefix>\n";
	}
} elsif ($ARGV[0] eq "olist_fast_word") {
	if ($#ARGV==3) {
		cl_olist_fast_word $ARGV[1],$ARGV[2],$ARGV[3];
	} else {
		print "Usage: olist_fast_word <word> <tree_prefix> <gnulls>\n";
	}
} elsif ($ARGV[0] eq "olist_fast_file") {
	if ($#ARGV==4) {
		cl_olist_fast_file $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage: olist_fast_file <wordlist> <tree_prefix> <gnulls> <newdict>\n";
	}
} elsif ($ARGV[0] eq "restrict_rules") {
	if ($#ARGV==4) {
		cl_restrict_rules $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage: restrict_rules <in_rules> <numseen> <cutoff> <out_rules>\n";
		print "       Only retain rules created by more than <cutoff> samples. Start restricting when at least <numseen> samples of weaker rule seen\n";
	}
} elsif ($ARGV[0] eq "id_pos_errors") {
	if ($#ARGV==7) {
		cl_id_pos_errors $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5],$ARGV[6],$ARGV[7];
	} else {
		print "Usage: id_pos_errors <in_rules> <in_singles> <cnt_if> <cutoff> <cut_errors> <out_rules>\n";
	}
} elsif ($ARGV[0] eq "id_pos_errorwords") {
	if ($#ARGV==5) {
		cl_id_pos_errorwords $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4],$ARGV[5];
	} else {
		print "Usage: id_pos_errorwords <in_singles> <cntif_net_lessthan> <cntif_match_lessthan> <cutoff_numrules> <out_errors>\n";
	}
} elsif ($ARGV[0] eq "pos_groups_from_rules") {
	if ($#ARGV==3) {
		cl_pos_groups_from_rules $ARGV[1],$ARGV[2],$ARGV[3];
	} else {
		print "Usage: pos_groups_from_rules <in_rules> <mingroupsize> <out_groups>\n";
	}
} elsif ($ARGV[0] eq "pos_groups_from_pats") {
	if ($#ARGV==4) {
		cl_pos_groups_from_pats $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage: pos_groups_from_pats <in_rules> <maxcontext> <mingroupsize> <out_groups>\n";
	}
} elsif ($ARGV[0] eq "find_rules_withgroups_single_large") {
	if ($#ARGV==4) {
		cl_fgen_rules_withgroups_single_large $ARGV[1],$ARGV[2],$ARGV[3],$ARGV[4];
	} else {
		print "Usage:  find_rules_withgroups_single_large <g> <groups> <in_patts> <out_rules>\n";
	}
} elsif ($ARGV[0] eq "kmeans") {
	if ($#ARGV==3) {
		cl_kmeans $ARGV[1],$ARGV[2],$ARGV[3];
	} else {
		print "Usage:  kmeans <in_groups> <numgroups> <out_groups>\n";
	}
} else { print_usage }

#--------------------------------------------------------------------------
