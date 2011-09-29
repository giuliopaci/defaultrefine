package g2pDefref;

use g2pFiles;
use g2pAlign;
use g2pDict;
use g2pOlist;
use Time::Local;
#use AnyDBM_File;
#use Graph;
#use g2pTrees;
use g2pRulesHelper;
#use strict;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;
	$msg = 0;

	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&predict_one_dr &predict_list &find_rules_single &custom_extract_patts &fread_rules_dr);
}

#--------------------------------------------------------------------------
#Helper functions
#--------------------------------------------------------------------------

sub get_rule_context($) {
	my $nr = shift @_;
	my @parts = split '&&',$nr;
	if (@parts>1) {
		$ctxt = $parts[0];
	} else {
		$ctxt = $nr;
	}
	return $ctxt;
}


sub get_num_features($) {
	my $nr = shift @_;
	my @parts = split '&&',$nr;
	return scalar @parts;
}


sub get_rule_feat($) {
	my $nr = shift @_;
	my @parts = split '&&',$nr;
	if (@parts<=1) {
		return '';
	} elsif (@parts==2) {
		return $parts[1];
	} else {
		die "Error in rule format: $nr";
	}
}


sub get_rule_length($) {
	my $nr = shift @_;
	my $ctxt = get_rule_context($nr);
	my $size = length $ctxt;
	return $size;
}


#--------------------------------------------------------------------------

sub custom_predict_one_1extra($\%$\@) {
	($line,$gnullp,$soundp,$infop) = @_;
	my @parts = split /;/,$line;
	my $word=add_gnull_word($parts[0],%$gnullp);
	my $f1 = $parts[1];
	
	chomp $word;
	my @slist=();

	my $wordend = (length $word)-1;
	my $l = " "; 
	my $g = substr $word,0,1; 
	my $r="";
	if ($wordend>0) {
		$r = (substr $word,1)." ";
	} else {
		$r = " ";
	}
			
	#foreach graph->phone
	foreach my $i (0 .. $wordend) {
		my @rlist = @{$rorder{$g}};
		$ri=$#rlist;
		$found=0;
		
		my $pat = $l."-".$g."-".$r;
		while ($ri>=0) {
			if (get_num_features($rlist[$ri])>1) {
				$posrule=get_rule_context($rlist[$ri]);
				$posf1=get_rule_feat($rlist[$ri]);
			} else {
				$posrule=$rlist[$ri];
				$posf1='';
			}
			if (($pat =~ /$posrule/)&&(($posf1 eq '') || ($posf1 eq $f1))) {
				$found=1;
				$rmatch=$rlist[$ri];
				last;
			}
			$ri--;
		}
		if ($found==0) {
			die "No matching rule found! [$word][$i]\n";
		} else { 
			$slist[$i]=$rule{$rmatch};
			$infop->[$i]=$rmatch;
			print "[$rmatch] -> $slist[$i]\n" if $debug;
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


sub predict_one_dr($\%\@\%\%) {
	my ($line,$gnullp,$infop,$dp,$sp) = @_;
	my $sound="";
	if ($custom_use eq 'context_and_1feat') {
		custom_predict_one_1extra($line,%$gnullp,\$sound,@$infop);
		my ($word,$f1) = split /;/,$line;
		$dp->{$word}{$f1}=$sound;
		$sp->{$word}{$f1}=0;
	} elsif ($custom_use eq 'context_only') {
		my $word=add_gnull_word($line,%$gnullp);
		g2p_word_olist($word,\$sound,@$infop);
		$dp->{$line}=$sound;
		$sp->{$line}=0;
	} elsif ($custom_use eq 'bio_specific') {
		my $word=add_gnull_word($line,%$gnullp);
		g2p_word_olist($word,\$sound,@$infop);
		$dp->{$line}=$sound;
		$sp->{$line}=0;
	}
	return $sound; 
}

sub predict_list($\%\@\%\%) {
	#Generate pronunciations for a list of words
	#Create a dictionary <dp>,<sp> based on word list <wname>
	#Mark all new words as not verified
	#If any characters in the $ignorep list, keep in orthography but ignore while producing pronunciations
	
	my ($wname,$gnullp,$ignorep,$dp,$sp) = @_;
	%$dp = (); %$sp = ();
	#open IH, "$wname" or die "Cannot open $wname";
	open IH, '<:encoding(utf8)', $wname or die "Cannot open $wname";	
	while (<IH>) {
		chomp;
		my $word = $_;
		my $sound = "";
		my @info=();
		my $doIgnore=0;
		foreach my $i (@{$ignorep}) { 
			if ($word =~ /$i/) {
				$word =~ s/$i//g;
				$doIgnore = 1;
			}
		}
		if ($doIgnore==1) {
			$word=add_gnull_word($word,%$gnullp);
			g2p_word_olist($word,\$sound,@$infop);
			$dp->{$_}=$sound;
			$sp->{$_}=0;
		} else {
			predict_one_dr($_,%$gnullp,@info,%$dp,%$sp);
		}
	}
	close IH;
}

#--------------------------------------------------------------------------
#Custom functions
#--------------------------------------------------------------------------

sub custom_fread_pattsfile_limit_std($$$\%\%) {
	my ($from,$to,$fname,$patp,$newp)=@_;
	#open IH, "$fname" or die "Error opening $fname\n";	
	open IH, '<:encoding(utf8)', $fname or die "Cannot open $fname";	
	while (<IH>) {
		chomp;
		my @parts = split /;/;
		if (@parts != 3) {
			die "Error in $fname format: @parts\n";
		}
		my ($id,$class,$context) = @parts;
		
		my @wordpats = get_all_pats_limit($context,$from,$to);
		foreach my $pat (@wordpats) {
			$patp->{$pat}{$class}{$id}=1;
		}
		$newp->{$id}{$context}=$class;
	}
	close IH;
}


sub custom_fread_pattsfile_limit_1extra($$$\%\%) {
	my ($from,$to,$fname,$patp,$newp)=@_;
	open IH, "$fname" or die "Error opening $fname\n";	
	while (<IH>) {
		chomp;
		my @parts = split /;/;
		if (@parts != 4) {
			die "Error in $fname format: @parts\n";
		}
		my ($id,$class,$context,$feat1) = @parts;
		
		my @wordpats = get_all_pats_limit($context,$from,$to);
		foreach my $pat (@wordpats) {
			$patp->{$pat}{$class}{$feat1}{$id}=1;
		}
		$newp->{$id}{$context}{$feat1}=$class;
	}
	close IH;
}


sub custom_fread_pattsfile_limit($$$\%\%) {
	my ($from,$to,$fname,$patp,$newp)=@_;
	if ($custom_use eq 'context_and_1feat') {
		custom_fread_pattsfile_limit_1extra($from,$to,$fname,%$patp,%$newp);
	} elsif ($custom_use eq 'context_only') {
		custom_fread_pattsfile_limit_std($from,$to,$fname,%$patp,%$newp);
	} elsif ($custom_use eq 'bio_specific') {
		custom_fread_pattsfile_limit_bio($from,$to,$fname,%$patp,%$newp);
	}
}

#--------------------------------------------------------------------------

sub custom_add_patts_limit_1extra($$\%\%\%\%) {
	my ($from,$to,$donep,$newp,$posp,$caughtp) = @_;
        foreach my $id (keys %$donep) {
		$idp = $donep->{$id};
		foreach my $context (keys %$idp) {
			my $clen = (length $context)-2;
			next if $clen < $from;
			my $ctxtp = $idp->{$context};
			foreach my $feat1 (keys %$ctxtp) {
				my $class = $ctxtp->{$feat1};
				my @wordpatts = get_all_pats_limit($context,$from,$to);
				foreach my $pat (@wordpatts) {
					$caughtp->{$pat}{$class}{$feat1}{$id}=1;
				}
			}
		}
	}

        foreach my $id (keys %$newp) {
		$idp = $newp->{$id};
		foreach my $context (keys %$idp) {
			my $clen = (length $context)-2;
			next if $clen < $from;
			my $ctxtp = $idp->{$context};
			foreach my $feat1 (keys %$ctxtp) {
				my $class = $ctxtp->{$feat1};	
				my @wordpatts = get_all_pats_limit($context,$from,$to);
				foreach my $pat (@wordpatts) {
					$posp->{$pat}{$class}{$feat1}{$id}=1;
				}
			}
		}
	}
}

sub custom_add_patts_limit_std($$\%\%\%\%) {
	my ($from,$to,$donep,$newp,$posp,$caughtp) = @_;
        foreach my $id (keys %$donep) {
		$idp = $donep->{$id};
		foreach my $context (keys %$idp) {
			my $clen = (length $context)-2;
			next if $clen < $from;
			my $class = $idp->{$context};
			my @wordpatts = get_all_pats_limit($context,$from,$to);
			foreach my $pat (@wordpatts) {
				$caughtp->{$pat}{$class}{$id}=1;
			}
		}
	}

        foreach my $id (keys %$newp) {
		$idp = $newp->{$id};
		foreach my $context (keys %$idp) {
			my $clen = (length $context)-2;
			next if $clen < $from;
			my $class = $idp->{$context};
			my @wordpatts = get_all_pats_limit($context,$from,$to);
			foreach my $pat (@wordpatts) {
				$posp->{$pat}{$class}{$id}=1;
			}
		}
	}
}

sub custom_add_patts_limit($$\%\%\%\%) {
	my ($from,$to,$donep,$newp,$posp,$caughtp) = @_;
	if ($custom_use eq 'context_and_1feat') {
		custom_add_patts_limit_1extra($from,$to,%$donep,%$newp,%$posp,%$caughtp);
	} elsif ($custom_use eq 'context_only') {
		custom_add_patts_limit_std($from,$to,%$donep,%$newp,%$posp,%$caughtp);
	} elsif ($custom_use eq 'bio_specific') {
		custom_add_patts_limit_bio($from,$to,%$donep,%$newp,%$posp,%$caughtp);
	}
}

#--------------------------------------------------------------------------

sub custom_check_and_add_default_std($$) {
	my ($feat,$rulefile)= @_;
	my $c;
	if (!(exists $rule{"-$feat-"})) {
		if (exists $rule{$rorder{$feat}[1]}) {
			$c=$rule{$rorder{$feat}[1]};	
		} else {
			$c="0";
		}	
		$rule{"-$feat-"} = $c;
		$rorder{$g}[0]="-$feat-";
		print "$feat:\t[0]\t[-$feat-] --> $c\n"; #if $debug;
		
		open OH, ">>$rulefile" or die "Error opening file $rulefile\n";
		print OH "$feat;;;$c;0;0\n";
		close OH;
		
	} else {
		$rorder{$g}[0]="-1";
	}
}


sub custom_check_and_add_default_1extra($$) {
	my ($feat,$rulefile)= @_;
	my $c;
	if (!(exists $rule{"-$feat-"})) {
		if (exists $rule{$rorder{$feat}[1]}) {
			$c=$rule{$rorder{$feat}[1]};	
		} else {
			$c="0";
		}	
		$rule{"-$feat-"} = $c;
		$rorder{$g}[0]="-$feat-";
		print "$feat:\t[0]\t[-$feat-] --> $c\n"; #if $debug;
		
		open OH, ">>$rulefile" or die "Error opening file $rulefile\n";
		print OH "$feat;;;;$c;0;0\n";
		close OH;
		
	} else {
		$rorder{$g}[0]="-1";
	}
}


sub custom_check_and_add_default($$) {
	my ($feat,$rulefile)= @_;
	if ($custom_use eq 'context_and_1feat') {
		custom_check_and_add_default_1extra($feat,$rulefile);
	} elsif ($custom_use eq 'context_only') {
		custom_check_and_add_default_std($feat,$rulefile);
	} elsif ($custom_use eq 'bio_specific') {
		custom_check_and_add_default_std($feat,$rulefile);
	}
}

#--------------------------------------------------------------------------

sub custom_next_template_std($) {
	my ($tp) = shift @_;
	if ($$tp eq '') {
		$$tp = 'context';
		return 1;
	}
	return 0;
}

sub custom_next_template_1extra($) {
	my ($tp) = shift @_;
	if ($$tp eq '') {
		$$tp = 'context';
		return 1;
	} elsif ($$tp eq 'context') {
		$$tp = 'context&&feat1';
		return 1;
	}
	return 0;
}

sub custom_next_template($) {
	my ($tp) = shift @_;
	if ($custom_use eq 'context_and_1feat') {
		return custom_next_template_1extra $tp;
	} elsif ($custom_use eq 'context_only') {
		return custom_next_template_std $tp;
	} elsif ($custom_use eq 'bio_specific') {
		return custom_next_template_bio $tp;
	}
}

#--------------------------------------------------------------------------

sub custom_resolve_1extra($$$$$$) {
	my ($champ,$max_alpha,$max_beta,$contender,$alpha,$beta)=@_;
	my $champ_ctxt = get_rule_context($champ);
	my $contend_ctxt = get_rule_context($contender);
	my $maxparts = get_num_features($champ);
	my $parts = get_num_features($contender);
	my $maxsize = length $champ_ctxt;
	my $size = length $contend_ctxt;
	my $maxsym = get_sym $champ_ctxt;
	my $sym = get_sym $contend_ctxt;
	my $maxright = right_first $champ_ctxt;
	my $right = right_first $contend_ctxt;

	if (($parts<$maxparts)
	    || (($parts==$maxparts)&&($alpha>$max_alpha))
	    || (($parts==$maxparts)&&($alpha==$max_alpha)&&($size<$maxsize))
	    || (($size==$maxsize)&&($parts==$maxparts)&&($alpha==$max_alpha)&&($sym<$maxsym))
	    || (($size==$maxsize)&&($parts==$maxparts)&&($alpha==$max_alpha)&&($sym==$maxsym)&&($right>$maxright))
	   ) {
		return 1;
	}
	return 0;
}

sub custom_resolve_std($$$$$$) {
	my ($champ,$max_alpha,$max_beta,$contender,$alpha,$beta)=@_;
	my $maxsize = length $champ;
	my $size = length $contender;
	my $maxsym = get_sym $champ;
	my $sym = get_sym $contender;
	my $maxright = right_first $champ;
	my $right = right_first $contender;

	if (($alpha>$max_alpha)
	    || (($alpha==$max_alpha)&&($size<$maxsize)) 
	    || (($alpha==$max_alpha)&&($size==$maxsize)&&($sym<$maxsym))
	    || (($alpha==$max_alpha)&&($size==$maxsize)&&($sym==$maxsym)&&($right>$maxright))
	   ) {
		return 1;
	}
	return 0;
}

sub custom_resolve($$$$$$) {
	my ($champ,$max_alpha,$max_beta,$contender,$alpha,$beta)=@_;
	if ($custom_use eq 'context_and_1feat') {
		return custom_resolve_1extra($champ,$max_alpha,$max_beta,$contender,$alpha,$beta);
	} elsif ($custom_use eq 'context_only') {
		return custom_resolve_std($champ,$max_alpha,$max_beta,$contender,$alpha,$beta);
	} elsif ($custom_use eq 'bio_specific') {
		return custom_resolve_bio($champ,$max_alpha,$max_beta,$contender,$alpha,$beta);
	}
}

#--------------------------------------------------------------------------

sub custom_net_move_std($\%\%$$$$$) {
	my ($template,$posp,$caughtp,$posrulep,$classp,$cntp,$ap,$bp)=@_;

	my $max=0;
	my $maxrule="";
	my $maxc="";
	my $found=0;
	my $max_alpha=0;
	my $max_beta=0;
	
	if ($template eq 'context') {
		foreach my $pat (keys %{$posp}) {
			my $patp = $posp->{$pat};
			foreach my $c (keys %{$patp}) {
				my $ftot=0;
				my $alpha=0;
				my $beta=0;
				my $cpatp = $patp->{$c};
				my @ids = keys %{$cpatp};
				$alpha = scalar @ids;	
				my $confp=$caughtp->{$pat};
				foreach my $not_c (keys %{$confp}) {
					next if $c eq $not_c;
					my $cconfp = $confp->{$not_c};
					my @ids = keys %{$cconfp};
					$beta += scalar @ids;
				}
				$ftot = $alpha - $beta;
				if (($ftot>$max)||
				    (($ftot==$max)&&($ftot>0)&&(custom_resolve($maxrule,$max_alpha,$max_beta,$pat,$alpha,$beta)==1))) {
					$max=$ftot;
					$maxc=$c;
					$maxrule=$pat;
					$max_alpha=$alpha;
					$max_beta=$beta;
					$found=1;
				}
			}
		}
	} 
	$$posrulep=$maxrule;
	$$classp=$maxc;
	$$cntp=$max;
	$$ap=$max_alpha;
	$$bp=$max_beta;
}


sub custom_net_move_1extra($\%\%$$$$$) {
	my ($template,$posp,$caughtp,$posrulep,$classp,$cntp,$ap,$bp)=@_;
	my $max=0;
	my $maxrule="";
	my $maxc="";
	my $found=0;
	my $max_alpha=0;
	my $max_beta=0;
	
	if ($template eq 'context') {
		foreach my $pat (keys %{$posp}) {
			my $patp = $posp->{$pat};
			foreach my $c (keys %{$patp}) {
				my $alpha=0;
				my $ftot=0;
				my $beta=0;
				my $cpatp = $patp->{$c};
				foreach my $feat1 (keys %$cpatp) {
					my @ids = keys %{$cpatp->{$feat1}};
					$alpha += @ids;
				}
				
				my $confp=$caughtp->{$pat};
				foreach my $not_c (keys %{$confp}) {
					next if $c eq $not_c;
					my $cconfp = $confp->{$not_c};
					foreach my $feat1 (keys %$cconfp) {
						my @ids = keys %{$cconfp->{$feat1}};
						$beta += scalar @ids;
					}	
				}
				$ftot = $alpha - $beta;
				
				if (($ftot>$max)||
				    (($ftot==$max)&&(custom_resolve($maxrule,$max_alpha,$max_beta,$pat,$alpha,$beta)==1))) {
					$max=$ftot;
					$maxc=$c;
					$maxrule=$pat;
					$max_alpha=$alpha;
					$max_beta=$beta;
				}
			}
		}
	} elsif ($template eq 'context&&feat1') {
		foreach my $pat (keys %{$posp}) {
			my $patp = $posp->{$pat};
			foreach my $c (keys %{$patp}) {	
				my $cpatp = $patp->{$c};
				foreach my $feat1 (keys %$cpatp) {
					my $ftot=0;
					my $alpha=0;
					my $beta=0;
					my @ids = keys %{$cpatp->{$feat1}};
					$alpha += @ids;
					
					my $confp=$caughtp->{$pat};
					foreach my $not_c (keys %{$confp}) {
						next if $c eq $not_c;
						my $cconfp = $confp->{$not_c};
						if (exists $confp->{$not_c}{$feat1}) {
							my @ids = keys %{$cconfp->{$feat1}};
							$beta+= @ids;
						}
					}
					$ftot = $alpha-$beta;
					
					my $newpat = "$pat" . '&&' . "$feat1";
					if (($ftot>$max)||
					    (($ftot==$max)&&(custom_resolve($maxrule,$max_alpha,$max_beta,$newpat,$alpha,$beta)==1))) {
						$max=$ftot;
						$maxc=$c;
						$maxrule=$newpat;
						$max_alpha=$alpha;
						$max_beta=$beta;
					}
				}
			}
		}			
	}
	$$posrulep=$maxrule;
	$$classp=$maxc;
	$$cntp=$max;
	$$ap=$max_alpha;
	$$bp=$max_beta;
}

sub custom_net_move($\%\%$$$$$) {
	my ($template,$posp,$caughtp,$posrulep,$classp,$cntp,$ap,$bp)=@_;
	if ($custom_use eq 'context_and_1feat') {
		custom_net_move_1extra($template,%$posp,%$caughtp,$posrulep,$classp,$cntp,$ap,$bp);
	} elsif ($custom_use eq 'context_only') {
		custom_net_move_std($template,%$posp,%$caughtp,$posrulep,$classp,$cntp,$ap,$bp);
	} elsif ($custom_use eq 'bio_specific') {
		custom_net_move_std($template,%$posp,%$caughtp,$posrulep,$classp,$cntp,$ap,$bp);
	}
}

#--------------------------------------------------------------------------

sub get_next_rules($\%\%$\@) {
	#Find next pat to add as rule
	my ($feat,$posp,$caughtp,$cp,$nrlp)=@_;
	
	@$nrlp=();
	my $max=0;
	my $maxrule="";
	my $template="";
	my $c="";
	my $found=0;
	my $max_alpha=0;
	my $max_beta=0;
	
	while (custom_next_template(\$template)) {
		my $posrule="";
		my $alpha=0;
		my $beta=0;
		custom_net_move($template,%$posp,%$caughtp,\$posrule,\$c,\$count,\$alpha,\$beta);
		if (($count>$max)||
		    (($count==$max)&&(custom_resolve($maxrule,$max_alpha,$max_beta,$posrule,$alpha,$beta)==1))) {
			$max=$count;
			$maxc=$c;
			$maxrule=$posrule;
			$max_alpha=$alpha;
			$max_beta=$beta;
			$found=1;
		}
	}
	
	if ($found==1) {
		print "$max\t[$maxrule] -> $maxc\n" if $msg;
		@$nrlp=($maxrule);
		$$cp=$maxc;
		return 1;
	} else {
		return 0;
	}
}

#--------------------------------------------------------------------------

sub custom_get_ids_per_pat_conflict_1extra($\%$) {
	my ($newrule,$patp,$class)=@_;
	my @wlist=();
	my @ruleparts = split '&&',$newrule;
	if (@ruleparts==2) {
		my $context=$ruleparts[0];
		my $feat1=$ruleparts[1];
		foreach my $c (keys %{$patp->{$context}}) {
			if (!($c eq $class)) {
				my $cp = $patp->{$context}->{$c};
				my @ids = keys %{$cp->{$feat1}};
				push @wlist, @ids;
			}
		}
	} else {
		my $context = $newrule;
		foreach my $c (keys %{$patp->{$context}}) {
			if (!($c eq $class)) {
				my $cp = $patp->{$context}->{$c};
				foreach my $f (keys %{$cp}) {
					my @ids = keys %{$cp->{$f}};
					push @wlist, @ids;
				}
			}
		}
	}
	return @wlist;
}


sub custom_get_ids_per_pat_conflict_std($\%$) {
	my ($newrule,$patp,$class)=@_;
	my @wlist=();
	my $context = $newrule;
	foreach my $c (keys %{$patp->{$context}}) {
		if (!($c eq $class)) {
			my $cp = $patp->{$context}->{$c};
			my @ids = keys %{$cp};
			push @wlist, @ids;
		}
	}
	return @wlist;
}


sub custom_get_ids_per_pat_conflict($\%$) {
	my ($newrule,$patp,$class)=@_;
	if ($custom_use eq 'context_and_1feat') {
		custom_get_ids_per_pat_conflict_1extra($newrule,%$patp,$class);
	} elsif ($custom_use eq 'context_only') {
		custom_get_ids_per_pat_conflict_std($newrule,%$patp,$class);
	} elsif ($custom_use eq 'bio_specific') {
		custom_get_ids_per_pat_conflict_std($newrule,%$patp,$class);
	}
}

#--------------------------------------------------------------------------

sub custom_get_ids_per_pat_match_1extra($\%$) {
	my ($newrule,$patp,$class)=@_;
	my @wlist=();
	my @ruleparts = split '&&',$newrule;
	if (@ruleparts==2) {
		$context=$ruleparts[0];
		$feat1=$ruleparts[1];
		foreach my $c (keys %{$patp->{$context}}) {
			if ($c eq $class) {
				my $cp = $patp->{$context}->{$c};
				my @ids = keys %{$cp->{$feat1}};
				push @wlist, @ids;
			}
		}
	} else {
		$context = $newrule;
		foreach my $c (keys %{$patp->{$context}}) {
			if ($c eq $class) {
				my $cp = $patp->{$context}->{$c};
				foreach my $f (keys %{$cp}) {
					my @ids = keys %{$cp->{$f}};
					push @wlist, @ids;
				}
			}
		}
	}
	return @wlist;
}

sub custom_get_ids_per_pat_match_std($\%$) {
	my ($newrule,$patp,$class)=@_;
	my @wlist=();
	my $context = $newrule;
	foreach my $c (keys %{$patp->{$context}}) {
		if ($c eq $class) {
			my $cp = $patp->{$context}->{$c};
			my @ids = keys %{$cp};
			push @wlist, @ids;
		}
	}
	return @wlist;
}


sub custom_get_ids_per_pat_match($\%$) {
	my ($newrule,$patp,$class)=@_;
	if ($custom_use eq 'context_and_1feat') {
		custom_get_ids_per_pat_match_1extra($newrule,%$patp,$class);
	} elsif ($custom_use eq 'context_only') {
		custom_get_ids_per_pat_match_std($newrule,%$patp,$class);
	} elsif ($custom_use eq 'bio_specific') {
		custom_get_ids_per_pat_match_std($newrule,%$patp,$class);
	}
}

#--------------------------------------------------------------------------

sub custom_rm_from_possiblelist_std(\%$$$) {
	my ($posp,$nr,$class,$id)=@_;
	return if !(exists $posp->{$nr}{$class}{$id});
	delete $posp->{$nr}{$class}{$id};
	my @ilist = keys %{$posp->{$nr}{$class}};
	if (scalar @ilist <=0) {
		delete $posp->{$nr}{$class};		
		my @clist = keys %{$posp->{$nr}};
		if (scalar @clist <=0) {
			delete $posp->{$nr};
		}
	}
}

sub custom_rm_from_possiblelist_1extra(\%$$$$) {
	my ($posp,$nr,$class,$f1,$id)=@_;
	return if !(exists $posp->{$nr}{$class}{$f1}{$id});
	delete $posp->{$nr}{$class}{$f1}{$id};
	my @ilist = keys %{$posp->{$nr}{$class}{$f1}};
	if (scalar @ilist <=0) {
		delete $posp->{$nr}{$class}{$f1};		
		my @flist = keys %{$posp->{$nr}{$class}};
		if (scalar @flist <=0) {
			delete $posp->{$nr}{$class};
			my @clist = keys %{$posp->{$nr}};
			if (scalar @clist <=0) {
				delete $posp->{$nr};
			}
		}
	}
}

sub rm_from_rulelist(\%$$) {
	#Delete rule after rule removed from caughtlist
	my ($words_notp,$nr,$g)=@_;
	my $p  = $rule{$nr};
	delete $rule{$nr};
	foreach my $ri (1..$#{$rorder{$g}}) {
		if ($rorder{$g}[$ri] eq $nr) {
			$rorder{$g}[$ri]=-1;
			last;
		}
	}
	#Add patterns previously conflicting with rule, but now possible
	#(Other patts automatically added in next step.) 
	my @words_possible_nr=get_words_per_pat_conflict($nr,%$words_notp,$p);
	foreach my $w (@words_possible_nr) {
		$pc = $words_notp->{$w};
		$posp->{$nr}{$pc}++;
	}
}


sub custom_rm_from_caughtlist_std(\%$$$) {
	my ($caughtp,$nr,$class,$id)=@_;
	return if !(exists $caughtp->{$nr}{$class}{$id});
	delete $caughtp->{$nr}{$class}{$id};
	my @ilist = keys %{$caughtp->{$nr}{$class}};
	if (scalar @ilist <=0) {
		delete $caughtp->{$nr}{$class};		
		if ((exists $rule{$nr})&&($rule{$nr} eq $class)) {
			print "About to delete rule $nr\n";
			#rm_from_rulelist(%$words_notp,$nr,$g)
		}
		my @clist = keys %{$caughtp->{$nr}};
		if (scalar @clist <=0) {
			delete $caughtp->{$nr};
		}
	}
}

sub custom_rm_from_caughtlist_1extra(\%$$$$) {
	my ($caughtp,$nr,$class,$f1,$id)=@_;
	return if !(exists $caughtp->{$nr}{$class}{$f1}{$id});
	delete $caughtp->{$nr}{$class}{$f1}{$id};
	my @ilist = keys %{$caughtp->{$nr}{$class}{$f1}};
	if (scalar @ilist <=0) {
		delete $caughtp->{$nr}{$class}{$f1};		
		my @flist = keys %{$caughtp->{$nr}{$class}};
		if (scalar @flist <=0) {
			delete $caughtp->{$nr}{$class};
			if ((exists $rule{$nr})&&($rule{$nr} eq $class)) {
				print "About to delete rule $nr\n";
				#rm_from_rulelist(%$words_notp,$nr,$g)
			}
			my @clist = keys %{$caughtp->{$nr}};
			if (scalar @clist <=0) {
				delete $caughtp->{$nr};
			}
		}
	}
}


#--------------------------------------------------------------------------

sub custom_add_rule_std($$$$) {
	my ($feat,$nr,$c,$displaycnt)=@_;
	$nr =~ /^(.*)-.-(.*)$/;
	print OH "$feat;$1;$2;$c;$frulenum;$displaycnt\n";
}

sub custom_add_rule_1extra($$$$) {
	my ($feat,$nr,$c,$displaycnt)=@_;
	my ($context,$feat1);
	if (get_num_features($nr)==1) {
		$context=$nr;
		$feat1='';
	} else {
		$context = get_rule_context($nr);
		$feat1 = get_rule_feat($nr);
	}
	$context =~ /^(.*)-.-(.*)$/;
	print OH "$feat;$1;$2;$feat1;$c;$frulenum;$displaycnt\n";
}

sub custom_add_rule($$$$) {
	my ($feat,$nr,$c,$displaycnt)=@_;
	$rule{$nr}=$c;
	$rorder{$feat}[$frulenum]=$nr;
	$numfound{$nr}=$displaycnt;
	print "$feat:\t[$frulenum]\t[$nr] --> [$c]\t$displaycnt\n"; #if $msg;
	
	if ($custom_use eq 'context_and_1feat') {
		custom_add_rule_1extra($feat,$nr,$c,$displaycnt);
	} elsif ($custom_use eq 'context_only') {
		custom_add_rule_std($feat,$nr,$c,$displaycnt);
	} elsif ($custom_use eq 'bio_specific') {
		custom_add_rule_std($feat,$nr,$c,$displaycnt);
	}
	$frulenum++;
}

#--------------------------------------------------------------------------

sub custom_move_solved_std(\@$\%\%\%\%$) {
	my ($solvedp,$c,$newp,$donep,$posp,$caughtp,$to) = @_;
	foreach my $id (@{$solvedp}) {
		print "Instance solved: [$id] -> [$c]\n" if $msg;
		foreach my $cont (keys %{$newp->{$id}}) {
			my @wordpatts = get_all_pats_limit($cont,1,$to);
			my $class = ${$newp->{$id}}{$cont};
			foreach my $pat (@wordpatts) {
				$caughtp->{$pat}{$class}{$id}=1;
				custom_rm_from_possiblelist_std(%$posp,$pat,$class,$id);
			}
			$donep->{$id}{$cont}=$class;
		}
		delete $newp->{$id};
	}
}


sub custom_move_solved_1extra(\@$\%\%\%\%$) {
	my ($solvedp,$c,$newp,$donep,$posp,$caughtp,$to) = @_;
	foreach my $id (@{$solvedp}) {
		print "Instance solved: [$id] -> [$c]\n" if $msg;
		foreach my $cont (keys %{$newp->{$id}}) {
			my @wordpatts = get_all_pats_limit($cont,1,$to);
			my $contp = ${$newp->{$id}}{$cont};
			foreach my $f1 (keys %{$contp}) {
				my $class = $contp->{$f1};
				foreach my $pat (@wordpatts) {
					$caughtp->{$pat}{$class}{$f1}{$id}=1;
					custom_rm_from_possiblelist_1extra(%$posp,$pat,$class,$f1,$id);
				}
				$donep->{$id}{$cont}{$f1}=$class;
			}
		}
		delete $newp->{$id};
	}
}

sub custom_move_solved(\@$\%\%\%\%$) {
	my ($solvedp,$c,$newp,$donep,$posp,$caughtp,$to) = @_;
	if ($custom_use eq 'context_and_1feat') {
		custom_move_solved_1extra(@$solvedp,$c,%$newp,%$donep,%$posp,%$caughtp,$to);
	} elsif ($custom_use eq 'context_only') {
		custom_move_solved_std(@$solvedp,$c,%$newp,%$donep,%$posp,%$caughtp,$to);
	} elsif ($custom_use eq 'bio_specific') {
		custom_move_solved_bio(@$solvedp,$c,%$newp,%$donep,%$posp,%$caughtp,$to);
	}	
}


sub custom_move_replaced_std(\@$\%\%\%\%$) {
	my ($replacedp,$c,$newp,$donep,$posp,$caughtp,$to) = @_;
	foreach my $id (@{$replacedp}) {
		print "Redo instance to prevent override: [$id]\n" if $msg;
		foreach my $cont (keys %{$donep->{$id}}) {
			my @wordpatts = get_all_pats_limit($cont,1,$to);
			my $class = ${$donep->{$id}}{$cont};
			foreach my $pat (@wordpatts) {
				if (!(exists $rule{$pat})) {
					${$posp->{$pat}}{$class}{$id}=1;
					custom_rm_from_caughtlist_std(%$caughtp,$pat,$class,$id);
				}
			}
			$newp->{$id}{$cont}=$class;
			
		}
		delete $donep->{$id};
	}
}


sub custom_move_replaced_1extra(\@$\%\%\%\%$) {
	my ($replacedp,$c,$newp,$donep,$posp,$caughtp,$to) = @_;
	foreach my $id (@{$replacedp}) {
		print "Redo instance to prevent override: [$id]\n" if $msg;
		foreach my $cont (keys %{$donep->{$id}}) {
			my @wordpatts = get_all_pats_limit($cont,1,$to);
			my $contp = ${$donep->{$id}}{$cont};
			foreach my $f1 (keys %{$contp}) {
				my $class = $contp->{$f1};
				foreach my $pat (@wordpatts) {
					if (!(exists $rule{$pat})) {
						${$posp->{$pat}}{$class}{$f1}{$id}=1;
						custom_rm_from_caughtlist_1extra(%$caughtp,$pat,$class,$f1,$id);
					}
				}
				$newp->{$id}{$cont}{$f1}=$class;
			}
		}
		delete $donep->{$id};
	}
}

sub custom_move_replaced(\@$\%\%\%\%$) {
	my ($replacedp,$c,$newp,$donep,$posp,$caughtp,$to) = @_;
	if ($custom_use eq 'context_and_1feat') {
		custom_move_replaced_1extra(@$replacedp,$c,%$newp,%$donep,%$posp,%$caughtp,$to);
	} elsif ($custom_use eq 'context_only') {
		custom_move_replaced_std(@$replacedp,$c,%$newp,%$donep,%$posp,%$caughtp,$to);
	} elsif ($custom_use eq 'bio_specific') {
		custom_move_replaced_bio(@$replacedp,$c,%$newp,%$donep,%$posp,%$caughtp,$to);
	}	
}


#--------------------------------------------------------------------------	

sub rulegroups_from_patts($$\%\%$) {
	
	#Extract the best <$feat>-specific rulegroups based on the set of patterns in <$posp>
	#Write directly to rulefile 
	#Update globals %rule and %rorder	
	
	my ($feat,$to,$posp,$newp,$rulefile) = @_;
	print "<p>-- Enter rulegroups_from_patts [$feat] [$rulefile]\n" if $debug;
	#open OH, ">$rulefile" or die "Error opening $rulefile";	
	open OH, '>:encoding(utf8)', $rulefile or die "Cannot open $rulefile";	

	$frulenum=0;
	my $displaycnt;
	my %caught=();
	my %done=();
	my $cwin=2;
			
	my $busy=get_next_rules($feat,%$posp,%caught,\$c,@newrules);

	while ($busy==1) {
		my @cnt = keys %$newp;
		my $showcnt = scalar @cnt;
		print "Still to do: $showcnt\n" if $debug;
		foreach my $nr (@newrules){
			my @replaced=custom_get_ids_per_pat_conflict($nr,%caught,$c);
			my @solved=custom_get_ids_per_pat_match($nr,%$posp,$c);
			$displaycnt = $#solved-$#replaced;
			custom_add_rule($feat,$nr,$c,$displaycnt);

			custom_move_solved(@solved,$c,%$newp,%done,%$posp,%caught,$to);
			custom_move_replaced(@replaced,$c,%$newp,%done,%$posp,%caught,$to);
						
			#my $nr_ctxt = get_rule_context($nr);			
			#my $nr_feat = get_rule_feat($nr);			
			#if (exists $posp->{$nr_ctxt}) {
			#	my $nrp=$patp->{$nr_ctxt};
			#	my @clist = keys %{$nrp};
			#	foreach my $c (@clist) {
			#		my $cp=$nrp->{$c};
			#		my @featlist = keys %{$cp};
			#		my $keep=0;
			#		foreach my $f (@featlist) {
			#			$fp = $cp->{$f};
			#			if (($nr_feat eq '')||($nr_feat eq $f)) { 
			#				my @idlist = keys %{$fp};
			#				foreach my $i (@idlist) {
			#					delete $fp->{$id};
			#				}
			#				delete $cp->{$f};
			#			} else {
			#				$keep=1;
			#			}
			#		}
			#		if ($keep==0) {
			#			delete $nrp->{$c};
			#		}
			#	}
			#	my @clist = keys %{$nrp};
			#	if (@clist <=0) {
			#		delete $patp->{$nr_ctxt};
			#	}
			#}
		}
		
		$busy=get_next_rules($feat,%$posp,%caught,\$c,@newrules);
		my $nr = $newrules[$#newrules];
		
		if ($busy==1){
			my $newlen = (get_rule_length($nr)-2);
			#my $newlen=0;
			if ($newlen>($to-$cwin)) {
				if ($newlen < 18) {
					$from = $to+1;
					$to = $to+$cwin;
					print "Adding contexts from [$from] to [$to]\n";
					custom_add_patts_limit($from,$to,%done,%$newp,%$posp,%caught);
				} else {
					$busy=0;
				}
			}
		}
	}
	foreach my $id (keys %new) {
		print "Error: missed $id\n";
	}
	
	close OH;
	
	#Add 1-feat backoff rule, if missed by other rules
	custom_check_and_add_default($feat,$rulefile);
}


#--------------------------------------------------------------------------

sub find_rules_single($$$) {
	my ($feat,$pattsfile,$rulefile)=@_;
	%rule=();
	%rulecnt=();
	my %patts=();
	my %new=();
	my $found=0;
	if (-e $pattsfile) {
		my $tmpFH=select (STDOUT);
		$|=1;
		select($tmpFH);
		custom_fread_pattsfile_limit(1,8,$pattsfile,%patts,%new);
		my @cnt = keys %new;
		if (scalar @cnt > 0) {
			my $num=$#cnt+1;
			print "Finding best rules for [$feat] [$num]\n";
			rulegroups_from_patts($feat,8,%patts,%new,$rulefile);
			$found=1;
		}
	}
	if ($found==0) {
		custom_check_and_add_default($feat,$rulefile);
	}
}

#--------------------------------------------------------------------------

sub fwrite_patts_dr(\%$$) {
	my ($allp,$featf,$fname) = @_;
	foreach my $g (keys %$allp) {
		open OH, ">>$fname.$g" or die "Error opening $fname.$g\n";
		my $gp = $allp->{$g}; 
		foreach my $pat (keys %$gp) {
			print OH "$pat\n";
			delete $gp->{$pat};
		}
		close OH;
	}
	my @features=();
	fread_array(@features,$featf);
	foreach my $f (@features) {
		`touch "$fname.$f"`
	}	
}

sub custom_extract_patts_std($$$) {
	my ($featf,$dataf,$pattsf) = @_;
	print "-- Enter extract_patts_single\n" if $debug;
	
	my %all = ();
	my $max_words=10000;
	frm_patts($pattsf,$featf);
	fread_align($dataf,%agd,%apd);
	
	my $cnt=0;
	my $id=0;
	foreach $word (keys %agd) {
		my @gstr = @{$agd{$word}};
		push @gstr," ";
		unshift @gstr," ";
		my @pstr = @{$apd{$word}};
		push @pstr," ";
		unshift @pstr," ";
		my $patstr = join "",@gstr;
		my $wlen = length $patstr;
		for my $i (1..$#gstr-1) {
			my $g = $gstr[$i];
			my $p = $pstr[$i];
			my $l = substr ($patstr,0,$i);
			my $r = substr ($patstr,$i+1);
			my $w = $l."-".$g."-".$r;
			#my $id = $w;
			#$id =~ s/ //g;
			#$id =~ s/0//g;
			$id++;
			$all{$g}{"$id;$p;$w"}=1;
		}
		$cnt++;
		if ($cnt==$max_words) {
			fwrite_patts_dr(%all,$featf,$pattsf);
			$cnt=0;
		}
		delete $agd{$word};
		delete $apd{$word};
	}
	fwrite_patts_dr(%all,$featf,$pattsf);
}


sub custom_extract_patts_1extra($$$) {
	my ($featf,$dataf,$pattsf) = @_;
	print "-- Enter extract_patts_single\n" if $debug;
	
	my %all = ();
	my $max_words=10000;
	frm_patts($pattsf,$featf);
	fread_align($dataf,%agd,%apd);
	
	my $cnt=0;
	my $id=0;
	foreach $word (keys %agd) {
		foreach my $f (keys %{$agd{$word}}) {
			my @gstr = @{$agd{$word}{$f}};
			push @gstr," ";
			unshift @gstr," ";
			my @pstr = @{$apd{$word}{$f}};
			push @pstr," ";
			unshift @pstr," ";
			my $patstr = join "",@gstr;
			my $wlen = length $patstr;
			for my $i (1..$#gstr-1) {
				my $g = $gstr[$i];
				my $p = $pstr[$i];
				my $l = substr ($patstr,0,$i);
				my $r = substr ($patstr,$i+1);
				my $w = $l."-".$g."-".$r;
				#my $id = $w;
				#$id =~ s/ //g;
				#$id =~ s/0//g;
				$id++;
				$all{$g}{"$id;$p;$w;$f"}=1;
			}
			$cnt++;
		}
		if ($cnt==$max_words) {
			fwrite_patts_dr(%all,$featf,$pattsf);
			$cnt=0;
		}
		foreach my $f (keys %{$agd{$word}}) {
			delete $agd{$word}{$f};
			delete $apd{$word}{$f};
		}
		delete $agd{$word};
		delete $apd{$word};
	}
	fwrite_patts_dr(%all,$featf,$pattsf);
}

sub custom_extract_patts($$$) {
	my ($featf,$dataf,$pattsf) = @_;
	if ($custom_use eq 'context_and_1feat') {
		custom_extract_patts_1extra($featf,$dataf,$pattsf);
	} elsif ($custom_use eq 'context_only') {
		custom_extract_patts_std($featf,$dataf,$pattsf);
	} elsif ($custom_use eq 'bio_specific') {
		custom_extract_patts_bio($featf,$dataf,$pattsf);
	}	
}

#--------------------------------------------------------------------------

sub custom_fread_rules_1extra($) {
	#Read ruleset from file
	#Update globals %rule,%rorder,%rulecnt,%numfound,$frulenum
	my $fname = shift @_;
	print "-- Enter fread_rules_1extra: $fname\n" if $debug;
	open RH, "$fname" or die "Error opening $fname\n";

	%rule = ();
	%rorder=();
	%rulecnt=();
	%numfound=();
	my ($grph,$left,$right,$f1,$phn,$cnt,$numi);
	while (<RH>) {
		chomp;
		my @line=split ";";
		if (scalar @line==7) {
			($grph,$left,$right,$f1,$phn,$cnt,$numi) = @line;
		} else {
			die "Error: problem with $fname rule format: @line";
		}
		my $pattern = "$left-$grph-$right";
		if (!($f1 eq '')) {
			$pattern = $pattern . '&&' . $f1;
		}
		$rule{$pattern} = $phn;
		$rorder{$grph}[$cnt]=$pattern;
		$rulecnt{$pattern}=$cnt;
		$numfound{$pattern}=$numi;
		$frulenum=$cnt;
	}
	close RH;
}


sub fread_rules_dr($) {
	my $fname = shift @_;
	if ($custom_use eq 'context_and_1feat') {
		custom_fread_rules_1extra($fname);
	} elsif ($custom_use eq 'context_only') {
		fread_rules_olist($fname);
	} elsif ($custom_use eq 'bio_specific') {
		fread_rules_olist($fname);
	}
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------
