package g2pVariants;

use g2pAlign;
use g2pRulesHelper;

#use strict;

#--------------------------------------------------------

BEGIN {
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&do_combine &do_separate &do_compare &do_calc_restrict);
}

 #--------------------------------------------------------

sub print_usage() {
	print "Usage: do_variants.pl combine <in_dict> <out_prefix> \n";
	print "       Combines variants in new dict. Assumes verified dictionary - other entries ignored \n\n";
	print "       do_variants.pl separate <in_dict> <mapfile> <restrictfile> <out_dict> \n";
	print "       Generate a new dict with separate variants based on mapfile \n\n";
	print "       do_variants.pl compare <dict_new> <dict_ref> <result> \n";
	print "       Compare two dictionaries with regard to variants only (common;missing;extra)\n\n";
	print "       do_variants.pl calc_restrict <mapfile> <dict_orig> <dict_rewrite> <restrict_file>\n";
	print "       Calculate restrictions in generating variants\n";
}

#--------------------------------------------------------

sub do_separate_v1($$$$) {
	#Working version if only 2 variants (used for OALD, changed for Fonilex - see do_separate below)
        my ($iname,$mname,$rname,$oname) = @_;
	print "Generating variants: \n- from dictionary: $iname\n- map file: $mname\n- restrict file: $rname\n- output dictionary: $oname\n";
        open IH, "<:encoding(utf8)", "$iname" or die "Cannot open $iname";
        open MH, "<:encoding(utf8)", "$mname" or die "Cannot open $mname";
        open RH, "<:encoding(utf8)", "$rname" or die "Cannot open $rname";
	open OH, ">:encoding(utf8)", "$oname" or die "Cannot open $oname";
	open SH, ">:encoding(utf8)", "$oname.stat" or die "Cannot open $oname.stat";
	
	my %mlist=();
	while (<MH>) {
		chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in map file: @line\n";
		}
		my $p0=$line[0];
		my $p1=$line[1];
		my $p2=$line[2];
		
		#$p1 =~ s/0//g;
		$p1 =~ s/^ //;
		$p1 =~ s/ $//;
		
		#$p2 =~ s/0//g;
		$p2 =~ s/^ //;
		$p2 =~ s/ $//;
		
		$mlist{$p0}{$p1}=1;
		$mlist{$p0}{$p2}=1;
	}
	close MH;
	
	my %rlist=();
	while (<RH>) {
		chomp;
		my @line = split /;/,$_;
		foreach my $i (1..$#line) {
			my $rstr = $line[$i];
			#$rstr =~ s/0//g;
			$rstr =~ s/^ //;
			$rstr =~ s/ $//;
			$rlist{$line[0]}{$rstr}=1;
		}
	}
	close RH;

	while (<IH>) {
                chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in dict file: @line\n";
		}
		my $foundvar=0;
		my $word = $line[0];
		my $sound = $line[1];
		my $verdict = $line[2];
		
		my @phon = split //,$sound;
		my @varlist=();
		foreach my $i (0..$#phon) {
			my $p=$phon[$i];
			if (exists $mlist{$p}) {
				push @varlist,$p;
				$foundvar=1;
			}
		}
		if ($foundvar==1) {
			my $varstr=join "",@varlist;
			my @dupvarlist = @varlist;
			my @all_expansions=();
			my $v1 = shift @dupvarlist;
			foreach my $v2 ( keys %{$mlist{$v1}} ) {
				push @all_expansions,$v2;
			}
			foreach my $p (@dupvarlist) {
				my $nume = $#all_expansions;
				foreach my $i (0..$nume) {
					my $estr = shift @all_expansions;
					foreach my $v (keys %{$mlist{$p}}) {
						push @all_expansions, "$estr $v";
					}
				}
			}
		
			my %done=();
			foreach my $estr (@all_expansions) {
				$estr =~ s/^ //;
				$estr =~ s/ $//;
				next if exists $done{$estr};
				my @newphon = @phon;
				if ( ((length $varstr)==1) || (exists $rlist{$varstr}{$estr}) ) {
					my @elist = split / /,$estr;
					my $j=0;
					foreach my $i (0..$#newphon) {
						if ($newphon[$i] eq $varlist[$j]) {
							$newphon[$i]= $elist[$j];
							$j++;
							
						}
						last if $j > $#varlist;
					}
					my $phonstr = join "",@newphon;
					$phonstr =~ s/0//g;
					print OH "$word;$phonstr;1\n";
					print SH "$word;$phonstr;1\n";
					#print "HERE $phonstr [$estr]\n";
				}
				$done{$estr}=1;
			}
		} else {
			print OH "$word;$sound;1\n";
		}
	}
	
	close IH;
	close OH;
	close SH;
}


sub do_separate($$$$) {
        my ($iname,$mname,$rname,$oname) = @_;
	print "Generating variants: \n- from dictionary: $iname\n- map file: $mname\n- restrict file: $rname\n- output dictionary: $oname\n";
        open IH, "<:encoding(utf8)", "$iname" or die "Cannot open $iname";
        open MH, "<:encoding(utf8)", "$mname" or die "Cannot open $mname";
        open RH, "<:encoding(utf8)", "$rname" or die "Cannot open $rname";
	open OH, ">:encoding(utf8)", "$oname" or die "Cannot open $oname";
	open SH, ">:encoding(utf8)", "$oname.stat" or die "Cannot open $oname.stat";
	
	my %mlist=();
	while (<MH>) {
		chomp;
		my @line = split /;/,$_;
		my $vari = shift @line;
		my $varval = join ";",@line;
		$mlist{$vari}=$varval;
		
		#$p1 =~ s/0//g;
		#$p1 =~ s/^ //;
		#$p1 =~ s/ $//;
		
		#$p2 =~ s/0//g;
		#$p2 =~ s/^ //;
		#$p2 =~ s/ $//;
	}
	close MH;
	
	my %rlist=();
	while (<RH>) {
		chomp;
		my @line = split /;/,$_;
		foreach my $i (1..$#line) {
			my $rstr = $line[$i];
			#$rstr =~ s/0//g;
			#$rstr =~ s/^ //;
			#$rstr =~ s/ $//;
			$rlist{$line[0]}{$rstr}=1;
		}
	}
	close RH;

	while (<IH>) {
                chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in dict file: @line\n";
		}
		my $foundvar=0;
		my $word = $line[0];
		my $sound = $line[1];
		my $verdict = $line[2];
		
		my @phon = split //,$sound;
		my @varlist=();
		foreach my $i (0..$#phon) {
			my $p=$phon[$i];
			if (exists $mlist{$p}) {
				push @varlist,$p;
				$foundvar=1;
			}
		}
		if ($foundvar==1) {
			my $varstr=join "",@varlist;
			my @dupvarlist = @varlist;
			my @all_expansions=();
			my $v1 = shift @dupvarlist;
			foreach my $p (split /;/,$mlist{$v1}) {
				push @all_expansions,$p;
			}
			foreach my $v2 (@dupvarlist) {
				my $nume = $#all_expansions;
				foreach my $i (0..$nume) {
					my $estr = shift @all_expansions;
					foreach my $p (split /;/,$mlist{$v2}) {
						push @all_expansions, "$estr;$p";
					}
				}
			}
		
			my %done=();
			foreach my $estr (@all_expansions) {
				#$estr =~ s/^ //;
				#$estr =~ s/ $//;
				next if exists $done{$estr};
				my @newphon = @phon;
				if ( ((length $varstr)==1) || (exists $rlist{$varstr}{$estr}) ) {
					my @elist = split /;/,$estr;
					my $j=0;
					foreach my $i (0..$#newphon) {
						if ($newphon[$i] eq $varlist[$j]) {
							$newphon[$i]= $elist[$j];
							$j++;
							
						}
						last if $j > $#varlist;
					}
					my $phonstr = join "",@newphon;
					$phonstr =~ s/0//g;
					print OH "$word;$phonstr;1\n";
					print SH "$word;$phonstr;1\n";
					#print "HERE $phonstr [$estr]\n";
				}
				$done{$estr}=1;
			}
		} else {
			print OH "$word;$sound;1\n";
		}
	}
	
	close IH;
	close OH;
	close SH;
}

#--------------------------------------------------------

sub do_count($$) {
	my ($iname,$oname) = @_;
	print "Counting variants: \n- from dictionary: $iname\n- output: $oname\n";
	open IH, "<:encoding(utf8)", "$iname" or die "Cannot open $iname";
	open OH, ">:encoding(utf8)", "$oname" or die "Cannot open $oname";

	walign_init_probs;
	my %wlist=();
	my %wcnt=();
	my %varcnt=();
	while (<IH>) {
		chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in dict file: @line\n";
		}
		my $word = $line[0];
		my $sound = $line[1];
		my $verdict = $line[2];
		if ($verdict==1) {
			$wcnt{$word}++;
			if (!(exists $wlist{$word})) {
				@{$wlist{$word}}=();
			}
			push @{$wlist{$word}}, $sound;
		}
	}
	close IH;
	
	foreach my $w (keys %wlist) {
		if ($wcnt{$w}>1) {
			if ($wcnt{$w}>2) {
				print "Warning: more than two variants\n";
			} else {
				printf("\n%d;%s",$wcnt{$w},$w);
				foreach my $var (@{$wlist{$w}}) {
					printf(";%s",$var);
				}
				my $var1 = $wlist{$w}[0];
				my $var2 = $wlist{$w}[1];
				my @seq1 = split //,$var1;
				my @seq2 = split //,$var2;
				if ($#seq1 < $#seq2) {
					walign_word(@seq2,@seq1);
				} else {
					walign_word(@seq1,@seq2);
				}
				my $prevvar=0;
				my $p1="";
				my $p2="";
				foreach my $i (0..$#seq1) {
					if (!($seq1[$i] eq $seq2[$i])) {
						$p1 = $p1.$seq1[$i];
						$p2 = $p2.$seq2[$i];
						$prevvar=1;
					} else {
						if ($prevvar==1) {
							if (($p1 cmp $p2) < 1 ) {
								$varcnt{$p1}{$p2}++;
								print "\t$p1\t$p2";
							} else {
								$varcnt{$p2}{$p1}++;
								print "\t$p2\t$p1";
							}
							$prevvar=0;
							$p1="";
							$p2="";
						}
					}
				}
				if ($prevvar==1) {
					if (($p1 cmp $p2) < 1 ) {
						$varcnt{$p1}{$p2}++;
						print "\t$p1\t$p2";
					} else {
						$varcnt{$p2}{$p1}++;
						print "\t$p2\t$p1";
					}
				}
			}
		}
	}
	
	my %printcnt=();
	foreach my $p1 (keys %varcnt) { 
		foreach my $p2 (keys %{$varcnt{$p1}}) {
			$printcnt{$varcnt{$p1}{$p2}}{$p1}=$p2;
		}
	}
	
	foreach my $cnt (sort {$b <=> $a} keys %printcnt) { 
		foreach my $p1 (keys %{$printcnt{$cnt}}) {
			printf OH ("%d\t%s\t%s\n",$cnt,$p1,$printcnt{$cnt}{$p1});
		}
	}
	close OH;
}

#--------------------------------------------------------

#sub get_var_name_v1($$\%\$\%) {
#	#Working version if maximum of 2 variants per word
#	my ($p1,$p2,$plistp,$pcntp,$newlistp)=@_;
#	my %notallowed=();
#	$notallowed{166}=1;
#	$notallowed{167}=1;
#	#$notallowed{172}=1;
#	if (exists $newlistp->{$p1}{$p2}) {
#		return $newlistp->{$p1}{$p2};
#	} elsif (exists $newlistp->{$p2}{$p1}) {
#		return $newlistp->{$p2}{$p1};
#	} else {
#		while ((exists $plistp->{chr($$pcntp)})||(exists $notallowed{$$pcntp})) {
#			$$pcntp++;
#		}
#		$newlistp->{$p1}{$p2} = chr($$pcntp);
#		my $show = chr($$pcntp);
#		#print "HERE\t$$pcntp\t$show\n";
#		return chr($$pcntp);
#	}
#}

sub get_var_name(\@\%\$\%) {
	#Working version if maximum of 2 variants per word
	my ($varlistp,$plistp,$pcntp,$newlistp)=@_;
	my %notallowed=();
	$notallowed{166}=1;
	$notallowed{167}=1;
	my $varname = join ";",sort @$varlistp;
	if (exists $newlistp->{$varname}) {
		return $newlistp->{$varname};
	} else {
		while ((exists $plistp->{chr($$pcntp)})||(exists $notallowed{$$pcntp})) {
			$$pcntp++;
		}
		$newlistp->{$varname} = chr($$pcntp);
		my $show = chr($$pcntp);
		#print "HERE\t$$pcntp\t$show\n";
		return chr($$pcntp);
	}
}

#sub do_combine_v1($$$) {
#	#previous version: combined 2 or more variant phones as one
#	my ($iname,$phons,$oname) = @_;
#	print "Formatting variants: \n- from dictionary: $iname\n- output: $oname.*\n";
#	open IH, "<:encoding(utf8)", "$iname" or die "Cannot open $iname";
#	open IPH, "<:encoding(utf8)", "$phons" or die "Cannot open $phons";
#	open CH, ">:encoding(utf8)", "$oname.cnt" or die "Cannot open $oname.cnt";
#	open LH, ">:encoding(utf8)", "$oname.log" or die "Cannot open $oname.log";
#	open DH, ">:encoding(utf8)", "$oname.dict" or die "Cannot open $oname.dict";
#	open AH, ">:encoding(utf8)", "$oname.aligned" or die "Cannot open $oname.aligned";
#	open MH, ">:encoding(utf8)", "$oname.map" or die "Cannot open $oname.map";
#	open PH, ">:encoding(utf8)", "$oname.phones" or die "Cannot open $oname.phones";
#
#	my %plist=();
#	while (<IPH>) {
#		chomp;
#		$plist{$_}=1;
#	}
#	close IPH;
#	
#	my %wlist=();
#	my %wcnt=();
#	while (<IH>) {
#		chomp;
#		my @line = split /;/,$_;
#		if (@line!=3) {
#			die "Error in aligned dict file: @line\n";
#		}
#		my $word = $line[0];
#		my $phons = $line[2];
#		$wcnt{$word}++;
#		if (!(exists $wlist{$word})) {
#			@{$wlist{$word}}=();
#		}
#		push @{$wlist{$word}}, $phons;
#	}
#	close IH;
#	
#	# Identify variants and store in %changed  -- according to $changed{new_phone}{relevant_word} = 1
#	# search for unused phones by starting from $newnum
#	# %plist - full list of phones in use at each stage
#	# %newlist - new pseudo-phones created
#	
#	my $newnum = 162;
#	my %newlist = ();
#	my %changed = ();
#	
#	foreach my $w (sort keys %wlist) {
#		if ($wcnt{$w}>1) {
#			if ($wcnt{$w}>2) {
#				print "Error: more than two variants\n";
#			} else {
#				my $var1 = $wlist{$w}[0];
#				my $var2 = $wlist{$w}[1];
#				my @seq1 = split / /,$var1;
#				my @seq2 = split / /,$var2;
#				if ($#seq1 != $#seq2) {
#					die "Error in alignment of [@seq1] and [@seq2]\n";
#				}
#				my $prevvar=0;
#				my $p1="";
#				my $p2="";
#				my $new_index=0;
#				my @sound=();
#				my $found=0;
#				my $multiple=0;
#				foreach my $i (0..$#seq1) {
#					if (!($seq1[$i] eq $seq2[$i])) {
#						$p1 = $p1.$seq1[$i];
#						$p2 = $p2.$seq2[$i];
#						$prevvar=1;
#						if ($found==1) {
#							$multiple=1;
#						}
#						$found=1;
#					} else {
#						if ($prevvar==1) {
#							$pnew = get_var_name($p1,$p2,%plist,$newnum,%newlist);
#							$changed{$pnew}{$w}=1;
#							$sound[$new_index]=$pnew;
#							$plist{$pnew}=1;
#							$new_index++;
#							my $numreplace=(length $p1) - 1;
#							foreach my $j  (1..$numreplace) {
#								$sound[$new_index]="0";
#								$new_index++;
#							}
#							$prevvar=0;
#							$p1="";
#							$p2="";
#						}
#						$sound[$new_index]=$seq1[$i];
#						#$plist{$seq1[$i]}=1;
#						$new_index++;
#					}
#				}
#				if ($prevvar==1) {
#					$pnew = get_var_name($p1,$p2,%plist,$newnum,%newlist);
#					$changed{$pnew}{$w}=1;
#					$sound[$new_index]=$pnew;
#					$plist{$pnew}=1;
#					my $numreplace=length $p1;
#					foreach my $j  (1..$numreplace) {
#						$new_index++;
#						$sound[$new_index]="0";
#					}
#				}
#				my $dict_entry = join "",@sound;
#				$dict_entry =~ s/0//g;
#				$dict_entry =~ s/ //g;
#				printf DH ("%s;%s;1\n",$w,$dict_entry);
#				
#				my $adict_entry_p = join " ",@sound;
#				my $adict_entry_g = join " ", (split //,$w);
#				printf AH ("%s;%s;%s\n",$w,$adict_entry_g,$adict_entry_p);
#				
#				if ($multiple==1) {
#					print "multi:\t$w;$dict_entry\n";
#				}
#			}
#		} else {
#			my $dict_entry = $wlist{$w}[0];
#			$dict_entry =~ s/0//g;
#			$dict_entry =~ s/ //g;
#			printf DH ("%s;%s;1\n",$w,$dict_entry);
#				
#			my $adict_entry_p = $wlist{$w}[0];
#			my $adict_entry_g = join " ", (split //,$w);
#			printf AH ("%s;%s;%s\n",$w,$adict_entry_g,$adict_entry_p);
#		}
#	}
#	close DH;
#	close AH;
#	
#	#Write .log and .map file	
#	my $cntwords=();
#	foreach my $p1 (keys %newlist) {
#		foreach my $p2 (keys %{$newlist{$p1}}) {
#			my $pnew = get_var_name($p1,$p2,%plist,$newnum,%newlist);
#			foreach my $w (keys %{$changed{$pnew}}) {
#				$cntwords{$pnew}++;
#				printf LH ("%s;%s;%s;%s\n",$pnew,$p1,$p2,$w);		
#			}
#			printf MH ("%s;%s;%s\n",$pnew,$p1,$p2);		
#		}
#	}
#	close LH;
#	close MH;
#	
#	#Write .cnt file	
#	foreach my $p (sort { $cntwords{$b} <=> $cntwords{$a} } keys %cntwords) { 
#		printf CH ("%s\t%d\n",$p,$cntwords{$p});		
#	}
#	close CH;
#	
#	#Write .phones file	
#	foreach my $p (sort keys %plist) {
#		print PH "$p\n";
#	}
#	close PH;
#}


sub do_combine($$$) {
	my ($iname,$phons,$oname) = @_;
	print "Formatting variants: \n- from dictionary: $iname\n- output: $oname.*\n";
	open IH, "<:encoding(utf8)", "$iname" or die "Cannot open $iname";
	open IPH, "<:encoding(utf8)", "$phons" or die "Cannot open $phons";
	open CH, ">:encoding(utf8)", "$oname.cnt" or die "Cannot open $oname.cnt";
	open LH, ">:encoding(utf8)", "$oname.log" or die "Cannot open $oname.log";
	open DH, ">:encoding(utf8)", "$oname.dict" or die "Cannot open $oname.dict";
	open AH, ">:encoding(utf8)", "$oname.aligned" or die "Cannot open $oname.aligned";
	open MH, ">:encoding(utf8)", "$oname.map" or die "Cannot open $oname.map";
	open PH, ">:encoding(utf8)", "$oname.phones" or die "Cannot open $oname.phones";

	my %plist=();
	while (<IPH>) {
		chomp;
		$plist{$_}=1;
	}
	close IPH;
	
	
	my %wlist=();
	my %wcnt=();
	while (<IH>) {
		chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in aligned dict file: @line\n";
		}
		my $word = $line[0];
		my $phons = $line[2];
		$wcnt{$word}++;
		if (!(exists $wlist{$word})) {
			@{$wlist{$word}}=();
		}
		push @{$wlist{$word}}, $phons;
	}
	close IH;
	
	# Identify variants and store in %changed  -- according to $changed{new_phone}{relevant_word} = 1
	# search for unused phones by starting from $newnum
	# %plist - full list of phones in use at each stage
	# %newlist - new pseudo-phones created
	
	my $newnum = 162;
	my %newlist = ();
	my %changed = ();
	
	foreach my $w (sort keys %wlist) {
		if ($wcnt{$w}>1) {
			#Working version - if only 2 variants
			#if ($wcnt{$w}>2) {
			#	die "Error: more than two variants\n";
			#} else {
			#	my $var1 = $wlist{$w}[0];
			#	my $var2 = $wlist{$w}[1];
			#	my @seq1 = split / /,$var1;
			#	my @seq2 = split / /,$var2;
			#	if ($#seq1 != $#seq2) {
			#		die "Error in alignment of [@seq1] and [@seq2]\n";
			#	}
			#	
			#	my @sound=@seq1;
			#	my $found=0;
			#	my $multiple=0;
			#	foreach my $i (0..$#seq1) {
			#		if (!($seq1[$i] eq $seq2[$i])) {
			#			$p1 = $seq1[$i];
			#			$p2 = $seq2[$i];
			#			$pnew = get_var_name($p1,$p2,%plist,$newnum,%newlist);
			#			$plist{$pnew}=1;
			#			$sound[$i]=$pnew;
			#			$changed{$pnew}{$w}=1;
			#			if ($found==1) {
			#				$multiple=1;
			#			}
			#			$found=1;
			#		}
			#	}
			#}
			
			my $i=0;
			my @seq=();
			my $vartot = ($wcnt{$w}-1);
			foreach my $var (@{$wlist{$w}}) {
				@{$seq[$i]} = split / /,$var;
				if ($#{$seq[$i]} != $#{$seq[0]}) {
					die "Error in alignment of [@{$seq[$i]}] and [@{$seq[0]}]\n";
				}	
				$i++;
			}
			
			#first find indices where different
			my %diffphones=();
			my $numg=$#{$seq[$vartot]};
			foreach my $g (0..$numg) {
				foreach my $i (0..$vartot) {
					foreach my $j (0..$vartot) {
						my $pi=${$seq[$i]}[$g];
						my $pj=${$seq[$j]}[$g];
						if (!($pi eq $pj)) {
							$diffphones{$g}{$pi}=1;
							$diffphones{$g}{$pj}=1;
						}	
					}
				}
			}
			
			my @sound = @{$seq[$vartot]};
			foreach my $g (0..$numg) {
				if (exists $diffphones{$g}) {
					my @varlist = keys %{$diffphones{$g}};
					my $pnew = get_var_name(@varlist,%plist,$newnum,%newlist);
					$plist{$pnew}=1;
					$sound[$g]=$pnew;
					$changed{$pnew}{$w}=1;
				}
			}
		
			my $dict_entry = join "",@sound;
			$dict_entry =~ s/0//g;
			$dict_entry =~ s/ //g;
			printf DH ("%s;%s;1\n",$w,$dict_entry);
				
			my $adict_entry_p = join " ",@sound;
			my $adict_entry_g = join " ", (split //,$w);
			printf AH ("%s;%s;%s\n",$w,$adict_entry_g,$adict_entry_p);
				
		} else {
			my $dict_entry = $wlist{$w}[0];
			$dict_entry =~ s/0//g;
			$dict_entry =~ s/ //g;
			printf DH ("%s;%s;1\n",$w,$dict_entry);
			
			my $adict_entry_p = $wlist{$w}[0];
			my $adict_entry_g = join " ", (split //,$w);
			printf AH ("%s;%s;%s\n",$w,$adict_entry_g,$adict_entry_p);
		}
	}
	close DH;
	close AH;
	
	#Write .log and .map file	
	my %cntwords=();
	foreach my $varlistname (keys %newlist) {
		my @varlist = split /;/,$varlistname;
		my $pnew = get_var_name(@varlist,%plist,$newnum,%newlist);
		foreach my $w (keys %{$changed{$pnew}}) {
			$cntwords{$pnew}++;
			printf LH ("%s;%s;%s\n",$pnew,$varlistname,$w);		
		}
		printf MH ("%s;%s\n",$pnew,$varlistname);		
	}
	close LH;
	close MH;
	
	#Write .cnt file	
	foreach my $p (sort { $cntwords{$b} <=> $cntwords{$a} } keys %cntwords) { 
		printf CH ("%s\t%d\n",$p,$cntwords{$p});		
	}
	close CH;
	
	#Write .phones file	
	foreach my $p (sort keys %plist) {
		print PH "$p\n";
	}
	close PH;
}

#--------------------------------------------------------
sub pron_exists($$\%\%) {
	#Verify if astr expansion of vstr holds: always, never or sometimes
	my ($vstr,$astr,$wordp,$dlistp)=@_;
	
	my @vlist = split //,$vstr;
	my @alist = split //,$astr;
	my $all=1;
	my $none=1;
	foreach my $w (keys %{$wordp}) {
		my @template=split //,$wordp->{$w};
		
		my @pos_var=@template;
		my $i=0;
		foreach my $j (0..$#vlist){
			while (!($template[$i] eq $vlist[$j])) {
				$i++;
			}
			$pos_var[$i]=$alist[$j];
			$i++;
		}
		my $pos_varstr = join "",@pos_var;
		$pos_varstr =~ s/0//g;
		
		if (exists $dlistp->{$w}{$pos_varstr}) {
			$none=0;
		} else {
			$all=0;
		}
	}
	if (($all==1)&&($none==0)) {
		return "all";
	} elsif (($all==0)&&($none==1)) {
		return "none";
	} else {
		return "some";
	}
}

#--------------------------------------------------------

sub do_calc_restrict_v1($$$$) {
	#Version used when only 2 variants possible (used for OALD, updated for Fonilex - see new version of do_calc_restrict)	
	my ($mapf,$origf,$rewritef,$restrictf) = @_;
	print "Calculating restrictions:\nMap file: $mapf\nOriginal dict: $origf\nRewrite dict: $rewritef\nOutput file: $restrictf\n";
	open MH, "<:encoding(utf8)", "$mapf" or die "Cannot open $mapf";
	open DH, "<:encoding(utf8)", "$origf" or die "Cannot open $origf";
	open RH, "<:encoding(utf8)", "$rewritef" or die "Cannot open $rewritef";
	open OH, ">:encoding(utf8)", "$restrictf" or die "Cannot open $restrictf";
	
	my %mlist=();
	while (<MH>) {
		chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in map file: @line\n";
		}
		my $p0=$line[0];
		my $p1=$line[1];
		my $p2=$line[2];
		$mlist{$p0}[0]=$p1;
		$mlist{$p0}[1]=$p2;
	}
	close MH;

	my %dlist=();
	while (<DH>) {
		chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in dict file: @line\n";
		}
		$dlist{$line[0]}{$line[1]}=1;
	}
	close DH;

	my %pvar=();
	while (<RH>) {
		chomp;
		my @line = split /;/,$_;
		my @pron = split //,$line[1];
		my @vlist=();
		foreach my $p (@pron) {
			if (exists $mlist{$p}) {
				push @vlist, $p;
			}	
		}
		if (scalar @vlist>1) {
			my $vstr = join '',@vlist;
			$pvar{$vstr}{$line[0]}=$line[1];
		}
	}
	close RH;
	
	#Get list of possible expansions
	my %restrict=();
	foreach my $vstr (keys %pvar) {
		my @vlist = split //,$vstr;
		my $v1 = shift @vlist;
		my @expand = ($mlist{$v1}[0],$mlist{$v1}[1]);
		foreach my $v (@vlist){
			my $nume = $#expand;
			foreach my $i (0..$nume) {
				my $e = shift @expand;
				push @expand, "$e ".$mlist{$v}[0];
				push @expand, "$e ".$mlist{$v}[1];
			}
		}
		
		foreach my $astr (@expand) {
			my $pron_type = pron_exists($vstr,$astr,%{$pvar{$vstr}},%dlist); 	#all,some,none
			if ($pron_type eq 'all') {
				print "Info: Variants [$vstr] restricted to [$astr] -- holds for all words in training set\n";
				$restrict{$vstr}{$astr}=1;
			} elsif ($pron_type eq 'some') {
				die "Error: More complex rule required for variant [$vstr] when realised as [$astr]\n";
			} else {
				print "Info: No variants [$vstr] allowed as [$astr] \n";
			}
		}
	}
	
	foreach my $r (keys %restrict) {
		print OH "$r";
		foreach my $r2 (keys %{$restrict{$r}}) {
			print OH ";$r2";
		}
		print OH "\n";
	}
	close OH;
}


sub do_calc_restrict($$$$) {
my ($mapf,$origf,$rewritef,$restrictf) = @_;
	print "Calculating restrictions:\nMap file: $mapf\nOriginal dict: $origf\nRewrite dict: $rewritef\nOutput file: $restrictf\n";
	open MH, "<:encoding(utf8)", "$mapf" or die "Cannot open $mapf";
	open DH, "<:encoding(utf8)", "$origf" or die "Cannot open $origf";
	open RH, "<:encoding(utf8)", "$rewritef" or die "Cannot open $rewritef";
	open OH, ">:encoding(utf8)", "$restrictf" or die "Cannot open $restrictf";
	
	my %mlist=();
	while (<MH>) {
		chomp;
		my @line = split /;/,$_;
		my $vari = shift @line;
		my $varval = join ";",@line;
		$mlist{$vari}=$varval;
	}
	close MH;

	my %dlist=();
	while (<DH>) {
		chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in dict file: @line\n";
		}
		$dlist{$line[0]}{$line[1]}=1;
	}
	close DH;

	my %pvar=();
	while (<RH>) {
		chomp;
		my @line = split /;/,$_;
		my @pron = split //,$line[1];
		my @vlist=();
		foreach my $p (@pron) {
			if (exists $mlist{$p}) {
				push @vlist, $p;
			}	
		}
		if (scalar @vlist>1) {
			my $vstr = join '',@vlist;
			$pvar{$vstr}{$line[0]}=$line[1];
		}
	}
	close RH;
	
	#Get list of possible expansions
	my %restrict=();
	foreach my $vstr (keys %pvar) {
		my @vlist = split //,$vstr;
		my $v1 = shift @vlist;
		my @expand = split /;/,$mlist{$v1};
		foreach my $v (@vlist){
			my $nume = $#expand;
			foreach my $i (0..$nume) {
				my $e = shift @expand;
				my @v2list= split /;/,$mlist{$v};
				foreach my $v2 (@v2list) {
					push @expand, "$e$v2";
				}
			}
		}
		
		foreach my $astr (@expand) {
			my $pron_type = pron_exists($vstr,$astr,%{$pvar{$vstr}},%dlist); 	#all,some,none
			if ($pron_type eq 'all') {
				print "Info: Variants [$vstr] restricted to [$astr] -- holds for all words in training set\n";
				$restrict{$vstr}{$astr}=1;
			} elsif ($pron_type eq 'some') {
				print "Info: More complex rule required for variant [$vstr] when realised as [$astr] - do manually!!\n";
				$restrict{$vstr}{$astr}=1;
			} else {
				print "Info: No variants [$vstr] allowed as [$astr] \n";
			}
		}
	}
	
	foreach my $r (keys %restrict) {
		print OH "$r";
		foreach my $r2 (keys %{$restrict{$r}}) {
			print OH ";$r2";
		}
		print OH "\n";
	}
	close OH;
}

#--------------------------------------------------------

sub do_compare($$$) {
	my ($tname,$rname,$oname) = @_;
	print "Comparing variant results:\n test dict: $tname\n reference dict: $rname\n output: $oname\n";
	open TH, "<:encoding(utf8)", "$tname" or die "Cannot open $tname";
	open RH, "<:encoding(utf8)", "$rname" or die "Cannot open $rname";
	open OH, ">:encoding(utf8)", "$oname" or die "Cannot open $oname";
	
	my %testlist=();
	my %cnttest=();
	my %cntref=();
	my %todo=();	

	while (<TH>) {
		chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in dict file: @line\n";
		}
		my $word = $line[0];
		my $sound = $line[1];
		my $verdict = $line[2];
		if ($verdict==1) {
			$testlist{$word}{$sound}=1;
			$cnttest{$word}++;
			if ($cnttest{$word}>1) {
				$todo{$word}=1;
			}
		}
	}
	close TH;
	
	my %reflist=();
	while (<RH>) {
		chomp;
		my @line = split /;/,$_;
		if (@line!=3) {
			die "Error in dict file: @line\n";
		}
		my $word = $line[0];
		my $sound = $line[1];
		my $verdict = $line[2];
		if ($verdict==1) {
			$reflist{$word}{$sound}=1;
			$cntref{$word}++;
			if ($cntref{$word}>1) {
				$todo{$word}=1;
			}
		}
	}
	close RH;

	my $total_common=0;
	my $total_missing=0;
	my $total_extra=0;
	foreach my $w (sort keys %todo) {
		my $common=0;
		my $missing=0;
		my $extra=0;
		foreach my $s (keys %{$testlist{$w}}) {
			if (exists $reflist{$w}{$s}) {
				$common++;
			} else {
				$extra++;
			}
		}
		foreach my $s (keys %{$reflist{$w}}) {
			if (!(exists $testlist{$w}{$s})) {
				$missing++;
			}
		}
		print OH "$w;$common;$missing;$extra\n";
		$total_common += $common;
		$total_missing += $missing;
		$total_extra += $extra;
	}

	my $total = $total_common+$total_missing+$total_extra;
	print OH "TOTAL;$total_common;$total_missing;$total_extra;$total\n";
	printf OH ("PERC;%2.2f;%2.2f;%2.2f\n",100*$total_common/$total,100*$total_missing/$total,100*$total_extra/$total);
	close OH;
}

#--------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------


