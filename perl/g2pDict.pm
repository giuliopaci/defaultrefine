package g2pDict;

use g2pFiles;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;
	$msg = 1;
	
	%verdictValue = ();
        $verdictValue{'Notverified'} = 0;
	$verdictValue{'Correct'} = 1;
	$verdictValue{'Wrong'} = -1;
	$verdictValue{'Uncertain'} = -2;
	$verdictValue{'Ambiguous'} = -3;
	$verdictValue{'Invalid'} = -4;

	#$hres = "/usr/local/htk/bin.linux/HResults";
	$hres = "HResults";

	#Many functions assume not using double words - doubles really only used by align experiments: not via front-end 
	#Check functionality before using doubles for other purposes!!
	
	%doubleType = ();
	$doubleType{'none'} = 0;
	$doubleType{'one'} = 1;
	$doubleType{'all'} = 2;
	$doubleType{'pos_one'} = 3;
	
	#$dictType = $doubleType{'pos_one'};
	$dictType = $doubleType{'one'};
	#$dictType = $doubleType{'all'};
	#$dictType = $doubleType{'none'};

	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(%verdictValue %doubleType $dictType &fread_words &fwrite_words &fread_dict &fwrite_dict &fadd_dict &add_stat &rm_uncertain_dict &rm_notcorrect_dict &cmp_dicts &ffind_words &fcmp_phoneAcc &fwlist_frommaster &fwlist_first &fwlist_even &fwlist_fromdict &rm_certain_words &fdict_subset &fcount_dict &read_changed &write_changed);

}

#--------------------------------------------------------------------------

sub fread_words($\@) {
	my ($fname,$wp) = @_;
	print "-- Enter fread_words: $fname\n" if $debug;
	open IH,"<:encoding(utf8)",$fname or die "Cannot open $fname";
	@$wp = ();
	while (<IH>) {
		chomp; 
		if (! $_ eq "") {push @$wp,$_;}
	}
	close IH;
	#print "@$wp\n" if $debug;
}						 

sub fwrite_words($\@) {
	my ($fname,$wp) = @_;
	print "-- Enter write_words $fname\n" if $debug;
	open OH,">:encoding(utf8)","$fname" or die "Cannot open $fname";
	if ($#$wp<0) {print OH "\n"}
	else { foreach my $w (@$wp){print OH "$w\n";}}
	close OH;
}						 

#--------------------------------------------------------------------------

sub fread_dict($\%\%) {
	my ($dname,$dictp,$statp) = @_;
	print "-- Enter fread_dict: $dname\n" if $debug;
	%$dictp = ();
	%$statp = ();
	open  IH, "<:encoding(utf8)", $dname or die "Cannot open file $dname";
	while (<IH>){
		chomp; my @line = split /;/;
		my $word=$line[0];
		my $pron=$line[1];
		my $verdict=$line[2];
		my $pos;
		if ($dictType==$doubleType{'pos_one'}) {
			die "Error: Dictionary format @line" if @line != 4;
			$pos=$line[3];
		}
	 	if (exists $dictp->{$word}) {
			if ($dictType==$doubleType{'none'}) {
                        	print "Warning: double removed ($word)\n" if $msg;
                        	delete $dictp->{$word};
                        	delete $statp->{$word};
			} elsif ($dictType==$doubleType{'one'}) { 
                        	print "Warning: not adding double ($word)\n" if $msg;
			} elsif ($dictType==$doubleType{'pos_one'}) {
				my %poslist = %{$dictp->{$word}};
				if (exists $poslist{$pos}) {
					print "Warning: not adding double ($word,$pos)\n" if $msg;
				} else {
					$dictp->{$word}{$pos} = $pron;
					$statp->{$word}{$pos} = $verdict;
				}
			} elsif ($dictType==$doubleType{'all'}) {
				my $newi=1;
				my $newword = "${word}_$newi";
				my $found=0;
				while (!$found) { 
					if (exists $dictp->{$newword}) {$newi++;$newword="${word}_$newi";} 
					else {$found=1}
				}
				$dictp->{$newword} = $pron;
				$statp->{$newword} = $verdict;
                        	print "Warning: adding a double ($newword)\n" if $msg;
			} else {
				die "Dictionary double type $dictType unknown"
			}
                 } else {
			
			if ($dictType==$doubleType{'pos_one'}) {
				$dictp->{$word}{$pos} = $pron;
				$statp->{$word}{$pos} = $verdict;
			} else {
				$dictp->{$word} = $pron;
				$statp->{$word} = $verdict;
			}
		}
	}
	close IH;
}


sub fwrite_dict($\%\%) {
        my ($dname,$dp,$sp) = @_;
        open OH, ">:encoding(utf8)","$dname" or die "Cannot open $dname";
	foreach my $word (sort keys %{$dp}) {
		if ($dictType==$doubleType{'pos_one'}) {
			my @poslist = keys %{$dp->{$word}};
			foreach my $pos (@poslist) {
				if (! exists $sp->{$word}{$pos}) {die "Error: status of $word unknown"}
				else { print OH "$word;$dp->{$word}{$pos};$sp->{$word}{$pos};$pos\n" }
			}
		} else {
			$towrite = $word;
			$towrite =~ s/^(.*)_.*$/$1/;
			#if ($towrite =~ s/^(.*)_.*$/$1/) {
			#	print "Changed $word to $towrite\n";
			#}
			if (! exists $sp->{$word}) {die "Error: status of $word unknown"}
			else { print OH "$towrite;$dp->{$word};$sp->{$word}\n" }
		}
	}
        close OH;
}

#--------------------------------------------------------------------------

sub fadd_dict($$) {
	#Add new values from new to master - if both have values, master (2nd dict) overrides
        my ($nnew,$nmaster) = @_;
	print "-- Enter fadd_dict: $nnew, $nmaster\n" if $debug;
	my (%dnew,%snew,%dmaster,%smaster);
	fread_dict($nmaster,%dmaster,%smaster);
	fread_dict($nnew,%dnew,%snew);
        while (my ($word,$val) = each %snew) {
             if ($val!=$verdictValue{'Notverified'}) {
		     $dmaster{$word} = $dnew{$word};
		     $smaster{$word} = $snew{$word};
	     } else {
		     if ((!exists($dmaster{$word}))||($smaster{$word}==$verdictValue{'Notverified'})) {
			     $dmaster{$word} = $dnew{$word};
			     $smaster{$word} = $snew{$word};
		     }
	     }
     }
     fwrite_dict($nmaster,%dmaster,%smaster);
}


sub add_stat(\%\%\%\%) {
       my ($newdp,$newsp,$olddp,$oldsp) = @_;
       while (my ($word,$val) = each %$newdp) {
               if (exists $olddp->{$word}) {
                     if ($newsp->{$word}==$verdictValue{'Notverified'}) {
			     $newsp->{$word} = $oldsp->{$word};
			     $newdp->{$word} = $olddp->{$word};
		     }
	       } 
        }
}

#--------------------------------------------------------------------------

sub rm_uncertain_dict(\%\%) {
	my ($dp,$sp) = @_;
	print "-- Enter rm_uncertain_dict\n" if $debug;
	foreach my $w (keys %$dp) {
		if ($sp->{$w}==$verdictValue{'Notverified'}) {
			delete $dp->{$w};
			delete $sp->{$w};
		}
	}
}

sub rm_notcorrect_dict(\%\%) {
	my ($dp,$sp) = @_;
	print "-- Enter rm_notcorrect_dict\n" if $debug;
	foreach my $w (keys %$dp) {
		if ($dictType==$doubleType{'pos_one'}) {
			my @poslist=keys %{$dp->{$w}};
			foreach my $pos (@poslist) {
				if ($sp->{$w}{$pos}!=$verdictValue{'Correct'}) {
					delete $dp->{$w}{$pos};
					delete $sp->{$w}{$pos};
					if (scalar @poslist==1) {
						delete $dp->{$w};
						delete $sp->{$w};
					}
				}
			}
		} else {
			if ($sp->{$w}!=$verdictValue{'Correct'}) {
				delete $dp->{$w};
				delete $sp->{$w};
			}
		}
	}
}

#--------------------------------------------------------------------------


#Find first <max> words from dictionary <dname> - result in <wname>
#if <test>, find uncertain ones only 
sub fwlist_fromdict($$$$) {
	my ($max,$test,$dname,$wname) = @_;
	print "-- Enter fwlist_fromdict: $max, $test,$dname,$wname\n" if $debug;
	open IH, "<:encoding(utf8)", "$dname" or die "Cannot open $dname";
	open OH, ">:encoding(utf8)","$wname" or die "Cannot open $wname";
	my $n=0;
	while (<IH>) {
		chomp; my @i = split /;/;
		if ((!$test)||(($test)&&($i[2]==0))) {
			print OH "$i[0]\n"; $n++;
		}
		last if ($n==$max);
	}
	close IH; close OH;
	return $n;
}

sub fwlist_first($\%$$\@) {
	my ($mname,$sp,$test,$max,$wp) = @_;
	open IH, "<:encoding(utf8)", "$mname" or die "Cannot open $mname";
	my $n=0;
	while (<IH>) {
		chomp; 
		if ((!$test)||(($test)&&((!exists $sp->{$_})||($sp->{$_}==$verdictValue{'Notverified'})))) {
			push @$wp, $_; $n++;
			print "[$n] $_\n" if $debug;
		}
		last if ($n==$max);
	}
	close IH; 
	return $n;
}

sub rm_certain_words(\%\@\%) {
	my ($sp,$mlistp,$wp) = @_;
	print "-- Enter rm_certain_words: $#$mlistp\n" if $debug;
	foreach my $i (0 .. $#{$mlistp}) {
		unless ((exists $sp->{$mlistp->[$i]})&&($sp->{$mlistp->[$i]}==1)) {
			$wp->{$mlistp->[$i]}=1;
		}
	}
}

sub fwlist_even($\%$$\@) {
	local ($mname,$sp,$test,$max,$wp) = @_;
	print "-- Enter fwlist_even: $mname, $test,$max\n" if $debug;
	local @wlist = ();
	@$wp = ();
	fread_words($mname,@wlist);
	if ($test) {
		local %tmplist = ();
		rm_certain_words(%$sp,@wlist,%tmplist);
		@wlist = keys %tmplist;
	}
	my $skip = $#wlist/$max-1;
	my $i = 1;
	for my $j (0..$#wlist) {
		if ($i >= $skip) {
			push @$wp, $wlist[$j];
			$i = $i-$skip;
		} else { $i++ }
		last if ($#$wp==$max-1);
	}
	return $#$wp+1;
}

sub fwlist_frommaster($$$$$) {
	my ($mname,$dname,$max,$otype,$wname) = @_;
	my (@wlist,%dict,%stat) = ((),(),());
        fread_dict($dname,%dict,%stat);
	if ($otype eq 'first') {
                $tsize = fwlist_first($mname,%stat,0,$max,@wlist);
        } elsif ($otype eq 'firstUncertain') {
                $tsize = fwlist_first($mname,%stat,1,$max,@wlist);
        } elsif ($otype eq 'even') {
                $tsize = fwlist_even($mname,%stat,0,$max,@wlist);
        } elsif ($otype eq 'evenUncertain') {
                $tsize = fwlist_even($mname,%stat,1,$max,@wlist);
        } else {return 0}
	fwrite_words($wname,@wlist);
	return $tsize;
}

#--------------------------------------------------------------------------

sub fdict_subset($$$) {
	my ($wname,$oldname,$newname) = @_;
	print "-- Enter fdict_subset $wname,$oldname,$newname\n" if $debug;
	my (%olddict,%oldstat,%newdict,%newstat,@words);
        fread_dict($oldname,%olddict,%oldstat);
	fread_words($wname,@words);
	%newdict=(); %newstat=();
        foreach my $word (@words) {
                if (exists $olddict{$word}) {
                        $newdict{$word} = $olddict{$word};
                        $newstat{$word} = $oldstat{$word};
			my $i=1;
                	while (exists $olddict{"${word}_$i"}) {
                        	$newdict{"${word}_$i"} = $olddict{"${word}_$i"};
                        	$newstat{"${word}_$i"} = $oldstat{"${word}_$i"};
				$i++;
			}
			#print "Added $word; $newdict{$word}; $newstat{$word}\n";
                }
        }
        fwrite_dict($newname,%newdict,%newstat);
}

#--------------------------------------------------------------------------

sub ffind_words($$$$\%) {
	my ($fname,$g,$p,$v,$wlp) = @_;
	print "-- Enter ffind_words $fname,$g,$p,$v\n" if $debug;
	local (%dict,%stat);
	fread_dict($fname,%dict,%stat);
	foreach my $word (keys %dict) {
		if ((($g eq 'all')||($word=~/$g/)) && (($p eq 'all')||($dict{$word}=~/$p/)) && (($v eq 'all')||($stat{$word}==$v))) {
			$wlp->{$word} = 1;
		}
	}
}

#--------------------------------------------------------------------------

sub cmp_dicts($$\%) {
	my ($n1,$n2,$resultp) = @_; 
	print "-- Enter cmp_dicts: $n1, $n2\n" if $debug;
	use List::Compare;
	my (%d1,%d2,%n1,%n2,@same,@diff);
	$#same=-1; $#diff=-1;
	fread_dict($n1,%d1,%s1);
	fread_dict($n2,%d2,%s2);
	@d1keys = keys %d1; @d2keys = keys %d2;
	$lc = List::Compare->new(\@d1keys, \@d2keys);
	@extra = $lc->get_Lonly;	
	@missing = $lc->get_Ronly;	
	@compare = $lc->get_intersection;	
	foreach $word (@compare) {
		if ((($s1{$word}==$s2{$word})&&($s1{$word}!=$verdictValue{'Correct'}))||
		    (($s1{$word}==$s2{$word})&&($s1{$word}==$verdictValue{'Correct'})&&($d1{$word} eq $d2{$word}))) { 
			    push @same, $word 
		} else { push @diff, $word }
	}
	$resultp->{same} = "@same";
	$resultp->{diff} = "@diff";
	$resultp->{extra} = "@extra";	
	$resultp->{missing} = "@missing";	
	#print "Result: <p>same: $resultp->{same} <p>diff: $resultp->{diff} <p>extra: $resultp->{extra} <p>missing: $resultp->{missing}" if $debug;
}

sub write_htkmlf(\%$$) {
	my ($dictp,$fname,$ext) = @_;
	print "-- Enter write_htkmlf $fname\n" if $debug;
	open OH, ">:encoding(utf8)", "$fname" or die "Cannot open $fname";
	foreach $i ('0'..'9') { $num{$i} = 'a'.$i }  #HTK breaks on phoneme names that are numbers only
	print OH "#!MLF!#\n";
	my @wlist = sort keys %$dictp;
	foreach my $word (@wlist) {
		my $sound = $dictp->{$word};
		print OH "\"$word.$ext\"\n";
		my @phones = split //,$sound;
		foreach my $p (@phones) {
			if (exists($num{$p})) { print OH "$num{$p}\n" } 
			else { print OH "$p\n" } 
		}
		print OH ".\n"; 
	}
	close OH;
}

sub write_htkmlf_1extra(\%$$) {
	my ($dictp,$fname,$ext) = @_;
	print "-- Enter write_htkmlf $fname\n" if $debug;
	open OH, ">:encoding(utf8)", "$fname" or die "Cannot open $fname";
	foreach $i ('0'..'9') { $num{$i} = 'a'.$i }
	print OH "#!MLF!#\n";
	foreach my $word (keys %{$dictp}) {
		foreach my $f1 (keys %{$dictp->{$word}}) {
			print OH "\"${word}_$f1.$ext\"\n";
			my @phones = split //,$dictp->{$word}{$f1};
			foreach my $p (@phones) {
				if (exists($num{$p})) { print OH "$num{$p}\n" } 
				else { print OH "$p\n" } 
			}
		}
		print OH ".\n"; 
	}
	close OH;
}


sub fcmp_phoneAcc($$$$) {
	my ($d1,$d2,$pn,$resf) = @_;
	print "-- Enter fcmp_phoneAcc $d1 $d2 $pn $resf\n" if $debug;
	my (%dict1,%dict2,%s1,%s2);
	if ($custom_use eq 'context_and_1feat') {
		fread_dict($d1,%dict1,%s1);
		write_htkmlf_1extra(%dict1,"$d1.mlf","lab");
		fread_dict($d2,%dict2,%s2);
		write_htkmlf_1extra(%dict2,"$d2.mlf","rec");
	} else {
		fread_dict($d1,%dict1,%s1);
		write_htkmlf(%dict1,"$d1.mlf","lab");
		fread_dict($d2,%dict2,%s2);
		write_htkmlf(%dict2,"$d2.mlf","rec");
	}
	my $sedstr =  's/\([0-9]\)/a\1/g';
	`sed -e $sedstr $pn > $pn.result`;
	my $cmnd = "$hres -t -T 1 -I $d1.mlf $pn.result $d2.mlf > $resf";
	print "$cmnd";
	`$cmnd`;
	#system "rm $pn.result";
}

#--------------------------------------------------------------------------

sub read_changed(\%\%) {
	my ($cdp,$csp) = @_; 
	print "-- Enter read_changed " if $debug;
	open IH, "<:encoding(utf8)", "$cdir/$ct" or die "Cannot open file $cdir/$ct";
	while (<IH>) {
		chomp; my ($word,$sound,$stat) = split /;/;
		$cdp->{$word} = $sound;
		$csp->{$word} = $stat;
	}
	close IH;
	my @numchanged = keys %{$csp};
	my $numc = $#numchanged+1;
	return $numc;
}

sub write_changed(\%\%) {
	my ($cdp,$csp) = @_; 
	print "-- Enter write_changed $cdir/$ct" if $debug;
	open OH, ">:encoding(utf8)", "$cdir/$ct" or die "Cannot open file $cdir/$ct";
	foreach $word (keys %{$cdp}) {
		print OH "$word;$cdp->{$word};$csp->{$word}\n";
	}
	close OH;
}

#--------------------------------------------------------------------------

sub fcount_dict($\%) {
        my ($fname,$estatp) = @_;
        print "-- Enter fcount_dict $fname" if $debug;
        %$estatp = (); local (%dp,%sp);
        fread_dict($fname,%dp,%sp);
        foreach my $verdict (values %verdictValue) {
                $estatp->{$verdict} = 0;
        }
        while ( my ($word,$verdict) = each %sp){
                $estatp->{$verdict}++;
                $estatp->{'total'}++;
        }
}


#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------
