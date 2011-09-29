package g2pExp;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;

	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&split_data &split_parts &combine_parts &combine_results &compare_results_3col);
}

#--------------------------------------------------------------------------

sub split_data($$$$$) {
	my ($iname,$n,$num,$sname,$lname) = @_;
	open IH, "$iname" or die "Cannot open $iname";
	open LH, ">$lname" or die "Cannot open $lname";
	open SH, ">$sname" or die "Cannot open $sname";

	#my $cmd = "wc $iname | gawk '{print \$1}'";
	#my $tot = `$cmd`;
	#my $skip = $tot/$num-1; 

	my $i = 1; my $c=0; my $next;
	while (defined($next=<IH>)&&($c<$num)) {
		chomp $next;
		if ($i==$n) { print SH "$next\n"; $i=1; $c++;}
		else {print LH "$next\n"; $i++;}
	}
	close IH;
	close LH;
	close SH;
}



sub split_parts($$$) {
	my ($iname,$n,$oname) = @_;
	my @all=();
	open IH, "$iname" or die "Error opening $iname\n";
	while (<IH>) {
		chomp;
		push @all,$_;
	}
	my $max = $#all * 5;

	foreach my $l (@all) {
		$order{$l}=rand($max);
	}
	@all = sort {$order{$a}<=>$order{$b}} @all;
	
	foreach my $fn (1..$n) {
		open $fn, ">$oname.$fn" or die "Error opening $oname.$fn\n";
	}

	my $fnum=1;
	foreach my $l (@all) {
		print $fnum "$l\n";
		$fnum++;
		if ($fnum>$n){$fnum=1;} 
	}
	
	foreach my $fn (1..$n) {
		close $fn;
	}
}



sub combine_parts($$$) {
	my ($iname,$n,$oname) = @_;
	
	my @train=();
	my @test=();
	for my $i (1..$n) {
		open $i, "$iname.$i" or die "Error opening $iname.$i\n";
		while (<$i>) {
			chomp;
			for my $o (1..$n) {
				if ($i != $o) {
					push @{$train[$o]},$_;
				} else {
					push @{$test[$o]},$_;
				}
			}
		}
		close $i;
	}
	
	for my $o (1..$n) {
		open $o, ">$oname.train.$o" or die "Error opening $oname.train.$o\n";
		@towrite = sort @{$train[$o]};
		foreach my $t (@towrite) {
			print $o "$t\n";
		}
		close $o;
		
		open $o, ">$oname.test.$o" or die "Error opening $oname.test.$o\n";
		@towrite = sort @{$test[$o]};
		foreach my $t (@towrite) {
			print $o "$t\n";
		}
		close $o;
	}
}

sub combine_results($$$) {
	my ($iname,$parts,$oname)=@_;
	
	use Statistics::Descriptive;
	open OH, ">$oname" or die "Error opening $oname\n";
	my @plist = split /;/,$parts;
	
	%acc1=();
	%acc2=();
	%acc3=();
	printf OH "$oname [$parts]\n";
	foreach my $p (@plist) {
		open IH, "$iname.$p" or die "Error opening $iname.$p\n";
		#<IH>;
		my $name="";
		while (<IH>) {
			chomp;
			if ($_ =~ /.*\.([a-z_]*$)/) {
				$name = $1;	
			} else {
				@line = split;
				if ((scalar @line)>1) {
					push @{$acc1{$name}{$line[0]}},$line[1];
					push @{$acc2{$name}{$line[0]}},$line[2];
				}
				if ((scalar @line)>2) {
					push @{$acc3{$name}{$line[0]}},$line[3];
				}
			}
		}
		close IH;
	}
	
	
	foreach my $t (keys %acc1) {
		printf OH "$t\n";
		#NB: This is the bias-corrected std.dev. May sometimes want to use the plain sample standard dev...
		print OH "n\tgcor\tstddev\t/sqrt\tgacc\tstddev\t/sqrt\twacc\tstddev\t/sqrt\n";
		foreach my $n (sort {$a <=> $b } keys %{$acc1{$t}}) {
			my $stat1 = Statistics::Descriptive::Sparse->new();
			my $stat2 = Statistics::Descriptive::Sparse->new();
			my $stat3 = Statistics::Descriptive::Sparse->new();
	                $stat1->add_data(@{$acc1{$t}{$n}});
	                $stat2->add_data(@{$acc2{$t}{$n}});
	                $stat3->add_data(@{$acc3{$t}{$n}});
			my $norm=sqrt($stat1->count);
			my $m1 = $stat1->mean;
			my $s1 = $stat1->standard_deviation;
			my $m2 = $stat2->mean;
			my $s2 = $stat2->standard_deviation;
			my $m3 = $stat3->mean;
			my $s3 = $stat3->standard_deviation;
			#print "$n\t$pm\t[$pv]\t$wm\t[$wv]\n";
			printf OH "%2.2f\t%2.2f\t[%2.2f]\t[%2.2f]\t%2.2f\t[%2.2f]\t[%2.2f]\t%2.2f\t[%2.2f]\t[%2.2f]\n",$n,$m1,$s1,$s1/$norm,$m2,$s2,$s2/$norm,$m3,$s3,$s3/$norm;
		}
	}
}

sub compare_results_3col ($$$) {
	my ($fname1,$fname2,$ignore)=@_;
	open IH1, "$fname1" or die "Error opening $fname1\n";
	open IH2, "$fname2" or die "Error opening $fname2\n";
	my %result1=();
	my %result2=();
	my $linecnt=0;
	while (<IH1>) {
		if ($linecnt<$ignore) {
			$linecnt++;
		} else {
			chomp;
			my @line = split;
			if (@line==3) {
				$result1{'pacc'}{$line[0]}=$line[1];
				$result1{'wacc'}{$line[0]}=$line[2];
			} elsif (@line==1) {
				$result1{'pacc'}{$line[0]}=0;
				$result1{'wacc'}{$line[0]}=0;
			}
		}
	}
	close IH1;
	$linecnt=0;
	while (<IH2>) {
		if ($linecnt<$ignore) {
			$linecnt++;
		} else {
			chomp;
			my @line = split;
			if (@line==3) {
				$result2{'pacc'}{$line[0]}=$line[1];
				$result2{'wacc'}{$line[0]}=$line[2];
			} elsif (@line==1) {
				$result2{'pacc'}{$line[0]}=0;
				$result2{'wacc'}{$line[0]}=0;
			}
		}
	}
	close IH2;

	print "Phone error rate:\n";
	foreach my $i (sort {$a<=>$b} keys %{$result1{'pacc'}}) {
		my $r1 = $result1{'pacc'}{$i};
		my $r2 = $result2{'pacc'}{$i};
		printf "%d\t%2.2f\t%2.2f\t%2.1f\n",$i,100-$r1,100-$r2,100*($r2-$r1)/(100-$r1) ;
	}
	print "Word error rate:\n";
	foreach my $i (sort {$a<=>$b} keys %{$result1{'wacc'}}) {
		my $r1 = $result1{'wacc'}{$i};
		my $r2 = $result2{'wacc'}{$i};
		printf "%d\t%2.2f\t%2.2f\t%2.1f\n",$i,100-$r1,100-$r2,100*($r2-$r1)/(100-$r1) ;
	}

}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------
