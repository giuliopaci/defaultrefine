package g2pGroups;

use g2pOlist;
use g2pRulesHelper;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;
	$msg = 0;
	%glist;
	
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&id_pos_groups_from_rules &id_pos_groups_from_pats &fwrite_groups &fgen_rules_withgroups_single_large &do_kmeans);
}

#--------------------------------------------------------------------------

sub convert_groups(\%\%) {
	#convert group list
	#from format oldp->{template}{phoneme}{grapheme}
	#to format newp->{list of graphems in group:list of graphemes excluded}{template:outcome}
	my ($oldp,$newp)=@_;
	foreach my $template (keys %{$oldp}) {
		foreach my $p (sort keys %{$oldp->{$template}}) {
			my %conflictlist=();
			my @glist = sort keys %{$oldp->{$template}{$p}};
			my $gstr = join '',@glist;
			foreach my $p2 (keys %{$oldp->{$template}}) {
				next if $p eq $p2;
				my @g2list = keys %{$oldp->{$template}{$p2}};
				foreach my $g2 (@g2list) {
					$conflictlist{$g2}=1;
				}
			}
			my $conflictstr = join '',keys %conflictlist;
			$template =~ s/ /#/;
			$newp->{"$gstr:$conflictstr"}{"${template}:$p"}=1;
		}
	}
}	


sub fwrite_groups(\%$$) {
	#write groups in format:
	#	list of graphemes in group:list of graphemes excluded; template:outcome; template:outcome; ...
	
	my ($groupp,$mingroupsize,$oname) = @_;
	open OH, ">$oname" or die "Error opening $oname\n";

	foreach my $group (sort {length $a <=> length $b} keys %{$groupp}) {
		my ($in,$out) = split /:/,$group;
		if (length $in>=$mingroupsize) {
			my $displaygroup = $group;
			$displaygroup =~ s/ /#/g;
			print OH "$displaygroup;";	
			foreach my $template (keys %{$groupp->{$group}}) {
				printf OH "$template;";
			}
			printf OH "\n";
		}
	}
	close OH
}


sub fread_groups($\%) {
	#read groups in format:
	#	list of graphemes in group:list of graphemes excluded; template:outcome; template:outcome; ...
	#	into newp->{list of graphems in group:list of graphemes excluded}{template:outcome}

	my ($iname,$groupp)=@_;
	open IH, "$iname" or die "Error opening $iname";
	%glist=();
	while (<IH>) {
		chomp;
		my @line = split ";",$_;
		my $group = shift @line;
		foreach my $template (@line) {
			$groupp->{$group}{$template}=1;
		}
		my ($in,$out)=split $group;
		my @inlist = split //,$in;
		push @inlist, split //,$out;
		foreach my $i (@inlist) {
			$glist{$i}=1;
		}
	}
}

#--------------------------------------------------------------------------

sub mk_wildpats($$\%) {
	
	#Create a list of wild patterns from a single input rule
	#Store in format {template}{phoneme}{grapheme}=cnt
	#where cnt the number of times that a grapheme is seen in the context of template (always 1 when run on rules)
	
	my ($inpat,$p,$wildp) = @_;
	if ($inpat !~ /(.*)(-.-)(.*)/) {
		die "Error: format of <inpat> in mk_wildpat\n";
        }
        $numleft=length $1;
        $numright=length $3;
        my @rstr = split //,$inpat;
        foreach my $i (0..$numleft-1) {
                @tmpstr = @rstr;
                $tmpstr[$i]= ".";
                $tmprule = join "",@tmpstr;
                $wildp->{$tmprule}{$p}{$rstr[$i]}++;
        }
        foreach my $i ($numleft+3..$numleft+$numright+2) {
                @tmpstr = @rstr;
                $tmpstr[$i]= ".";
                $tmprule = join "",@tmpstr;
                $wildp->{$tmprule}{$p}{$rstr[$i]}++;
        }
}

sub id_pos_groups_from_rules($$$) {

	#Read ruleset from file
	#Identify possible groups and write to file if groupsize larger than or euqal to cutoff
	#in format:  "template: g1,g2,g3,..."

	my ($iname,$mingroupsize,$oname) = @_;
	print "-- Enter id_pos_groups: $iname,$oname\n" if $debug;
	fread_rules_olist($iname);
	my %wildpats=();
	foreach my $r (keys %rule) {
		mk_wildpats($r,$rule{$r},%wildpats); 
	}
	convert_groups(%wildpats,%writepats);
	fwrite_groups(%writepats,$mingroupsize,$oname);
}

sub id_pos_groups_from_pats($$$$) {
	my ($iname,$maxcontext,$mingroupsize,$oname) = @_;
	my %gpatts=();
	my %gwords=();
	my %wildpats=();
	fread_gpatts_limit(1,$maxcontext,%gpatts,%gwords,$iname);
	foreach my $r (keys %gpatts) {
		foreach my $p (keys %{$gpatts{$r}}) {
			mk_wildpats($r,$p,%wildpats); 
		}
	}
	convert_groups(%wildpats,%writepats);
	fwrite_groups(%writepats,$mingroupsize,$oname);
}

#--------------------------------------------------------------------------


sub expand_rule(\@$) {
	my ($groupp,$rule)=@_;
	my @rulelist=();
	if ($rule =~ /^(.*)<([0-9]*)>(.*)$/) {
		my @replacelist = split //,$groupp->[$2];
		foreach my $r (@replacelist) {
			push @rulelist, "$1$r$3";
		}
	} else {
		push @rulelist,$rule;
	}
	return @rulelist;
}

sub get_phones(\@\%) {
	my ($patp,$posp)=@_;
	my %phonelist=();
	foreach my $pat (@$patp) {
		if (exists $posp->{$pat}) {
			foreach my $phone (keys %{$posp->{$pat}}) {
				$phonelist{$phone}=1;
			}
		}
	}
	return keys %phonelist;
}

sub get_top_pats_withgroups($\@\%\%$\@) {
	#Find next pat to add as rule
	my ($g,$groupp,$posp,$caughtp,$pp,$nrlp)=@_;
	my $max=0;
	my $maxsize=100;
	my $mingroupsize=100;
	my $maxpat="";
	my $maxp="";
	my $found=0;
	@$nrlp=();
	my $nr="";
	foreach my $pat (keys %$posp) {
		my @patlist = expand_rule(@$groupp,$pat);
		my @phonelist = get_phones(@patlist,%$posp);
		foreach my $p (@phonelist) {
			my $gtot=0;
			foreach my $newpat (@patlist) {
				$gtot += $posp->{$newpat}{$p};
				my $confp=$caughtp->{$newpat};
				foreach my $pc (keys %{$confp}) {
					next if $pc eq $p;
					$gtot-= $confp->{$pc};
				}
			}
			my $size=(length $pat)-2;
			my $groupsize = scalar @patlist;
			if 	( ($gtot>$max)||
				  (($gtot==$max)&&($gtot>0)&&($size<$maxsize))||
				  (($gtot==$max)&&($gtot>0)&&($size==$maxsize)&&($groupsize<$mingroupsize))||
				  (($gtot==$max)&&($gtot>0)&&($size==$maxsize)&&($groupsize==$mingroupsize)&&(get_sym($pat)<get_sym($maxpat) )) ||
				  (($gtot==$max)&&($gtot>0)&&($size==$maxsize)&&($groupsize==$mingroupsize)&&(get_sym($pat)==get_sym($maxpat) ))&&
																	(right_first($pat)>(right_first($maxpat)))) {
				$max=$gtot;
				$maxp=$p;
				$maxpat=$pat;
				$maxsize=$size;
				$mingroupsize = $groupsize;
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

sub get_words_per_pat_conflict_withgroups($\@\%$) {
	my ($newpat,$groupp,$wp,$p)=@_;
	my @wlist=();
	my @patlist = expand_rule(@{$groupp},$newpat);
	foreach my $pat (@patlist) {
		foreach my $w (keys %$wp) {
			if ((!($wp->{$w} eq $p))&&($w =~ /$pat/)) {
				push @wlist,$w;
			}
		}
	}
	return @wlist;
}

sub get_words_per_pat_match_withgroups($\@\%$) {
	my ($newpat,$groupp,$wp,$p)=@_;
	my @wlist=();
	my @patlist = expand_rule(@{$groupp},$newpat);
	foreach my $pat (@patlist) {
		foreach my $w (keys %$wp) {
			if (($wp->{$w} eq $p)&&($w =~ /$pat/)) {
				push @wlist,$w;
			}
		}
	}
	return @wlist;
}

#
#sub rm_from_rulelist(\%$$) {
#	#Delete rule after rule removed from caughtlist
#	my ($words_notp,$nr,$g)=@_;
#	my $p  = $rule{$nr};
#	delete $rule{$nr};
#	foreach my $ri (1..$#{$rorder{$g}}) {
#		if ($rorder{$g}[$ri] eq $nr) {
#			$rorder{$g}[$ri]=-1;
#			last;
#		}
#	}
#	#Add patterns previously conflicting with rule, but now possible
#	#(Other patts automatically added in next step.) 
#	my @words_possible_nr=get_words_per_pat_conflict($nr,%$words_notp,$p);
#	foreach my $w (@words_possible_nr) {
#		$pc = $words_notp->{$w};
#		$posp->{$nr}{$pc}++;
#	}
#}


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


sub rules_frompats_withgroups_olist_large($\@$\%\%$) {
	#Extract the best <$g>-specific rulegroups based on the set of patterns in <$gpatp>
	#Update globals %rule, %rorder and %numfound
	my $find_single=0;		#find rules caused by single words - used during error detection
	my $id_single=1;		#used when find_single=1. Number of words allowed while rule still identified as single
	my $fromsize=1;		#$fromsize usually 1 unless testing with fixed context size, then 0
	my $ngram=0;		#used when calculating n-gram probs. Probably best to do this separately, not during rule extraction
	
	my ($g,$groupp,$cmax,$possiblep,$words_notp,$rulefile) = @_;
	print "<p>-- Enter rulegroups_from_pats_olist_large [$g] [$cmax]\n" if $debug;
	
	if ($ngram==1) {
		#temporary file created to write probabilities - integrate better once tested
		open TH, ">$rulefile.prob" or die "Error opening $rulefile.prob";
		if ($find_single==1) {
			open EH, ">$rulefile.single" or die;
		}
	}
	
	my $cwin=2;
	$grulenum=1;
	my %words_done=();
	my %caught=();
	my $from=1;
	my $to=$cmax;
	my $displaycnt;
	
	my $busy=get_top_pats_withgroups($g,@$groupp,%$possiblep,%caught,\$p,@newrules);
	while ($busy==1) {
		foreach my $nr (@newrules){
			print "$g:\t[$grulenum]\t[$nr] --> [$p]"; #if $msg;
			$rule{$nr}=$p;
			$rorder{$g}[$grulenum]=$nr;
			
			my @replacewords=get_words_per_pat_conflict_withgroups($nr,@$groupp,%words_done,$p);
			my @new_words=get_words_per_pat_match_withgroups($nr,@$groupp,%$words_notp,$p);
			#my @overwords=get_words_per_pat_match_withgroups($nr,%words_done,$p);
			
			if ($ngram==1) {
				#when calculating n-gram probabilities
				my $nummatch = scalar get_words_per_pat_match_withgroups($nr,@$groupp,%words_done,$p);
				my $numconflict =scalar get_words_per_pat_conflict_withgroups($nr,@$groupp,%$words_notp,$p);
				$numconflict += scalar @replacewords;
				$nummatch += scalar @new_words;
				my $prob=0;
				if (($nummatch+$numconflict)!=0) {
					$prob = ($nummatch*100.0) / ($nummatch+$numconflict);
				}
				printf TH "%s;%s;%s;%s;%d;%.2f\n",$g,$1,$2,$p,$grulenum,$prob;
			}
			
			$displaycnt = $#new_words-$#replacewords;
			print "\t$displaycnt\n"; #if $msg;
			$numfound{$nr}=$displaycnt;
	
			$nr =~ /^(.*)-.-(.*)$/;
			#print OH "$g;$1;$2;$p;$grulenum;$displaycnt\n";
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
			if (exists $possiblep->{$nr}) {
				my $nrp=$possiblep->{$nr};
				my @plist = keys %{$nrp};
				foreach my $pc (@plist) {
					delete $nrp->{$pc};
				}
				delete $possiblep->{$nr};
			}
		}		
		$busy=get_top_pats_withgroups($g,@$groupp,%$possiblep,%caught,\$p,@newrules);
		my $nr = $newrules[$#newrules];
		
		if ($busy==1){
			my $newlen = (length $nr)-2;
			my $limit_size=0;
			#don't increase context size while testing effect of limiting context size - use limit_size==1
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
	close TH;
}

sub possible_grule($$$\%) {
	my ($left,$right,$group,$gpatp)=@_;
	my @glist = split //,$group;
	my %cnt=();
	foreach my $g (@glist) {
		my $pat="$left$g$right";
		if (exists $gpatp->{$pat}) {
			foreach my $p (keys %{$gpatp->{$pat}}) {
				$cnt{$p}{$g}++;
			}
		}
	}
	foreach my $p (keys %cnt) {
		my @glist = keys %{$cnt{$p}};
		if (scalar @glist > 1) {
			print "Possible rule: $left<$group>$right -> $p\n" if $debug;
			return 1;
		}
	}
	print "No rule: $left<$group>$right\n" if $debug;
	return 0;
}

sub add_group_patts(\%\@) {
	my ($gpatp,$groupp)=@_;
	my %gindex=();
	foreach my $i (0..$#$groupp) {
		my $g = $groupp->[$i];
		my @letters = split //,$g;
		foreach my $l (@letters) {
			$gindex{$l}{$g}=$i;
		}
	}
	foreach my $pat (keys %$gpatp) {
		my $focus = (index $pat,"-")+1;
		my @letters = split //,$pat;
		foreach my $i (0..$#letters) {
			next if $i == $focus;
			my $l = $letters[$i];
			if (exists $gindex{$l}) {
				my $left = substr $pat,0,$i;
				my $right = substr $pat,$i+1;
				foreach my $g (keys %{$gindex{$l}}) {
					if (possible_grule($left,$right,$groupp->[$gindex{$l}{$g}],%$gpatp)==1) {
						$gpatp->{"$left<$gindex{$l}{$g}>$right"} = $gpatp->{$pat};
					}
				}
			}
		}
	}
}

sub fgen_rules_withgroups_single_large($$$$) {
        my ($g,$groupsfile,$pattsfile,$rulefile)=@_;
        %rule=();
        %rulecnt=();
        %numfound=();
        my %gpatts=();
        my %gwords=();
        my $found=0;

	if (-e $pattsfile) {
                my $fromsize=1;
                my $tosize=40;
                #normal $fromsize=1; $tosize=8
                #tosize can be larger if sufficient memory available
                #set fromsize=0 only while testing effect of context size
                fread_gpatts_limit($fromsize,$tosize,%gpatts,%gwords,$pattsfile);
                my @cntwords = keys %gwords;
                if (scalar @cntwords > 0) {
                        my $wnum=$#cntwords+1;
                        print "Finding best rules for [$g] [$wnum]\n";
			my @groups=();
			fread_array(@groups,$groupsfile);
			add_group_patts(%gpatts,@groups);
                        rules_frompats_withgroups_olist_large($g,@groups,$tosize,%gpatts,%gwords,$rulefile);
                        $found=1;
                }
        }
        if ($found==0) {
                $rule{"-$g-"} = "0";
                $rorder{$g}[0]="-$g-";
                $numfound{"-$g-"}=0;
                print "$g:\t[0]\t[-$g-] --> 0\n"; 
        }
}

#--------------------------------------------------------------------------

sub init_proto(\%$\%) {
	my ($groupp,$num,$protop)=@_;
	my %random=();
	foreach my $g (keys %{$groupp}) {
		$random{$g}=1;
	}
	my @rlist = keys %random;
	foreach my $i (1..$num) {
		$protop->{$rlist[$i]}{'dummy'}=1;
	}
}

sub get_distance($$) {
	my ($v1,$v2) = @_;
	#print "Entering get_distance: [$v1] and [$v2]\n";
	my ($in1,$out1) = split /:/,$v1;
	my ($in2,$out2) = split /:/,$v2;
	#my $allstr = $in1 . $out1 . $in2 . $out2;
	#my $allstr = $in1 . $in2;
	#my @all = split //,$allstr;
	#my %cnt=();
	#foreach my $g (@all) {
	#	$cnt{$g}=1;
	#}
	my $match=0;
	my $total = scalar keys %glist;
	foreach my $g (keys %glist) {
		if (($in1 =~ /$g/) && ($in2 =~ /$g/)) {$match++;}
		if (($out1 =~ /$g/) && ($out2 =~ /$g/)) {$match++;}
		if (($in1 =~ /$g/) && ($out2 =~ /$g/)) {$match--;}
		if (($out1 =~ /$g/) && ($in2 =~ /$g/)) {$match--;}
	}
	return 1.0 - ($match/$total);
}

sub assign_vectors(\%\%) {
	my ($groupp,$clusterp)=@_;
	foreach my $proto (keys %{$clusterp}) {
		foreach my $v (keys %{$clusterp->{$proto}}) {
			delete $clusterp->{$proto}{$v};
		}
	}
	foreach my $v (keys %{$groupp}) {
		my $closest = 100;
		my $best = "";
		foreach my $proto (keys %{$clusterp}) {
			my $score = get_distance($v,$proto);
			if ($score <= $closest) {
				$closest = $score;
				$best = $proto;
			}
		}
		$clusterp->{$best}{$v}=1;
	}
}

sub update_proto(\%\%) {
	my ($groupp,$clusterp)=@_;
	my $busy=0;
	foreach my $proto (keys %{$clusterp}) {
		%cnt_in = ();
		%cnt_out = ();
		my $cnt_mem;
		my $randomv="";
		foreach my $member (keys %{$clusterp->{$proto}}) {
			my ($in,$out) = split /:/,$member;
			my @inlist = split //,$in;
			foreach my $i (@inlist) {
				$cnt_in{$i}++;
			}
			my @outlist = split //,$out;
			foreach my $o (@outlist) {
				$cnt_out{$o}++;
			}
			$cnt_mem++;
			$randomv=$member;
		}
		$new_in="";
		foreach my $i (sort keys %cnt_in) {
			if ($cnt_in{$i}>=$cnt_mem/4) {
				$new_in = $new_in . "$i";
			}
		}
		$new_out="";
		foreach my $o (sort keys %cnt_out) {
			if (($cnt_out{$o}>=$cnt_mem/2)&&($new_in !~ /$o/)) {
				$new_out = $new_out . "$o";
			}		
		}
		my $newproto = "$new_in:$new_out";
		if (($newproto eq ":")) {
			$newproto = $randomv;
		}
		if (!($proto eq $newproto)) {
			$busy=1;
			foreach my $v (keys %{$clusterp->{$proto}}) {
				delete $clusterp->{$proto}{$v};
				delete $clusterp->{$proto};
				$clusterp->{$newproto}{$v}=1;
			}
		}
	}
	return $busy;
}


sub update_proto_v2(\%\%) {
	my ($groupp,$clusterp)=@_;
	my $busy=0;
	foreach my $proto (keys %{$clusterp}) {
		
		%all=();
		my $randomv="";
		foreach my $member (keys %{$clusterp->{$proto}}) {
			my ($in,$out) = split /:/,$member;
			my @inlist = split //,$in;
			foreach my $i (@inlist) {
				$all{$i}++;
			}
			$randomv=$member;
		}
		
		my $cnt_for=0;
		my $cnt_against=0;
		foreach  my $g (keys %all) {
			foreach my $member (keys %{$clusterp->{$proto}}) {
				my ($in,$out) = split /:/,$member;
				my @inlist = split //,$in;
				if ($in =~ /$g/) {
					$cnt_for += 1;
				}
			}
		}
		my $newproto = "$new_in:$new_out";
		if (($newproto eq ":")) {
			$newproto = $randomv;
		}
		if (!($proto eq $newproto)) {
			$busy=1;
			foreach my $v (keys %{$clusterp->{$proto}}) {
				delete $clusterp->{$proto}{$v};
				delete $clusterp->{$proto};
				$clusterp->{$newproto}{$v}=1;
			}
		}
	}
	return $busy;
}


sub show_groups(\%) {
	my $groupp = shift @_;
	my $num=1;
	foreach my $proto (keys %{$groupp}) {
		print "$num]\t$proto\t:";
		foreach my $v (keys %{$groupp->{$proto}}) {
			print "$v;";
		}
		print "\n";
		$num++;
	}
}

sub do_kmeans($$$) {
	my ($infile,$num,$outfile)=@_;
	fread_groups($infile,%groups);
	my $busy=1;
	my %clusters=();
	print "Assign prototypes\n";
	init_proto(%groups,$num,%clusters);
	show_groups(%clusters);
	while ($busy==1) {
		print "Assign vectors\n";
		assign_vectors(%groups,%clusters);
		print "Show groups\n";
		show_groups(%clusters);
		print "Update prototypes\n";
		$busy = update_proto(%groups,%clusters);
		show_groups(%clusters);
	}
	fwrite_groups(%clusters,1,$outfile);
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

