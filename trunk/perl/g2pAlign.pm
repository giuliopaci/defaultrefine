package g2pAlign;

use g2pFiles;
use g2pDict;
use g2pArchive;
use g2pSound;
use g2pRulesHelper;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	
	#pattern = left-graph-right
	#%context;  context{graph} = array of patterns;
	#%rule;     rule{pattern} = phones;
	#%counts;
	#%probs;
	#don't need context - can get from rule - added to keep things simple

	$debug = 0;
	$msg = 1;
	$aligntype = 4;
	#$aligntype = 1; #(Previous version of align - not integrated with gnulls process)

	#v1 = normal Viterbi
	#v2 = extra set of probs (prob0 added)
	#v3 = further refinement of v2 - probs now calculated per chunk not only on staying in state
	#v4 = new alignment if gnulls added automatically (based on v2)
	#v10 - different alignment used when identifying gnulls

	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw($aligntype %counts %counts0 %counts00 %counts000 %probs %probs0 %probs00 %probs000 &fread_align &fwrite_align &falign_dict &align_word &fadd_aligned &align_dict &id_gnulls &faligned &init_counts &fread_gnull_list &fwrite_gnull_list &add_gnull_word &add_gnull_list &update_probs &compare_words &fcmp_aligned &walign_init_probs &walign_word &fprobs_from_aligned &init_acc_probs &full_align_word &compare_accuracy &score_match);
}


#--------------------------------------------------------------------------

#Debug functions

sub show_counts() {
	use CGI qw(:standard *table);
	print "-- Enter show_counts" if $debug;
        local (@graphs,@phones);
        my @tdarray = ();
        read_graphs(@graphs);
        read_phones(@phones);
        print start_table;
        push @graphs,0;
        push @tdarray, th(" ");
	local %sinfo=();
	read_sounds(%sinfo);
        foreach my $p ( @phones ) {
		my @p=($p);
		mk_phon(%sinfo,@p,@sp);	
                push @tdarray, th($sp[0]);
        }
        print Tr(@tdarray);
        foreach my $g ( @graphs ) {
                my @tdarray = (th("$g"));
                foreach my $p ( @phones ) {
                        push @tdarray, td($counts{$g}{$p});
		}
		print Tr(@tdarray);
		#@tdarray = (th("$g"));
		#foreach my $p ( @phones ) {
		#	push @tdarray, td($counts0{$g}{$p}); 
		#	} 
		#print Tr(@tdarray); 
		#@tdarray = (th("$g"));
		#foreach my $p ( @phones ) {
		#	push @tdarray, td($counts00{$g}{$p}); 
		#	} 
		#print Tr(@tdarray); 
		#@tdarray = (th("$g"));
		#foreach my $p ( @phones ) {
		#	push @tdarray, td($counts000{$g}{$p}); 
		#	} 
		#print Tr(@tdarray); 
	}
	print end_table; 
}


sub show_probs(\%\%) {
	use CGI qw(:standard *table);
	my ($probp,$prob0p) = @_;
	print "-- Enter show_probs" if $debug;
	local (@graphs,@phones);
	local %sinfo=();
	my @tdarray = ();
	read_graphs(@graphs); push @graphs,'0';
	read_phones(@phones); 
	read_sounds(%sinfo);
	print start_table;
	push @tdarray, th(" ");
	foreach my $p ( @phones ) {
		@p=($p);
		mk_phon(%sinfo,@p,@sp);	
		push @tdarray, th($sp[0]);
	}
	print Tr(@tdarray);
	foreach my $g ( @graphs ) {
		my @tdarray = (th("$g"));
		foreach my $p ( @phones ) {
			$prob = sprintf "%.3f",$probp->{$g}{$p};
			push @tdarray, td($prob);
		}
		print Tr(@tdarray);

		#@tdarray = (th("$g"));
		#foreach my $p ( @phones ) {
		#	$prob = sprintf "%.3f",$prob0p->{$g}{$p};
		#	push @tdarray, td($prob);
		#}
		#print Tr(@tdarray);
	}
	print end_table;
}


#--------------------------------------------------------------------------

sub init_counts_v2() {
	print "-- Enter init_counts" if $debug;
	local (@graphs,@phones);
	read_graphs(@graphs); push @graphs,'0';
	read_phones(@phones); 
	my $smoothf = 1;
	%counts=(); %counts0=(); 
	foreach my $g ( @graphs ) {
		foreach my $p ( @phones ) {
			$counts{$g}{$p} = $smoothf;
			$counts0{$g}{$p} = $smoothf;
		}
	}
}

sub update_probs_v2() {
	print "-- Enter update_probs" if $debug;
	my $scalef = 1;
	local (@graphs,@phones);
	read_graphs(@graphs); push @graphs,'0';
	read_phones(@phones); 
	foreach my $g ( @graphs ) {
		my $gtotal = 0; my $gtotal0 = 0;
		foreach my $p ( @phones ) {
			$gtotal += $counts{$g}{$p};
			$gtotal0 += $counts0{$g}{$p};
		}
		my $gtotal_all = $gtotal+$gtotal0;
		foreach my $p ( @phones ) {
			$probs{$g}{$p} = $scalef * $counts{$g}{$p} / $gtotal_all;
			$probs0{$g}{$p} = $scalef * $counts0{$g}{$p} / $gtotal_all;
			#print "HERE [$g][$p] $probs{$g}{$p} AND $probs0{$g}{$p}\n";
		}
	}
}


#--------------------------------------------------------------------------

sub update_probs_v3() {
	print "-- Enter update_probs" if $debug;
	my $scalef = 1;
	local (@graphs,@phones);
	read_graphs(@graphs);
	read_phones(@phones); 

	#my $total=0;
	foreach my $g ( @graphs ) {
		my $gtotal = 0; my $gtotal0 = 0;
		foreach my $p (@phones) {
			$gtotal += $counts{$g}{$p};
		}
		foreach my $gstr (keys %counts0) {
			if ($gstr =~ /.*$g$/) {
				foreach my $p (keys %{$counts0{$gstr}}) {
					$gtotal0 += $counts0{$gstr}{$p};
				}
			}
		}
		
		my $gtotal_all = $gtotal+$gtotal0;
		foreach my $p ( @phones ) {
			$probs{$g}{$p} = $scalef * $counts{$g}{$p} / $gtotal_all;
			$probs0{$g}{$p} = $scalef / $gtotal_all;
		}
	
		foreach my $gstr (keys %counts0) {
			if ($gstr =~ /.*$g$/) {
				foreach my $p (keys %{$counts0{$gstr}}) {
					$probs0{$gstr}{$p} = $scalef * $counts0{$gstr}{$p} / $gtotal_all;
				}
			}
		}
		$total += $gtotal;
	}
	#my $avgtotal = $total / $#graphs;
	#foreach my $g ( @graphs ) {
	#	foreach my $p ( @phones ) {
	#		$probs0{$g}{$p} = $scalef / $avgtotal;
	#	}
	#}
}

#--------------------------------------------------------------------------
# Previous version of align_word (Uses normal Viterbi)
# Relied on different prob calculation. To use, also use init_counts_v1 and update_probs_v1

sub init_counts_v1() {
	print "-- Enter init_counts" if $debug;
	local (@graphs,@phones);
	read_graphs(@graphs); 
	read_phones(@phones); push @phones, '0';
	my $smoothf = 3;
	foreach my $g ( @graphs ) {
		foreach my $p ( @phones ) {
			#if ($p eq '0') {
			#	$counts{$g}{$p} = $smoothf;
			#} else { 
				$counts{$g}{$p} = $smoothf;
			#}
		}
	}
}

sub update_probs_v1() {
	print "-- Enter update_probs" if $debug;
	my $scalef = 1;
	local (@graphs,@phones);
	read_graphs(@graphs);
	read_phones(@phones); push @phones, '0';
	foreach my $g ( @graphs ) {
		my $gtotal = 0; 
		foreach my $p ( @phones ) {
			$gtotal += $counts{$g}{$p};
		}
		foreach my $p ( @phones ) {
			$probs{$g}{$p} = $scalef * $counts{$g}{$p} / $gtotal;
		}
	}
}


#--------------------------------------------------------------------------

sub init_counts_vg() {
	print "-- Enter init_counts" if $debug;
	local (@graphs,@phones);
	read_graphs(@graphs); push @graphs,0;
	read_phones(@phones); 
	my $smoothf = 1;
	%counts=(); 
	#%counts0=(); 
	foreach my $g ( @graphs ) {
		foreach my $p ( @phones ) {
			$counts{$g}{$p} = $smoothf;
			#$counts0{$g}{$p} = $smoothf;
		}
	}
}

sub update_probs_vg() {
	print "-- Enter update_probs" if $debug;
	my $scalef = 1;
	local (@graphs,@phones);
	read_graphs(@graphs); push @graphs, '0';
	read_phones(@phones); 
	foreach my $g ( @graphs ) {
		my $gtotal = 0; 
		foreach my $p ( @phones ) {
			$gtotal += $counts{$g}{$p};
		}
		foreach my $p ( @phones ) {
			$probs{$g}{$p} = $scalef * $counts{$g}{$p} / $gtotal;
		}
	}
}

#--------------------------------------------------------------------------

sub update_probs() {
	if ($aligntype==1) {update_probs_v1;}
	elsif ($aligntype==2) {update_probs_v2;}
	elsif ($aligntype==3) {update_probs_v3;}
	elsif ($aligntype==4) {update_probs_v2;}
	elsif ($aligntype==10) {update_probs_vg;}
	else {die "Align type not set to known value\n"};
}

sub init_counts() {
	if ($aligntype==1) {init_counts_v1;}
	elsif ($aligntype==2) {init_counts_v2;}
	elsif ($aligntype==3) {init_counts_v2;}
	elsif ($aligntype==4) {init_counts_v2;}
	elsif ($aligntype==10) {init_counts_vg;}
	else {die "Align type not set to known value\n"};
}

#--------------------------------------------------------------------------

sub align_word_v1(\@\@) {
	my ($gseqp,$pseqp) = @_;
	print "<p>-- Enter align_word_v1 @$gseqp to @$pseqp \n" if $debug;
	my $free = $#$gseqp - $#$pseqp;
	if ($free==0) { return 1 }
	#if ($free<0) { die "Error: missing graphemic null" }
	if ($free<0) { 
	 	print "WARNING: missing graphemic null in word @$gseqp";
		@$gseqp=  split //,"dummy";
		@$pseqp= ();
		return 0;
	}

	@gstates = @$gseqp;
	@pstates = split //,join '0',@$pseqp;
	push @pstates,'0'; unshift @pstates,'0';
	$score{0}{0} = $probs{$gstates[0]}{$pstates[0]};@{$btrack{0}{0}} = (0); $cnt0{0}{0} = 1;
	$score{0}{1} = $probs{$gstates[0]}{$pstates[1]};@{$btrack{0}{1}} = (1); $cnt0{0}{1} = 0;
	foreach my $i (2 .. $#pstates) { 
		$score{0}{$i} = 0;
		@{$btrack{0}{$i}} = (); $cnt0{0}{$i} = 0;
	}
	foreach my $t ( 1 .. $#gstates ) {
		foreach my $j ( 0 .. $#pstates ) {
			#print "Find best route to be in $j at time $t\n";
			my $mscore = 0; $imax = 0;
			foreach my $i ( 0 .. $#pstates ) {
				if ($score{$t-1}{$i}<=0){$tscore=0;}
				else {
					#print "<p>Possible route: $i to $j\n";
					my $diff = $j-$i; 
					my $transprob=0;
					if ($pstates[$i] eq '0') {
						if (($diff==1)||(($diff==0)&&($cnt0{$t-1}{$i}<$free))){$transprob=1}
					} else {
						if (($diff==2)||(($diff==1)&&($cnt0{$t-1}{$i}<$free))){$transprob=1}
					}
					#print "p=$t; g=$j; $score{$t-1}{$i}; $probs{$gstates[$t]}; $pstates[$j]; $transprob\n";
					$tscore = $score{$t-1}{$i}*$probs{$gstates[$t]}{$pstates[$j]}*$transprob;
				}
				if ($tscore >= $mscore) {
					$mscore = $tscore; $imax = $i;
				}
			}	
			$score{$t}{$j} = $mscore;
			@{$btrack{$t}{$j}} = @{$btrack{$t-1}{$imax}};
			push @{$btrack{$t}{$j}},$j;
			if ($pstates[$j] eq '0') {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}+1}
			else {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}}
			#print "BEST: [in $i at time $t] : @{$btrack{$t}{$i}} : $mscore <p>";
		}
	}
	my (@tmp,$finscore);
	if ($score{$#gstates}{$#pstates} > $score{$#gstates}{$#pstates-1}) {
		 @tmp = @{$btrack{$#gstates}{$#pstates}};
		 $finscore = $score{$#gstates}{$#pstates};
	} else {
		 @tmp = @{$btrack{$#gstates}{$#pstates-1}}; 
		 $finscore = $score{$#gstates}{$#pstates-1};
	}
	for my $i (0..$#tmp) {$$pseqp[$i] = $pstates[$tmp[$i]]}
	print "Aligned: @$gseqp to @$pseqp\n" if $debug;
	return $finscore;
}

#--------------------------------------------------------------------------

#probs must be initialised beforehand
#align_word(gseq*,pseq*) - given gseq, pseq & probs, adjust pseq to best alignment, return score
#uses format: score{graph_index}{phone_index}

sub getprob(\@\@$$){
	# Calculate prob that this graph should stay in same phone ($p) at time ($t)
	# if @$wordp the word being aligned
	# and @$roadp the current best path at time $t-1 
	
	my ($wordp,$roadp,$p,$t) = @_;
	print "<p>-- Enter getprob $@wordp,@$roadp,$p,$t\n" if $debug;
	
	my $word=join "",@$wordp;
	my $num = $#$roadp;
	my $num2check=2;
	my $pindex = $roadp->[$num];
	$num--;

	#print "getprob $word: $t,$num road=[@$roadp] $pindex\n";
	while (($roadp->[$num] eq $pindex)&&($num>=0)){$num--;$num2check++};

	my $gstr = substr $word,$t-$num2check+1,$num2check;
	my $g = substr $word,$t,1;
	#print "getprob $word: $t,$num $gstr to $p [$g]\n";
	if ((exists $probs0{$gstr})&&(exists $probs0{$gstr}{$p})){
		#print "foundprob $gstr to $p $probs0{$gstr}{$p}\n";
		return $probs0{$gstr}{$p};
	}else {
		#print "not found $gstr to $p $probs0{$g}{$p}\n";
		return $probs0{$g}{$p};
	}
}

sub align_word_v3(\@\@) {
	my ($gseqp,$pseqp) = @_;
	print "<p>-- Enter align_word_v2 @$gseqp to @$pseqp \n" if $debug;
	my $free = $#$gseqp - $#$pseqp;
	if ($free==0) { return 1 }
	#if ($free<0) { die "Error: missing graphemic null" }
	if ($free<0) { 
		@$gseqp=  split //,"dummy";
		@$pseqp= ();
		return 0;
	}

	@gstates = @$gseqp; @pstates = @$pseqp;
	$score{0}{0} = 1.0; @{$btrack{0}{0}} = (0); $cnt0{0}{0} = 0;
	foreach my $i (1 .. $#pstates) { 
		$score{0}{$i} = 0; @{$btrack{0}{$i}} = ($i); $cnt0{0}{$i} = 0;
	}
	foreach my $t ( 1 .. $#gstates ) {
		foreach my $j ( 0 .. $#pstates ) {
			#print "Find best route to be in $j at time $t\n";
			my $mscore = 0; my $imax = 0; 
			foreach my $i ( 0 .. $#pstates ) {
				#print "<p>Possible route: $i to $j\n";
				if ($score{$t-1}{$i}<=0){$tscore=0;}
				else {
					my $p0=0;
					if (($i==$j)&&($cnt0{$t-1}{$i}<$free)) {
						my @road = @{$btrack{$t-1}{$i}};
						my $p0 = getprob(@gstates,@road,$pstates[$i],$t);
						$tscore = $score{$t-1}{$i}*$p0;
					} elsif ($j==$i+1) {
						$tscore = $score{$t-1}{$i}*$probs{$gstates[$t]}{$pstates[$j]};
					} else {
						$tscore = 0;
					}
				}
				#print "[@gstates] [@pstates] [$t][$j][$i] $tscore -- $score{$t-1}{$i} -- $probs{$gstates[$t]}{$pstates[$i]} --$probs0{$gstates[$t]}{$pstates[$i]}\n";
				if ($tscore >= $mscore) {
					$mscore = $tscore; $imax = $i;
				}
			}	
			$score{$t}{$j} = $mscore;
			@{$btrack{$t}{$j}} = @{$btrack{$t-1}{$imax}};
			push @{$btrack{$t}{$j}}, $j;
			my @tmpbt = @{$btrack{$t}{$j}};
			if ($tmpbt[$#tmpbt] eq $tmpbt[$#tmpbt-1]) {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}+1}
			else {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}}
			#print "BEST: [in $j at time $t] : @{$btrack{$t}{$j}} : $mscore <p>\n";
		}
	}
	my @final = @{$btrack{$#gstates}{$#pstates}};
	$$pseqp[0] = $pstates[$final[0]];
	for my $i (1..$#final) {
		if ($final[$i]==$final[$i-1]) { $$pseqp[$i] = '0'}
		else { $$pseqp[$i] = $pstates[$final[$i]] }
	}
	return $score{$#gstates}{$#pstates};
}


#--------------------------------------------------------------------------


#probs must be initialised beforehand
#align_word(gseq*,pseq*) - given gseq, pseq & probs, adjust pseq to best alignment, return score
#uses format: score{graph_index}{phone_index}

sub align_word_v2(\@\@) {
	my ($gseqp,$pseqp) = @_;
	print "<p>-- Enter align_word_v2 @$gseqp to @$pseqp \n" if $debug;
	my $free = $#$gseqp - $#$pseqp;
	if ($free==0) { return 1 }
	#if ($free<0) { die "Error: missing graphemic null" }
	if ($free<0) { 
		@$gseqp=  split //,"dummy";
		@$pseqp= ();
		return 0;
	}

	@gstates = @$gseqp; @pstates = @$pseqp;
	$score{0}{0} = 1.0; @{$btrack{0}{0}} = (0); $cnt0{0}{0} = 0;
	foreach my $i (1 .. $#pstates) { 
		$score{0}{$i} = 0; @{$btrack{0}{$i}} = ($i); $cnt0{0}{$i} = 0;
	}
	foreach my $t ( 1 .. $#gstates ) {
		foreach my $j ( 0 .. $#pstates ) {
			#print "Find best route to be in $j at time $t\n";
			my $mscore = 0; my $imax = 0; 
			foreach my $i ( 0 .. $#pstates ) {
				#print "<p>Possible route: $i to $j\n";
				if (($i==$j)&&($cnt0{$t-1}{$i}<$free)) {
					my @road = @{$btrack{$t-1}{$i}};
					#print "ROAD @road\n";
					my $num = $#road;
					while (($road[$num] eq $j)&&($num>0)){$num--;};
					#while (($road[$num] eq $j)&&($num>0)) {print "inwhile $num $road[$num] $j\n"; $num--; $timestat++};
					$tscore = $score{$t-1}{$i}*$probs0{$gstates[$t]}{$pstates[$i]};
				} elsif ($j==$i+1) {
					$tscore = $score{$t-1}{$i}*$probs{$gstates[$t]}{$pstates[$j]};
				} else {
					$tscore = 0;
				}
				#print "[@gstates] [@pstates] [$t][$j][$i] $tscore -- $score{$t-1}{$i} -- $probs{$gstates[$t]}{$pstates[$i]} --$probs0{$gstates[$t]}{$pstates[$i]}\n";
				if ($tscore >= $mscore) {
					$mscore = $tscore; $imax = $i;
				}
			}	
			$score{$t}{$j} = $mscore;
			@{$btrack{$t}{$j}} = @{$btrack{$t-1}{$imax}};
			push @{$btrack{$t}{$j}}, $j;
			my @tmpbt = @{$btrack{$t}{$j}};
			if ($tmpbt[$#tmpbt] eq $tmpbt[$#tmpbt-1]) {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}+1}
			else {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}}
			#print "BEST: [in $j at time $t] : @{$btrack{$t}{$j}} : $mscore <p>\n";
		}
	}
	my @final = @{$btrack{$#gstates}{$#pstates}};
	$$pseqp[0] = $pstates[$final[0]];
	for my $i (1..$#final) {
		if ($final[$i]==$final[$i-1]) { $$pseqp[$i] = '0'}
		else { $$pseqp[$i] = $pstates[$final[$i]] }

	}
	print "Aligned: @$gseqp to @$pseqp\n" if $debug;
	return $score{$#gstates}{$#pstates};
}


sub align_word_v4(\@\@) {
	my ($gseqp,$pseqp) = @_;
	print "<p>-- Enter align_word_v4 @$gseqp to @$pseqp \n" if $debug;
	my $free = $#$gseqp - $#$pseqp;
	if ($free==0) {return 1;}
	if ($free<0) {return 0;}

	@gstates = @$gseqp; @pstates = @$pseqp;
	$score{0}{0} = 1.0; @{$btrack{0}{0}} = (0); $cnt0{0}{0} = 0;
	foreach my $i (1 .. $#pstates) { 
		$score{0}{$i} = 0; @{$btrack{0}{$i}} = ($i); $cnt0{0}{$i} = 0;
	}
	foreach my $t ( 1 .. $#gstates ) {
		foreach my $j ( 0 .. $#pstates ) {
			#print "Find best route to be in $j at time $t\n";
			my $mscore = 0; my $imax = 0; 
			foreach my $i ( 0 .. $#pstates ) {
				#print "<p>Possible route: $i to $j\n";
				if (($i==$j)&&($cnt0{$t-1}{$i}<$free)) {
					my @road = @{$btrack{$t-1}{$i}};
					#print "ROAD @road\n";
					my $num = $#road;
					while (($road[$num] eq $j)&&($num>0)){$num--;};
					#while (($road[$num] eq $j)&&($num>0)) {print "inwhile $num $road[$num] $j\n"; $num--; $timestat++};
					$tscore = $score{$t-1}{$i}*$probs0{$gstates[$t]}{$pstates[$j]};
				} elsif ($j==$i+1) {
					$tscore = $score{$t-1}{$i}*$probs{$gstates[$t]}{$pstates[$j]};
				} else {
					$tscore = 0;
				}
				#print "[@gstates] [@pstates] [$t][$j][$i] $tscore -- $score{$t-1}{$i} -- $probs{$gstates[$t]}{$pstates[$i]} --$probs0{$gstates[$t]}{$pstates[$i]}\n";
				if ($tscore >= $mscore) {
					$mscore = $tscore; $imax = $i;
				}
			}	
			$score{$t}{$j} = $mscore;
			@{$btrack{$t}{$j}} = @{$btrack{$t-1}{$imax}};
			push @{$btrack{$t}{$j}}, $j;
			my @tmpbt = @{$btrack{$t}{$j}};
			if ($tmpbt[$#tmpbt] eq $tmpbt[$#tmpbt-1]) {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}+1}
			else {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}}
			#print "BEST: [in $j at time $t] : @{$btrack{$t}{$j}} : $mscore <p>\n";
		}
	}
	my @final = @{$btrack{$#gstates}{$#pstates}};
	$$pseqp[0] = $pstates[$final[0]];
	for my $i (1..$#final) {
		if ($final[$i]==$final[$i-1]) { $$pseqp[$i] = '0'}
		else { $$pseqp[$i] = $pstates[$final[$i]] }

	}
	print "Aligned: @$gseqp to @$pseqp\n" if $debug;
	return $score{$#gstates}{$#pstates};
}


#--------------------------------------------------------------------------

sub align_word(\@\@) {
	my ($gseqp,$pseqp) = @_;
	if ($aligntype==1) {return align_word_v1(@$gseqp,@$pseqp);}
	elsif ($aligntype==2) {return align_word_v2(@$gseqp,@$pseqp);}
	elsif ($aligntype==3) {return align_word_v3(@$gseqp,@$pseqp);}
	elsif ($aligntype==4) {return align_word_v4(@$gseqp,@$pseqp);}
	else {die "Align type not set to known value\n"};
}

#--------------------------------------------------------------------------

sub count_equal(\%) {
	print "-- Enter count_equal" if $debug;
	my $dictp = shift @_;
	my ($word,@pseq,@gseq);
	foreach $word (keys %$dictp) {
		$act_word = $word;
		$act_word =~ s/^(.*)_(.*)$/$1/g;
		if ( (length $act_word) == (length $dictp->{$word}) ) {
			@pseq = split //,$dictp->{$word};
			@gseq = split //,$act_word;
			foreach $i ( 0 .. $#gseq ) {
				$counts{$gseq[$i]}{$pseq[$i]}++;
				#print "<p>$counts{$gseq[$i]}{$pseq[$i]}"
			}
		}
	}
}


sub init_probs(\%) {
	print "-- Enter init_probs" if $debug;
	my $dictp = shift @_;
	my ($word,@pseq,@gseq);
	init_counts;
	count_equal(%$dictp);
	update_probs;
}


#--------------------------------------------------------------------------

sub add_word_gnulls(\@\@) {
	#Add graphemic nulls to a single word-sound pair
	
	my ($gseqp,$pseqp) = @_;
	print "<p>-- Enter add_word_gnulls @$gseqp to @$pseqp \n" if $debug;
	my $free = $#$pseqp - $#$gseqp;

	@gstates = @$gseqp; @pstates = @$pseqp;
	unshift @gstates,'0';
	$score{0}{0} = $probs{$gstates[0]}{$pstates[0]}; @{$btrack{0}{0}} = (0); $cnt0{0}{0} = 1;
	$score{0}{1} = $probs{$gstates[1]}{$pstates[0]}; @{$btrack{0}{1}} = (1); $cnt0{0}{1} = 0;
	foreach my $i (2 .. $#gstates) { 
		$score{0}{$i} = 0; @{$btrack{0}{$i}} = ($i); $cnt0{0}{$i} = 0;
	}
	foreach my $t ( 1 .. $#pstates ) {
		foreach my $j ( 0 .. $#gstates ) {
			#print "Find best route to be in $j at time $t\n";
			my $mscore = 0; my $imax = 0; 
			foreach my $i ( 0 .. $#gstates ) {
				#print "<p>Possible route: $i to $j\n";
				if (($i==$j)&&($cnt0{$t-1}{$i}<$free)){
					$tscore = $score{$t-1}{$i}*$probs{'0'}{$pstates[$t]};
					#print "[@pstates] [@gstates] at $t($pstates[$t]) in $j($gstates[$j]) from $i ($gstates[$i]) $tscore = $score{$t-1}{$i} * $probs{'0'}{$pstates[$t]}  --\n";
				} elsif ($j==$i+1) {
					$tscore = $score{$t-1}{$i}*$probs{$gstates[$j]}{$pstates[$t]};
					#print "[@pstates] [@gstates] at $t($pstates[$t]) in $j($gstates[$j]) from $i ($gstates[$i]) $tscore = $score{$t-1}{$i} * $probs{$gstates[$j]}{$pstates[$t]}  --\n";
				} else {
					$tscore = 0;
				}
				if ($tscore >= $mscore) {
					$mscore = $tscore; $imax = $i;
				}
			}	
			$score{$t}{$j} = $mscore;
			@{$btrack{$t}{$j}} = @{$btrack{$t-1}{$imax}};
			push @{$btrack{$t}{$j}}, $j;
			my @tmpbt = @{$btrack{$t}{$j}};
			if ($tmpbt[$#tmpbt] eq $tmpbt[$#tmpbt-1]) {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}+1}
			else {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}}
			#print "BEST: [in $j at time $t] : @{$btrack{$t}{$j}} : $mscore <p>\n";
		}
	}
	my @final = @{$btrack{$#pstates}{$#gstates}};
	$$gseqp[0] = $gstates[$final[0]];
	for my $i (1..$#final) {
		if ($final[$i]==$final[$i-1]) { $$gseqp[$i] = '0'}
		else { $$gseqp[$i] = $gstates[$final[$i]] }

	}
	print "Aligned: [@$gseqp] to [@$pseqp]\n" if $debug;
	return $score{$#pstates}{$#gstates};
}


sub mk_gnull_list(\%\%) {
	my ($dictp,$gnullp) = @_;
	print "<p>-- Finding gnulls -- \n" if $msg;
	my %gnullwrds=();
	my %gnullsnds=();
	my %gnullpos=();
	my ($tprob,$pprob,$threshold) = (0,0,1);
	init_probs(%{$dictp}); 
	#show_counts;
	#show_probs(%probs,%probs);
	while (($pprob==0)||($tprob/$pprob>$threshold)) {
		$pprob=$tprob;
		$tprob = 0;
		print "\n<p>-- Gnulls: Redo probabilities -- $pprob\n" if $msg;
		init_counts;
		count_equal(%{$dictp}); 
		foreach my $word (keys %$dictp) {
			my $actword = $word;
			$actword =~ s/^(.*)_.*$/$1/;
			if (length $actword < length $dictp->{$word}) {
				@gseq = split //, $actword;
				@pseq = split //, $dictp->{$word};
				$tprob+=add_word_gnulls(@gseq,@pseq);
				@{$gnullwrds{$word}} = @gseq;
				@{$gnullsnds{$word}} = @pseq;
				foreach my $i ( 0 .. $#gseq ) {
					$counts{$gseq[$i]}{$pseq[$i]}++;
				}
			}
		}
		last if ($tprob==0);
		#show_counts;
		update_probs;
		#show_probs(%probs,%probs);
	}

	my %show=%gnullwrds;
	while (my ($key,$val) = each %show) {print "$key @$val @{$gnullsnds{$key}}\n";}

	my $left=0;
	foreach my $word (keys %gnullwrds) {
		my $gword = join "",@{$gnullwrds{$word}};
		my $gpos=index($gword,'0');
		while ($gpos!=-1) {
			my $toadd;
			if ($gpos==0){$toadd = " ".substr $gword,$gpos,2;}
			elsif ($gpos==(length($gword)-1)){$toadd = substr($gword,$gpos-1,2)." ";}
			else {$toadd = substr $gword,$gpos-1,3;}
			if ($toadd !~ /00/){ #only expand 1 at at time
				if (exists $gnullpos{$toadd}) {$gnullpos{$toadd}++;}
				else {$gnullpos{$toadd}=1;}
				#print "Adding $toadd because of $word,$gword\n";
			} else { $left=1 }
			$gpos=index($gword,'0',$gpos+1);
		}	
	}
	%$gnullp=();
	print "Gnulls found:\n" if $msg;
	foreach my $replaceby (keys %gnullpos) {
		#my $toreplace = substr $replaceby,0,1;
		#$toreplace = $toreplace.substr $replaceby,2,1;
		my $toreplace = substr($replaceby,0,1).substr($replaceby,2,1);
		$gnullp->{$toreplace}=$replaceby;
		print "[$toreplace]->[$replaceby]\n" if $msg;
	}
	return $left;
}


sub add_gnull_word($\%) {
	my ($word,$gnullp) = @_;
	print "-- Enter add_gnull_word: $word" if $debug;
	while (my ($gfind,$greplace)=each %{$gnullp}) {
		if ($word =~ /(.*)_(.*)/) {
			$word=$1;
			$tail=$2;
		} else {
			$tail="";
		}
		$word = " ".$word." ";
		if ($word =~ /$gfind/) {
			$word =~ s/$gfind/$greplace/g;
		}
		$word=~s/ //g;
                if (!($tail eq "")) { 
			$word=$word."_".$tail;
		}
	}
	return $word;
}


sub add_gnull_list(\%\%) {
	my ($dictp,$gnullp) = @_;
	print "-- Enter add_gnull_list" if $debug;
	# JWFT - 3 June 2014:
	# The following causes a bug in perl 5.18.2
	# See: http://blogs.perl.org/users/rurban/2014/04/do-not-use-each.html
	# while (my ($word,$sound)=each %$dictp) {
	foreach my $word (keys %{$dictp}) {
		my $sound = ${$dictp}{$word};
		$newword = add_gnull_word($word,%$gnullp);
		if (!($newword eq $word)) {
			#if (exist $dictp->{$newword}) {
			#	print "ERROR - check gnull process\n";
			#} else {
				$dictp->{$newword}=$sound;
				delete $dictp->{$word};
			#}
		}
	}
}


sub fwrite_gnull_list(\%$) {
	my ($gnullp,$fname) = @_;
	print "-- Enter fwrite_gnull_list: $fname\n" if $debug;
	open OH, ">:encoding(utf8)", "$fname" or die;
	while (my ($find,$replace)=each %$gnullp){
		print OH "$find;$replace\n";
	}
}


sub fread_gnull_list($\%) {
	my ($fname,$gnullp) = @_;
	print "-- Enter fread_gnull_list: $fname\n" if $debug;
	open IH, "<:encoding(utf8)", "$fname" or die "Error opening $fname\n";
	%$gnullp=();
	while (<IH>) {
		chomp;
		@line=split /;/;
		$gnullp->{$line[0]}=$line[1];
	}
}


sub rm_alignprob_words(\%\%){
	my ($dp,$sp) = @_;
	foreach my $word (keys %$dp) {
		my $actword = $word;
		$actword =~ s/^(.*)_.*$/$1/g;
		if (length $actword < length $dp->{$word}) {
			delete $dp->{$word};
			delete $sp->{$word};
		}
	}
}


sub align_dict(\%\%\%\%$) {
	#Align dictionary pointed to by $dictp and store aligned strings in hashes $agdp->{word}=graphs of word and $apdp->{word}=phones of word
	#Store list of graphemic nulls via $gnullp
	#use Math::BigFloat;
	#my $cnt_thold=0.09;
	local ($dictp,$agdp,$apdp,$gnullp,$pre) = @_;
	print "-- Enter align_dict " if $debug;
	local (@gseq,@pseq);

	if ($aligntype==4) {
		print "<p>-- Insert g-nulls --\n" if $msg;
		if ($pre==1) {
			add_gnull_list(%$dictp,%$gnullp);
		} else {
			$aligntype=10;
			do {
				my %tmpgnulls=();
				$left = mk_gnull_list(%$dictp,%tmpgnulls);
				if (scalar %tmpgnulls) {
					add_gnull_list(%$dictp,%tmpgnulls);
					%$gnullp=(%$gnullp,%tmpgnulls);
				} elsif ($left==1) {
					$left=0;
					rm_alignprob_words(%dict,%stat);
				}
			} while ($left);
			$aligntype=4;
		} 
	}
	
	print "<p>-- Initialise probabilities --\n" if $msg;
	init_probs(%{$dictp}); 
	#show_probs(%probs,%probs0) if $debug;
	#change to get first from first run
	my ($tprob,$pprob,$threshold) = (0,0,1);
	while (($pprob==0)||($tprob/$pprob > $threshold)) {
		$pprob=$tprob;
		$tprob = 0;
		print "\n<p>-- Redo probabilities -- $pprob\n" if $msg;
		my $i=0;
		init_counts;
		foreach $word (keys %$dictp) {
			my $gword = $word;
			$gword =~ s/^(.*)_.*$/$1/;
			@gseq = split //, $gword;
			@pseq = split //, $dictp->{$word};
			$wprob = align_word(@gseq,@pseq);
			$tprob += $wprob;
		
			#my $bigwprob = Math::BigFloat->new($wprob);
			#my $wlen = length $gword;
			#my $cprob = $bigwprob->broot($wlen);
			#$i++; print "-Align $i- [@gseq][@pseq] $wprob\n" if $msg;
			
			@{$agdp->{$word}} = @gseq;
			@{$apdp->{$word}} = @pseq;
			next if (join("",@gseq) eq "dummy");
			foreach my $i ( 0 .. $#gseq ) {
				if ($aligntype==1){
					$counts{$gseq[$i]}{$pseq[$i]}++; 
				} elsif (($aligntype==2)||($aligntype==4)) {
					if ($pseq[$i] eq '0') { 
						my $cnt = $i-1; my $gstr="";
						while ($pseq[$cnt] eq '0') {$cnt--;}
						$counts0{$gseq[$i]}{$pseq[$cnt]}++;
					} else {$counts{$gseq[$i]}{$pseq[$i]}++;}
				} elsif ($aligntype==3) {
					#if ($cprob>$cnt_thold) {
						if ($pseq[$i] eq '0') { 
							my $cnt = $i-1; my $gstr="";
							while ($pseq[$cnt] eq '0') {$cnt--;}
							my $strlen = $i-$cnt+1;
							$gstr = substr $gword,$cnt,$strlen;
							$counts0{$gstr}{$pseq[$cnt]}++;
							#print "HERE: counting $gstr to $pseq[$cnt] [$strlen]\n";
						} else {$counts{$gseq[$i]}{$pseq[$i]}++;}
					#}
				}
			}
		}
		print "Current dict score: $tprob\n" if $msg;
		update_probs;
		#show_counts if $debug;
		#show_probs(%probs,%probs0) if $debug; 
	} 
}
	

#--------------------------------------------------------------------------

sub fread_align($\%\%) {
	my ($fname,$agdp,$apdp) = @_;
	print "-- Enter fread_align: $fname\n" if $debug;
	open IH, "<:encoding(utf8)", "$fname" or die "Cannot read file $fname\n";
	%$agdp = (); %$apdp = (); my %dict=();
	while (<IH>) {
		chomp;
		my ($word,$gseq,$pseq,$pos);
		my @line = split /;/;
		if (scalar @line >= 3) {
			$word =$line[0];
			$gseq=$line[1];
			$pseq=$line[2];
		} else {
			die "Error: align format error: @line in $fname"
		}
		if ($dictType==$doubleType{'pos_one'}) {
			die "Error: Dictionary format @line" if scalar @line != 4;
			$pos=$line[3];
		}
		if (exists $dict{$word}) { 
			if ($dictType==$doubleType{'none'}) {
                        	print "Warning: double removed ($word)\n" if $debug;
				delete $agdp->{$word};
				delete $apdp->{$word};
			} elsif ($dictType==$doubleType{'one'}) { 
                        	print "Warning: not adding double ($word)\n" if $debug;
			} elsif ($dictType==$doubleType{'pos_one'}) {
				if (exists $dict{$word}{$pos}) {
					print "Warning: not adding double ($word,$pos)\n" if $msg;
				} else {
					@{$agdp->{$word}{$pos}} = split / /,$gseq;
					@{$apdp->{$word}{$pos}} = split / /,$pseq;
					$dict{$word}{$pos}=1;
				}
			} elsif ($dictType==$doubleType{'all'}) {
				my $newi=1;
				my $newword = "${word}_$newi";
				my $found=0;
				while (!$found) { 
					if (exists $dict{$newword}) {$newi++;$newword="${word}_$newi"} 
					else {$found=1}
				}
				@{$agdp->{$newword}} = split / /,$gseq;
                        	@{$apdp->{$newword}} = split / /,$pseq;
				$dict{$newword}=1;
                        	print "Warning: adding a double ($newword)\n" if $debug;
			} else {
				die "Dictionary double type $dictType unknown";
			}
		} else {	
			if ($dictType==$doubleType{'pos_one'}) {
				$dict{$word}{$pos}=1;
				@{$agdp->{$word}{$pos}} = split / /,$gseq;
				@{$apdp->{$word}{$pos}} = split / /,$pseq;
			} else {	
				$dict{$word}=1; 
				@{$agdp->{$word}} = split / /,$gseq;
				@{$apdp->{$word}} = split / /,$pseq;
			}
		}
	}
	close IH;
}


sub fwrite_align($\%\%\%) {
	my ($fname,$dictp,$agdp,$apdp) = @_;
	print "-- Enter fwrite_align: $fname\n" if $debug;
	open OH, ">:encoding(utf8)", "$fname" or die;
	foreach my $w (sort keys %$dictp){
		if ($dictType==$doubleType{'pos_one'}) {
			$towrite = $w;
			$towrite =~ s/0//g;
			foreach my $f (keys %{$agdp->{$w}}) {
				my @gseq = @{$agdp->{$w}{$f}};
				my @pseq = @{$apdp->{$w}{$f}};
				my @gseqtowrite=();
				my @pseqtowrite =();
				for my $i (0..$#pseq) {
					#if (!(($pseq[$i]eq'0')&&($gseq[$i]eq'0'))){
					push @pseqtowrite,$pseq[$i];
					push @gseqtowrite,$gseq[$i];
					#}
				}
				print OH "$towrite;@gseqtowrite;@pseqtowrite;$f\n";
			}
		} else {
			my $towrite = $w;
			$towrite =~ s/^(.*)_.*$/$1/;
			$towrite =~ s/0//g;
			my @gseq = @{$agdp->{$w}};
			my @pseq = @{$apdp->{$w}};
			my @gseqtowrite=();
			my @pseqtowrite =();
			for my $i (0..$#pseq) {
				#if (!(($pseq[$i]eq'0')&&($gseq[$i]eq'0'))){
				push @pseqtowrite,$pseq[$i];
				push @gseqtowrite,$gseq[$i];
				#}
			}
			print OH "$towrite;@gseqtowrite;@pseqtowrite\n";
		}
	}
	close OH;
}


sub fexpand_write_align($\%\%\%) {
	my ($fname,$dictp,$agdp,$apdp) = @_;
	print "-- Enter fwrite_align: $fname\n" if $debug;
	open OH, ">:encoding(utf8)", "$fname" or die;
	foreach my $w (sort keys %$dictp){
		my $towrite = $w;
		$towrite =~ s/^(.*)_(.*)$/$1/g;
		my $pos = $2;
		$towrite =~ s/0//g;
		my @gseq = @{$agdp->{$w}};
		my @pseq = @{$apdp->{$w}};
		my @gseqtowrite=();
		my @pseqtowrite =();
		for my $i (0..$#pseq) {
			#if (!(($pseq[$i]eq'0')&&($gseq[$i]eq'0'))){
				push @pseqtowrite,$pseq[$i];
				push @gseqtowrite,$gseq[$i];
			#}
		}
		print OH "$towrite;@gseqtowrite;@pseqtowrite;$pos\n";
	}
	close OH;
}


#--------------------------------------------------------------------------

sub dict_hide_extra(\%\%) {
	my ($indp,$outdp)=@_;
	foreach my $w (keys %$indp) {
		my @poslist=keys %{$indp->{$w}};
		foreach my $pos (@poslist) {
			$outdp->{"${w}_$pos"}=$indp->{$w}{$pos};
		}
	}
}

#sub dict_show_extra(\%\%) {
#	my ($indp,$outdp)=@_;
#	foreach my $w (keys %$indp) {
#		if ($w ~= /(.*)_(.*))/) {
#			$outdp->{$1}{$2}=$indp->{$w};
#		} else {
#			die "Error: wrong format for word $w\n";
#		}
#	}
#}


sub falign_dict($$$$) {
	my ($dname,$aname,$gname,$pre) = @_;
	print "-- Enter falign_dict: $dname, $aname,$gname,$pre\n" if $debug;
	local (%dict,%stat,%agd,%apd);	
	print "<p>-- Reading dictionary --\n" if $msg;
	fread_dict($dname,%dict,%stat);
	rm_notcorrect_dict(%dict,%stat);
	print "<p>-- Aligning dictionary --\n" if $msg;
	%gnulls=();
	if ($pre==1) {
		fread_gnull_list($gname,%gnulls);
	}
	if ($dictType==$doubleType{'pos_one'}) {
		dict_hide_extra(%dict,%newdict);
		align_dict(%newdict,%agd,%apd,%gnulls,$pre);
		fexpand_write_align($aname,%newdict,%agd,%apd);
	} else {
		align_dict(%dict,%agd,%apd,%gnulls,$pre);
		fwrite_align($aname,%dict,%agd,%apd);
	}
	fwrite_gnull_list(%gnulls,$gname);
}


sub fcmp_aligned($$$) {
	my ($a1,$a2,$resname) = @_;
	print "-- Enter fcmp_aligned: $a1, $a2,$resname\n" if $debug;
	open OH, ">:encoding(utf8)", "$resname" or die "Error opening $resname\n";
	
	local (%agd1,%apd1,%agd2,%apd2);	
	fread_align($a1,%agd1,%apd1);
	fread_align($a2,%agd2,%apd2);
	my %res=();
	$res{'same'}=0;
	$res{'gdiff'}=0;
	$res{'pdiff'}=0;
	$res{'only1'}=0;
	$res{'only2'}=0;
	foreach my $word (keys %agd1) {
		if (exists $agd2{$word}) {
			my $gstr1=join "",@{$agd1{$word}};
			my $pstr1=join "",@{$apd1{$word}};
			my $gstr2=join "",@{$agd2{$word}};
			my $pstr2=join "",@{$apd2{$word}};
			if (($gstr1 eq $gstr2)&&($pstr1 eq $pstr2)) {$res{'same'}++;}
			if (!($gstr1 eq $gstr2)||!($pstr1 eq $pstr2)) {
				print OH "[$word]\t$gstr1\t$gstr2\n[$word]\t$pstr1\t$pstr2\n";
			}
			if (!($gstr1 eq $gstr2)) {$res{'gdiff'}++;}
			if (!($pstr1 eq $pstr2)) {$res{'pdiff'}++;}

		} else {$res{'only1'}++;}
	}
	foreach my $word (keys %agd1) {
		if (!(exists $agd2{$word})){$res{'only2'}++;}
	}
	while (my ($key,$val)=each %res){
		print OH "$key\t$val\n";
	}
}

#--------------------------------------------------------------------------

sub fprobs_from_aligned ($) {
	my $dname = shift @_;
	print "-- Enter fprobs_from_aligned: $dname\n" if $debug;
	open FH, "<:encoding(utf8)", "$dname" or die;
	init_counts; 
	while (<FH>) {
		@line = split ";",$_;
		@gseq = split / /,$line[1];
		@pseq = split / /,$line[2];
		foreach $i ( 0 .. $#gseq ) {
			if ($pseq[$i] eq '0') { $counts0{$gseq[$i]}{$pseq[$i-1]}++ }
			else { $counts{$gseq[$i]}{$pseq[$i]}++ }
		}
	}
	update_probs;
}

sub fadd_aligned($$$) {
	my ($word,$sound,$dname) = @_;
	print "-- Enter fadd_aligned: $word,$sound,$dname\n" if $debug;
	open FP, ">>:encoding(utf8)", "$dname" or die;
	fprobs_from_aligned($dname);
	my %gnulls=();
	fread_gnull_list($glist,%gnulls);
	add_gnull_word($word,%gnulls);
	if (length $word >= length $sound) {
		my @gseq = split //,$word;
		my @pseq = split //,$sound;
		align_word(@gseq,@pseq);
		print FP "$word".";"."@gseq".";"."@pseq"."\n";
		close FP;
	}
}

sub frm_aligned ($$) {
	my ($word,$dname) = @_;
	print "-- Enter frm_aligned: $word,$dname\n" if $debug;
	`sed -i /^$word;/d`;
}

#--------------------------------------------------------------------------

sub faligned($) {
	my ($dname) = @_;
	my $aname = "$dname.aligned";
	if (! -e $dname) {die "File $dname does not exist\n"};
	if (! -e $aname) {return 0};
	my $dtime = `stat -c%Z $dname`;
	my $atime = `stat -c%Z $aname`;
	if ($dtime<$atime) {return 1}
	else {return 0}
}

#--------------------------------------------------------------------------

sub id_gnulls($) {
	my $dname = shift @_;
	local (%dict,%stat);
	my %possible=();
	fread_dict($dname,%dict,%stat);
	my $max=0;
	while (my ($word,$pron)=each %dict) {
		if (length $word < length $pron) {
			print "$word = $pron\n";
		}
		if (length $word > $max) {
			$max=length $word;
		}
	}
	print "Longest word: $max\n";	
}

#--------------------------------------------------------------------------

sub walign_init_probs() {
	print "-- Enter walign_init_probs" if $debug;
	local (@phones);
	push @phones,'0';
	read_phones(@phones); 
	foreach my $p1 ( @phones ) {
		foreach my $p2 ( @phones ) {
			if ($p1 eq $p2) {$probs{$p1}{$p2} = 1.0;}
			elsif (($p1 eq '0')||($p2 eq '0')) {$probs{$p1}{$p2} = 0.1;}
			else {$probs{$p1}{$p2} = 0.4;}
		}
	}
}

sub walign_word(\@\@) {
	my ($gseqp,$pseqp) = @_;
	print "<p>-- Enter walign_word @$gseqp to @$pseqp \n" if $debug;
	my $free = $#$gseqp - $#$pseqp;
	if ($free==0) { return 1 }
	if ($free<0) { die "Error: missing graphemic null" }

	@gstates = @$gseqp;
	@pstates = split //,join '0',@$pseqp;
	push @pstates,'0'; unshift @pstates,'0';
	$score{0}{0} = $probs{$gstates[0]}{$pstates[0]};@{$btrack{0}{0}} = (0); $cnt0{0}{0} = 1;
	$score{0}{1} = $probs{$gstates[0]}{$pstates[1]};@{$btrack{0}{1}} = (1); $cnt0{0}{1} = 0;
	foreach my $i (2 .. $#pstates) { 
		$score{0}{$i} = 0;
		@{$btrack{0}{$i}} = (); $cnt0{0}{$i} = 0;
	}
	foreach my $t ( 1 .. $#gstates ) {
		foreach my $j ( 0 .. $#pstates ) {
			#print "Find best route to be in $j at time $t\n";
			my $mscore = 0; $imax = 0;
			foreach my $i ( 0 .. $#pstates ) {
				#print "<p>Possible route: $i to $j\n";
				my $diff = $j-$i; 
				my $transprob=0;
				if ($pstates[$i] eq '0') {
					if (($diff==1)||(($diff==0)&&($cnt0{$t-1}{$i}<$free))){$transprob=1}
				} else {
					if (($diff==2)||(($diff==1)&&($cnt0{$t-1}{$i}<$free))){$transprob=1}
				}
				#print "HERE p=$t; g=$j; $score{$t-1}{$i}; $probs{$gstates[$t]}; $pstates[$j]; $transprob\n";
				$tscore = $score{$t-1}{$i}*$probs{$gstates[$t]}{$pstates[$j]}*$transprob;
				if ($tscore >= $mscore) {
					$mscore = $tscore; $imax = $i;
				}
			}	
			$score{$t}{$j} = $mscore;
			@{$btrack{$t}{$j}} = @{$btrack{$t-1}{$imax}};
			push @{$btrack{$t}{$j}},$j;
			if ($pstates[$j] eq '0') {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}+1}
			else {$cnt0{$t}{$j} = $cnt0{$t-1}{$imax}}
			#print "BEST: [in $i at time $t] : @{$btrack{$t}{$i}} : $mscore <p>";
		}
	}
	my (@tmp,$finscore);
	if ($score{$#gstates}{$#pstates} > $score{$#gstates}{$#pstates-1}) {
		 @tmp = @{$btrack{$#gstates}{$#pstates}};
		 $finscore = $score{$#gstates}{$#pstates};
	} else {
		 @tmp = @{$btrack{$#gstates}{$#pstates-1}}; 
		 $finscore = $score{$#gstates}{$#pstates-1};
	}
	for my $i (0..$#tmp) {$$pseqp[$i] = $pstates[$tmp[$i]]}
	print "Aligned: @$gseqp to @$pseqp\n" if $debug;
	return $finscore;
}


sub cmp_result(\@\@\%) {
	my ($word1p,$word2p,$resp) = @_;
	print "-- Enter cmp_result @$word1p,@$word2p\n" if $debug;
	$resp->{'add'}=0; $resp->{'del'}=0; $resp->{'sub'}=0; 
	foreach my $p (0..$#$word1p) {
		if ($word1p->[$p] eq '0') {$resp->{'add'}++} 
		elsif ($word2p->[$p] eq '0') {$resp->{'del'}++}
		elsif (!($word1p->[$p] eq $word2p->[$p])) {$resp->{'sub'}++}
	}
	$resp->{'total'}=$resp->{'add'}+$resp->{'del'}+$resp->{'sub'};
}


sub compare_words($$\%) {
	my ($word1,$word2,$resp) = @_;
	if (length $word2 == 0) {
			$resp->{'del'}=length $word1;
			$resp->{'add'}=0;
			$resp->{'sub'}=0;
			$resp->{'total'}=$resp->{'del'}
	} elsif (length $word1 == 0) {
			$resp->{'add'}=length $word2;
			$resp->{'del'}=0;
			$resp->{'sub'}=0;
			$resp->{'total'}=$resp->{'add'}
	} else { 
		my @w1 = split "",$word1;
		my @w2 = split "",$word2;
		if ((length $word1) == (length $word2)) { 
			cmp_result(@w1,@w2,%$resp);
		} elsif (length $word2 < length $word1) {
			walign_init_probs;
			walign_word(@w1,@w2);
			cmp_result(@w1,@w2,%$resp);
		} else {
			walign_init_probs;
			walign_word(@w2,@w1);
			cmp_result(@w1,@w2,%$resp);
		}
	}
}

#--------------------------------------------------------------------------

sub init_acc_probs($\%) {
	my ($phonfn,$scorep)=@_;
	print "-- Enter init_acc_probs" if $debug;
	#Initialises scores to mimic HResults (note that different weights for NIST align) 
	my @phones;
	fread_array(@phones,$phonfn); 
	%$scorep=();
	foreach my $p1 (@phones) {
		foreach my $p2 (@phones) {
			if ($p1 eq '0'){
				$scorep->{$p1}{$p2} = 7;
			} elsif ($p2 eq '0'){
				$scorep->{$p1}{$p2} = 7;
			} elsif ($p1 eq $p2) {
				$scorep->{$p1}{$p2} = 0;
			} else {
				$scorep->{$p1}{$p2} = 10;
			}
		}
	}
}

sub full_align_word(\%\@\@) {
	my ($scorep,$phon1p,$phon2p) = @_;
	print "<p>-- Enter full_align_word @$phon1p to @$phon2p \n" if $debug;

	my %cost=();
	my %btrackx=();
	my %btracky=();
	my @statesx = (0,@$phon1p);
	my @statesy = (0,@$phon2p);
	$cost{0}{0} = 0.0;
	@{$btrackx{0}{0}} = (0);
	@{$btracky{0}{0}} = (0);
	foreach my $y (1 .. $#statesy) { 
		$cost{0}{$y} = 7+$cost{0}{$y-1};
		@{$btrackx{0}{$y}} = (@{$btrackx{0}{$y-1}},'0');
		@{$btracky{0}{$y}} = (@{$btracky{0}{$y-1}},$y);
	}
	foreach my $x ( 1 .. $#statesx ) {
		foreach my $y ( 0 .. $#statesy ) {
			#print "Find best route to be in $y at position $x\n";
			my $minscore = 1000;
			my (@tbackx,@tbacky);
			foreach my $i (1..3) { #Only 3 paths possible (limiting paths rather than using transition probs)
				my $tscore=1000;
				if (($i==1)&&($y>0)) {
					#move along x and y
					$tscore = $cost{$x-1}{$y-1}+$scorep->{$statesx[$x]}{$statesy[$y]};
					@tbackx = (@{$btrackx{$x-1}{$y-1}},$x);
					@tbacky = (@{$btracky{$x-1}{$y-1}},$y);
				} elsif ($i==2) {
					#move along x only
					$tscore = $cost{$x-1}{$y}+$scorep->{$statesx[$x]}{'0'};
					@tbackx = (@{$btrackx{$x-1}{$y}},$x);
					@tbacky = (@{$btracky{$x-1}{$y}},'0');
				} elsif (($i==3)&&($y>0)) {	
					#move along y only
					$tscore = $cost{$x}{$y-1}+$scorep->{'0'}{$statesy[$y]};
					@tbackx = (@{$btrackx{$x}{$y-1}},'0');
					@tbacky = (@{$btracky{$x}{$y-1}},$y);
				}
				if ($tscore < $minscore) {
					$minscore = $tscore;
					@bestbackx=@tbackx;
					@bestbacky=@tbacky;
				}
			}	
			$cost{$x}{$y} = $minscore;
			@{$btrackx{$x}{$y}} = @bestbackx;
			@{$btracky{$x}{$y}} = @bestbacky;
		}
	}
	my @finalx = @{$btrackx{$#statesx}{$#statesy}};
	my @finaly = @{$btracky{$#statesx}{$#statesy}};
	for my $i (0..$#finalx) {
		$phon1p->[$i]= $statesx[$finalx[$i]];
		$phon2p->[$i]= $statesy[$finaly[$i]];
	}
	if (($phon1p->[0] eq '0')&&($phon2p->[0] eq '0')) {
		shift @$phon1p;
		shift @$phon2p;
	}
	
	print "Aligned: @$phon1p to @$phon2p\n" if $debug;
	return $cost{$#statesx}{$#statesy};
}

#--------------------------------------------------------------------------

sub score_match($$\%\@\@) {
	my ($w1,$w2,$scorep,$phon1p,$phon2p) = @_;
	@$phon1p = split //,$w1;
	@$phon2p = split //,$w2;
	return full_align_word(%$scorep,@$phon1p,@$phon2p);
}

sub count_phon_acc(\@\@\%\%\%\%) {
	#Updates phone accuracy: $pron1p reference value, $pron2p generated value
	my ($pron1p,$pron2p,$pcorrp,$pinsertp,$pdeletep,$pwrongp) =@_;
	foreach my $i (0..$#$pron1p) {
		if ($pron1p->[$i] eq $pron2p->[$i]) {
			$pcorrp->{$pron1p->[$i]}++;
		} else {
			if ($pron1p->[$i] eq '0') {
				$pinsertp->{$pron2p->[$i]}++;
				
			} elsif ($pron2p->[$i] eq '0') {
				$pdeletep->{$pron1p->[$i]}++;
			} else {
				$pwrongp->{$pron1p->[$i]}{$pron2p->[$i]}++;
			}
		}
	}
}

sub compare_accuracy($$$$$$$) {
	my ($d1name,$d2name,$phonfn,$conf,$apairs,$varinf,$resname)=@_;
	my (%dict1,%stat1,%dict2,%stat2);
	
	fread_dict($d1name,%dict1,%stat1);
	fread_dict($d2name,%dict2,%stat2);
	
	open RH, ">:encoding(utf8)", "$resname" or die "Error opening output file $resname";
	if ($conf==1) {
		open CH, ">:encoding(utf8)", "$resname.confusion" or die "Error opening output file $resname.confusion";
	}
	if ($apairs==1) {
		open AH, ">:encoding(utf8)", "$resname.aligned" or die "Error opening output file $resname.confusion";
	}
	if ($varinf==1) {
		open VH, ">:encoding(utf8)", "$resname.variants" or die "Error opening output file $resname.variants";
	}
	my (%var,%single)=((),());
	my (%pcorr,%pinsert,%pdelete,%pwrong)=((),(),(),());
	my ($wcorr,$wrong,$wmiss,$wextra)=(0,0,0,0);
	my ($varexpected,$varfound,$varcorr,$varwrong)=(0,0,0,0);
	
	foreach my $w (keys %dict1) {
		if ($w =~ /^(.*)_.*$/) {
			$var{$1}=1;
		} else {
			$single{$w}=1;
		}
	}
	foreach my $w (keys %dict2) {
		if ($w =~ /^(.*)_.*$/) {
			$var{$1}=1;
		} else {
			$single{$w}=1;
		}
	}
	foreach my $w (keys %var) {
		if (exists $single{$w}) {
			delete $single{$w};
		}
	}
	
	my %scores=();
	init_acc_probs($phonfn,%scores);
	foreach my $w (keys %single) {
		#print "$w\n";
		my (@phon1,@phon2);
		if ($dict1{$w} eq $dict2{$w}) {
			$wcorr++;
			@phon1 = split //,$dict1{$w};
			@phon2 = split //,$dict2{$w};
		} else {
			$wwrong++;
			score_match($dict1{$w},$dict2{$w},%scores,@phon1,@phon2);	
			if ($apairs==1) {
				print AH "@phon1;@phon2\n";
			}
		}
		count_phon_acc(@phon1,@phon2,%pcorr,%pinsert,%pdelete,%pwrong);
		
	}
	
	foreach my $w (keys %var) {
		my %varlist1=();
		$varlist1{$dict1{$w}}=1;
		my $i=1;
		while (exists $dict1{"${w}_$i"}) {
			$varlist1{$dict1{"${w}_$i"}}=1;
			$i++;
		}
		my %varlist2=();
		$varlist2{$dict2{$w}}=1;
		$i=1;
		while (exists $dict2{"${w}_$i"}) {
			$varlist2{$dict2{"${w}_$i"}}=1;
			$i++;
		}
		my @vkeys1 = keys %varlist1;
		my @vkeys2 = keys %varlist2;
		$varexpected += @vkeys1;
		$varfound += @	vkeys2;
		
		my @phon1=();
		my @phon2=();
		my (%shortlist,%longlist);
		my $missing;
		if ($#vkeys1 <= $#vkeys2) {
			%shortlist=%varlist1;
			%longlist=%varlist2;
			$missing=0
		} else {
			%shortlist=%varlist2;
			%longlist=%varlist1;
			$missing=1;
		}
		foreach my $pron (keys %shortlist) {
			if (exists $longlist{$pron}) {
				print VH "correct;$w;$pron\n" if $varinf==1;
				$wcorr++;
				$varcorr++;
				@phon1 = split //,$pron;
				@phon2 = split //,$pron;
				count_phon_acc(@phon1,@phon2,%pcorr,%pinsert,%pdelete,%pwrong);
				delete $shortlist{$pron};
				delete $longlist{$pron};
			}
		}
		foreach my $pron (keys %shortlist) {
			my $minscore=1000;
			foreach my $pron2 (keys %longlist) {
				my $score = score_match($pron,$pron2,%scores,@phon1,@phon2);
				if ($score<$minscore) {
					$bestpron=$pron2;
					$minscore=$score;
				}
			}
			$wwrong++;
			$varwrong++;
			my $prntstr1 = join "",@phon1;
			my $prntstr2 = join "",@phon2;
			if ($missing==1) {
				print VH "error;$w;$prntstr2;$prntstr1\n" if $varinf==1;
				count_phon_acc(@phon2,@phon1,%pcorr,%pinsert,%pdelete,%pwrong);
			} else {
				print VH "error;$w;$prntstr1;$prntstr2\n" if $varinf==1;
				count_phon_acc(@phon1,@phon2,%pcorr,%pinsert,%pdelete,%pwrong);
			}
			if ($apairs==1) {
				print AH "@phon1;@phon2\n";
			}
			delete $shortlist{$pron};
			delete $longlist{$bestpron};
		}
		if ($missing==1) {
			foreach my $pron (keys %longlist) {
				$wmiss++;
				print VH "miss;$w;$pron\n" if $varinf==1;
				delete $longlist{$pron};
			}
		} else {
			foreach my $pron (keys %longlist) {
				$wextra++;
				print VH "extra;$w;$pron\n" if $varinf==1;
				delete $longlist{$pron};
			}
		}
	}
	
	my $wtot=$wcorr+$wwrong;
	my $wperc = ($wcorr*100)/$wtot;
	printf RH "SENT: \%Correct=%.2f [H=%d, S=%d, N=%d]\n",$wperc,$wcorr,$wwrong,$wtot;
	printf RH "Variants: expected=%d, found=%d, missing=%d, extra=%d, correct=%d, wrong=%d\n",$varexpected,$varfound,$wmiss,$wextra,$varcorr,$varwrong;
	
	my ($pcorr_tot,$pinsert_tot,$pdelete_tot,$pwrong_tot)=(0,0,0,0);
	foreach my $p (keys %pcorr) {
		$pcorr_tot += $pcorr{$p};
	}
	foreach my $p (keys %pinsert) {
		$pinsert_tot += $pinsert{$p};
	}
	foreach my $p (keys %pdelete) {
		$pdelete_tot += $pdelete{$p};
	}
	foreach my $p (keys %pwrong) {
		foreach my $p2 (keys %{$pwrong{$p}}) {
			$pwrong_tot += $pwrong{$p}{$p2};
		}
	}
	my $ptot=$pcorr_tot+$pwrong_tot+$pdelete_tot;
	my $pcorrperc=($pcorr_tot*100)/$ptot;
	my $paccperc=(($pcorr_tot-$pinsert_tot)*100)/$ptot;
	printf RH "WORD: \%Corr=%.2f, Acc=%.2f [H=%d, D=%d, S=%d, I=%d, N=%d]\n",$pcorrperc,$paccperc,$pcorr_tot,$pdelete_tot,$pwrong_tot,$pinsert_tot,$ptot;
	
	close AH;
	close RH;
	close CH;
	close VH;
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------
