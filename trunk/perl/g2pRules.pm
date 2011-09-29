package g2pRules;

use g2pFiles;
use g2pAlign;
use g2pDict;
use Time::Local;
use AnyDBM_File;
use g2pDec;
use g2pOlist;
use g2pRulesHelper;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	
	$debug = 0;
	$msg = 0;
	
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&g2p_word &g2p_word_info &g2p_wordlist &analyse_wordlist &fg2p_wordlist_align &detail_diff_dicts);
}

#--------------------------------------------------------------------------

sub g2p_word($$){
	#Generate a single pronunciation
	#Generate a pronunciation in <soundp> for word <word>
	#Use global %rule, %context and %rulecnt
	
	($word,$soundp) = @_;
	print "<p>-- Enter g2p: [$word]\n" if $debug;
	#print "word: [$word]\n" if $msg;
	
	my @rule_info=(); 	#not used in default g2p_word - only in g2p_word_info
				#used to keep commandline functions stable
	my $res;
	if ($rtype eq "bounce") {
		#$res=g2p_word_bounce($word,$soundp,@rule_info);
	} elsif ($rtype eq "olist") {
		$res = g2p_word_olist($word,$soundp,@rule_info);
	} else {
		#$res=g2p_word_shift($word,$soundp,@rule_info);
	}
	$$soundp =~ s/0//g;
	return $res;
}

sub g2p_word_info($$\@){
	#Generate a single pronunciation
	#Generate a pronunciation in <soundp> for word <word>
	#Use global %rule, %context and %rulecnt
	
	($word,$soundp,$infop) = @_;
	print "<p>-- Enter g2p: [$word]\n" if $debug;
	print "word: [$word]\n" if $msg;
	
	if ($rtype eq "bounce") {
		#g2p_word_bounce($word,$soundp,@$infop);
	} elsif ($rtype eq "olist") {
		g2p_word_olist($word,$soundp,@$infop);
	} else {
		#g2p_word_shift($word,$soundp,@$infop);
	}
}

sub g2p_wordlist($\%\%\%) {
	#Generate pronunciations for a list of words
	#Create a dictionary <dp>,<sp> based on word list <wname>
	#Mark all new words as not verified
	
	my ($wname,$gnullp,$dp,$sp) = @_;
	%$dp = ();
	%$sp = ();
	open IH, "$wname" or die "Cannot open $wname";
	while (<IH>) {
		chomp;
		my $sound = "";
		my $word=add_gnull_word($_,%$gnullp);
		#$word =~ s/^-//g;
		#$word =~ s/-$//g;
		my $err = g2p_word($word,\$sound);
		#print "HERE: $word\t$sound\n";
		if ($err) { print "<p>Error: $_\n" }
		else { $dp->{$_}=$sound; $sp->{$_}=0 }
	}
	close IH;
}

#--------------------------------------------------------------------------

sub fg2p_wordlist_align($$$$) {
	#Generate a pronunciation for a wordlist, leaving graphemic and phonemic nulls in place
	my ($wf,$rf,$gf,$of) = @_;
	open OH, ">$of" or die "Error opening $of\n";
	if ($rtype eq "olist") {
		fread_rules_olist($rf);
	} else {
		fread_rules($rf);
	}
	fread_gnull_list($gf,%gnulls);	
	fread_words($wf,@words);
	foreach my $word (@words) {
		chomp $word;
		my $sound = "";
		my @rinf=();
		my $gword=add_gnull_word($word,%gnulls);
		my $err = g2p_word_info($gword,\$sound,@rinf);
		if ($err) {
			print "<p>Error: $word\n"
		} else {
			my @wlist = split //,$gword;
			my @slist = split //,$sound;
			print OH "$word;@wlist;@slist\n"; }
	}
	close OH;
}

sub analyse_wordlist($$) {
	#Generate pronunciations for a list of words, first applying gnulls if any
	#Print result + rules applied (used during debugging)
	
	my ($wname,$gname) = @_;
	open WH, "$wname" or die "Cannot open $wname";
	my %gnulls=();
	fread_gnull_list($gname,%gnulls);
	my $keepmsg=$msg;
	$msg=1;
	while (<WH>) {
		chomp;
		my $sound = "";
		my $word=add_gnull_word($_,%gnulls);
		my $err = g2p_word($word,\$sound);
		if ($err) { print "<p>Error: $_\n" }
	}
	close IH;
	$msg=$keepmsg;
}

sub detail_diff_dicts ($$\@\@$\@\@$$) {
	my ($word,$snd1,$snd1p,$rule1p,$snd2,$snd2p,$rule2p,$ref,$fh)=@_;
	print $fh "Word:\t$word\n";
	print $fh "Right:\t$snd1\t";
	foreach my $l (0..$#$snd1p) {
		print $fh "$snd1p->[$l] [$rule1p->[$l]]\t";
	}
	print $fh "\nWrong:\t$snd2\t";
	foreach my $l (0..$#$snd2p) {
		print $fh "$snd2p->[$l] [$rule2p->[$l]]\t";
	}
	print $fh "\nRef:\t$ref\n";
	foreach my $l (0..$#$snd1p) {
		if (!($snd1p->[$l] eq $snd2p->[$l])) {
			my $len1 = length $rule1p->[$l];
			my $len2 = length $rule2p->[$l];
			my %pos=();
			if (($l!=0)&&($snd1p->[$l-1] eq "0")) {
				$pos{p_left_0}=1;
			}
			if ($snd1p->[$l] eq "0") {
				$pos{p_true_0}=1;
			}
			if (($l!=$#$snd1p)&&($snd1p->[$l+1] eq "0")) {
				$pos{p_right_0}=1;
			}
			if ($rule1p->[$l] =~ /^(.*)-(.)-(.*)$/) {
				my ($m1,$m2,$m3)=($1,$2,$3);
				if ($m1 =~ /.*0/) {
					$pos{g_left_0}=1;
				}
				if ($m2 eq "0") {
					$pos{g_true_0}=1;
				}
				if ($m3 =~ /0.*/) {
					$pos{g_right_0}=1;
				}
			}
			my $print0 = join " ", keys %pos;
			if ($len1>$len2) {
				print $fh "Length:\tlarger $len1 > $len2;\t$print0\n";
			} elsif ($len1<$len2) {
				print $fh "Length:\tsmaller $len1 < $len2;\t$print0\n";
			} else {
				print $fh "Length:\tsame $len1 == $len2;\t$print0\n";
			}
		}
	}
	print $fh "------------------------\n";
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

