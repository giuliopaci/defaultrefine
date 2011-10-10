package g2pRulesHelper;

use g2pFiles;
use g2pAlign;
use g2pDict;
use Time::Local;
#use AnyDBM_File;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	
	%rule=();     	#rule{pattern} = phone;
			#pattern = left-graph-right
	%rulecnt=();  	#rulecnt{pattern} = cnt;
	%context=();  	#context{graph} = list of patterns;
			#context derived from rule
	%rulepairs=();
	%rorder=();	#rorder{graph}[i] = pat
	
	$debug = 0;
	$msg = 0;
	$rtype = "olist";
	$use_rulepairs = 0;
	
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(%rule %context %rulecnt %rorder %numfound $rtype $use_rulepairs &get_sym &right_first &flatest_rules &frm_patts &min &get_all_pats_limit &add_gpatts_limit &fread_gpatts_limit &fread_array &get_all_pats_limit_wspecific &add_gpatts_limit_wspecific &fread_gpatts_limit_wspecific);
}

#--------------------------------------------------------------------------

sub get_sym($) {
	my $pat = shift @_;
	return 0 if ($pat eq '');
	if ($pat !~ /(.*)-.-(.*)/) {
		die "Error: get_sym\n";
	} 
	my $symcnt = abs ((length $2)-(length $1));
	return $symcnt;
}

sub right_first($) {
	my $pat = shift @_;
	return 0 if ($pat eq '');
	if ($pat !~ /(.*)-.-(.*)/) {
		die "Error: right_first\n";
	} 
	if ((length $2)>(length $1)) {
		return 1;
	} else {
		return 0;
	}
}


#--------------------------------------------------------------------------

sub frm_patts($$) {
	#Remove all pattern files of format <fname>.<g>
	my ($fname,$list) = @_;
	my @graphs;
	push @graphs,0;
	fread_array(@graphs,$list);
	foreach my $g ( @graphs ) {
		if (-e "$fname.$g") {
			system "rm $fname.$g";
		}
	}
}


sub flatest_rules($$) {
	#Determine if current rules latest
	#Return 1 if rules <rname> newer than dictionary <dname>, else 0 
	
	my ($dname,$rname) = @_;
        if (! -e $dname) {die "File $dname does not exist\n"};
        if (! -e $rname) {die "File $dname does not exist\n"};
        my $dtime = `stat -c%Z $dname`;
        my $rtime = `stat -c%Z $rname`;
        if ($dtime<$rtime) {return 1}
        else {return 0}
}
							

#--------------------------------------------------------------------------

sub min($$){
	my ($a,$b)=@_;
	if ($a<$b) {return $a}
	else {return $b}
}


#--------------------------------------------------------------------------

#Normal version used
sub get_all_pats_limit($$$) {
	my ($w,$from,$to) = @_;
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
		last if (($l+1)>$to);
		$newleft=substr($left,$leftlen-$l,$l);
		foreach my $r (0..$rightlen) {
			next if ($l+$r+1)>$to;
			$newright=substr($right,0,$r);
			if ((($l+$r+1)>=$from) && (($l+$r+1)<=$to)) {
				push @patlist,"${newleft}-${g}-${newright}";
			}
		}
	}
	return @patlist;	
}

sub get_all_pats_limit_wspecific($$$$) {
	my ($word,$w,$from,$to) = @_;
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
		last if (($l+1)>$to);
		$newleft=substr($left,$leftlen-$l,$l);
		foreach my $r (0..$rightlen) {
			next if ($l+$r+1)>$to;
			$newright=substr($right,0,$r);
			my $addpat="${newleft}-${g}-${newright}";
			if ( ($word =~ /$addpat/) && (($l+$r+1)>=$from) && (($l+$r+1)<=$to)) {
				push @patlist,$addpat;
			}
		}
	}
	return @patlist;	
}

#Version used when testing effect of limiting the context size
#now $to specifies the allowed context to left or right, rather than the 
#full context size, as previously
sub get_all_pats_limit_v2($$$) {
	my ($w,$from,$to) = @_;
	if ($w !~ /^(.*)-(.)-(.*)$/) {
		die "Error: rule format error in get_all_pats [$w]\n";
	}
	my @patlist=();
	my $left=$1;
	my $g=$2;
	my $right=$3;
	my $leftlen=length $left;
	my $rightlen=length $right;
	foreach my $l (0..$leftlen) {
		last if $l>$to;
		$newleft=substr($left,$leftlen-$l,$l);
		foreach my $r (0..$rightlen) {
			next if $r>$to;
			$newright=substr($right,0,$r);
			if (($l>=$from)&&($r>=$from)&&($l<=$to)&&($r<=$to)) {
				push @patlist,"${newleft}-${g}-${newright}";
			}
		}
	}
	return @patlist;	
}


sub fread_gpatts_limit($$\%\%$) {
	#Read all patterns from <$fname> (related to a single grapheme)
	#Update <$gp>
	my ($from,$to,$gp,$wp,$fname) = @_;
	open IH, "<:encoding(utf8)", "$fname" or die "Error opening $fname\n";	
	while (<IH>) {
		chomp;
		my ($p,$w) = split ";";
		$wp->{$w}=$p;
		my @wordpats = get_all_pats_limit($w,$from,$to);
		foreach my $pat (@wordpats) {
			$gp->{$pat}{$p}++;
		}
	}
	close IH;
}

sub fread_gpatts_limit_wspecific($$$\%\%$) {
	#Read all patterns from <$fname> (related to a single grapheme)
	#Update <$gp>
	my ($word,$from,$to,$gp,$wp,$fname) = @_;
	open IH, "<:encoding(utf8)", "$fname" or die "Error opening $fname\n";	
	while (<IH>) {
		chomp;
		my ($p,$w) = split ";";
		$wp->{$w}=$p;
		my @wordpats = get_all_pats_limit_wspecific($word,$w,$from,$to);
		foreach my $pat (@wordpats) {
			$gp->{$pat}{$p}++;
		}
	}
	close IH;
}


sub add_gpatts_limit($$\%\%\%\%) {
	my ($from,$to,$donep,$notp,$posp,$caughtp) = @_;
        foreach my $w (keys %$donep) {
		my $wlen = (length $w)-2;
		my $p = $donep->{$w};
		next if $wlen < $from;
		my @wordpatts = get_all_pats_limit($w,$from,$to);
		foreach my $pat (@wordpatts) {
			$caughtp->{$pat}{$p}++;
		}
	}

        foreach my $w (keys %$notp) {
		my $wlen = (length $w)-2;
		my $p = $notp->{$w};
		next if $wlen < $from;
		my @wordpatts = get_all_pats_limit($w,$from,$to);
		foreach my $pat (@wordpatts) {
			if (!(exists $rule{$pat})) {
				$posp->{$pat}{$p}++;
			}
		}
	}
}


sub add_gpatts_limit_wspecific($$$\%\%\%\%) {
	my ($word,$from,$to,$donep,$notp,$posp,$caughtp) = @_;
        foreach my $w (keys %$donep) {
		my $wlen = (length $w)-2;
		my $p = $donep->{$w};
		next if $wlen < $from;
		my @wordpatts = get_all_pats_limit_wspecific($word,$w,$from,$to);
		foreach my $pat (@wordpatts) {
			$caughtp->{$pat}{$p}++;
		}
	}

        foreach my $w (keys %$notp) {
		my $wlen = (length $w)-2;
		my $p = $notp->{$w};
		next if $wlen < $from;
		my @wordpatts = get_all_pats_limit_wspecific($word,$w,$from,$to);
		foreach my $pat (@wordpatts) {
			if (!(exists $rule{$pat})) {
				$posp->{$pat}{$p}++;
			}
		}
	}
}


#--------------------------------------------------------------------------

sub fread_array(\@$) {
	my ($ap,$fn)=@_;
	print "-- Enter fread_array $fn\n" if $debug;
        open FH, "<:encoding(utf8)","$fn" or die "Unable to open $fn\n";
        while (<FH>) { chomp; push @$ap,$_ }
        print "graphs: @$ap" if $debug;
        close FH;
}

#--------------------------------------------------------------------------

return 1;
END { }

#--------------------------------------------------------------------------


