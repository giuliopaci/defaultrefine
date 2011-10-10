package g2pTrees;

use g2pFiles;
use g2pRules;
use Graph;
#use Graph::Layouter::Spring;
#use Graph::Renderer::Imager;
use Imager;
use Array::Compare;

#use g2pAlign;
#use g2pDict;
#use Time::Local;
#use AnyDBM_File;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$msg = 1;
	$debug = 1;
	
	%pcolors = ('1'=>'blue','2'=>'brown','3'=>'green','4'=>'cyan','5'=>'black','6'=>'red', 7=>'orange',8=>'magenta',9=>'yellow');
	%status_types = ('normal'=>'1','conflict'=>'1','minrule'=>'1','word'=>'1');
	%edge_types = ('decided'=>'1','possible1'=>'1','possible2'=>'1');
	%node_types = ('complete'=>'1','single'=>'1');
	
	$pcolor_num = 0;		#Display: colour per phoneme
	%pcolor_index = ();
	$no=0;				#Display: Number of tree jpg being displayed
	#Display: Drawing trees with possible orders ('all'), without ('decided_only'), drawing two trees ('both') or none ('none')
	#$draw_type = 'decided_only';	
	#$draw_type = 'all';		
	#$draw_type = 'both';
	$draw_type = 'both';		

	%poswords=();			#possible_words per rule, given decided orderings and set of minrules (Z_e)
	%variants=();			#identified variants
	%mincomp=();			#all minimal complements
	#%startorder=();
	#%keepkids=();
	
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&fbuild_tree &get_kids &get_parents &has_path_of_type);
}

#--------------------------------------------------------------------------
# Node helper functions
#--------------------------------------------------------------------------

sub get_display_name($$) {
	my ($gtreep,$v) = @_;
	my @outcomes = get_outcomes($gtreep,$v);
	my $vstat = get_status($gtreep,$v);
	my $name;
	
	if ($vstat eq 'word') {
		$name = "$v:$outcomes[0]";
	} else {
		$name = "$v:";
		foreach my $out (@outcomes) {
			my $poscount=0;
			if (exists $poswords{$v}{$out}) {
				$poscount = scalar keys %{$poswords{$v}{$out}};
			} 
			$name = $name.$out."($poscount)";
		}
	}
	return $name;
}


sub get_color($$) {
	my ($gtreep,$v) = @_;
	my @outcomes = get_outcomes($gtreep,$v);
	if (@outcomes != 1) {
		die "Error: more than one outcome\n";
	}
	return $pcolors{$pcolor_index{$outcomes[0]}};
}


sub get_outcomes($$) {
	my ($gtreep,$v) = @_;
	my $out;
	if (!($$gtreep->has_attribute('out',$v))) {
		die "Error: node $v does not have an outcome";
	} else {
		$out=$$gtreep->get_attribute('out',$v);
	}
	my @outcomes = split /;/,$out;
	return @outcomes;
}


sub get_single_outcome($$) {
	my ($gtreep,$v) = @_;
	my @out = get_outcomes($gtreep,$v);
	if (@out!=1) {
		die "Error: more than one outcome where single expected ($v -> @out)\n";
	}
	return $out[0];
}


sub get_status($$) {
	my ($gtreep,$v) = @_;
	if (!($$gtreep->has_attribute('status',$v))) {
		die "Error: node $v does not have a status";
	} else {
		my $stat=$$gtreep->get_attribute('status',$v);
		if (!(exists $status_types{$stat})) {
			die "Error: status type $stat not allowed\n";;
		}
		return $stat;
	}
}


sub is_conflict($$) {
	my ($gtreep,$v) = @_;
	my $vstat = get_status($gtreep,$v);
	if ($vstat eq "conflict") {
		return 1;
	}
	return 0;
}


sub is_word($$) {
	my ($gtreep,$v) = @_;
	my $vstat = get_status($gtreep,$v);
	if ($vstat eq "word") {
		return 1;
	}
	return 0;
}

sub is_minrule($$) {
	my ($gtreep,$v) = @_;
	my $vstat = get_status($gtreep,$v);
	if ($vstat eq "minrule") {
		return 1;
	}
	return 0;
}


sub is_normal($$) {
	my ($gtreep,$v) = @_;
	my $vstat = get_status($gtreep,$v);
	if ($vstat eq "normal") {
		return 1;
	}
	return 0;
}


sub is_single($$) {
	my ($gtreep,$v) = @_;
	if ($$gtreep->has_attribute('single',$v)==1) {
		return 1;
	} else {
		return 0;
	}
}


sub is_complete($$) {
	my ($gtreep,$v) = @_;
	if ($$gtreep->has_attribute('complete',$v)==1) {
		return 1;
	} else {
		return 0;
	}
}


sub is_match($$) {
	my ($v1,$v2) = @_;
	$v1 =~ s/[\[\]]//g;
	$v2 =~ s/[\]\[]//g;

	if ($v1 !~ /^(.*)-.-(.*)$/) {
		die "Error in format: [$v1]\n";
	} 
	my $v1l = $1;
	my $v1r = $2;
	if ($v2 !~ /^(.*)-.-(.*)$/) {
		die "Error in format: [$v2]\n";
	} 
	my $v2l = $1;
	my $v2r = $2;
	if ( (($v1l =~ /.*$v2l$/)||($v2l =~ /.*$v1l$/))
	      &&(($v1r =~ /^$v2r.*/)||($v2r =~ /^$v1r.*/))) {
		return 1;
	}
	return 0;
}	


sub is_outcome_in_node($$$) {
	my ($gtreep,$p,$v) = @_;
	#print "Entering is_outcome_in_node [$p] [$v]\n";
	my @outcomes = get_outcomes($gtreep,$v);
	foreach my $out (@outcomes) {
		if ($p eq $out) {
			return 1;
		}
	}
	return 0;
}


sub get_immediate_parents($$$) {
	my ($gtreep,$v,$vtype) = @_;	
	my %returnparents = ();
	my %allowed=();
	my @vtypelist = split /_/,$vtype;
	foreach my $vtype (@vtypelist) {
		$allowed{$vtype}=1;
	}
	my @vlist = $$gtreep->predecessors($v);
	foreach my $v2 (@vlist) {
		my %atlist = $$gtreep->get_attributes($v2,$v);
		foreach my $a (keys %atlist) {
			if (exists $allowed{$a}) {
				$returnparents{$v2}=1;
			}
			last;
		}
	}
	return %returnparents;
}

sub get_next_parents($$) {
	my ($gtreep,$v) = @_;	
	my %returnparents = get_immediate_parents($gtreep,$v,'decided_possible1_possible2');
	return %returnparents;
}

sub get_immediate_kids($$$) {
	my ($gtreep,$v,$vtype) = @_;	
	my %returnkids = ();
	my %allowed=();
	my @vtypelist = split /_/,$vtype;
	foreach my $vtype (@vtypelist) {
		$allowed{$vtype}=1;
	}
	my @vlist = $$gtreep->successors($v);
	foreach my $v2 (@vlist) {
		my %atlist = $$gtreep->get_attributes($v,$v2);
		foreach my $a (keys %atlist) {
			if (exists $allowed{$a}) {
				$returnkids{$v2}=1;
			}
			last;
		}
	}
	return %returnkids;
}

sub get_next_kids($$) {
	my ($gtreep,$v) = @_;	
	my %returnkids = get_immediate_kids($gtreep,$v,'decided_possible1_possible2');
	return %returnkids;
}


# Find all kids: 
# - starting at node <v> 
# - along all <vtype> paths		decided, possible, decided_possible
# - with a specific <vstatus>		normal,conflict,minrule,word
# - via rules of status <vstatvia>	normal, conflict,minrule, word
# - first only or all			first,all

sub get_kids($$$$$$) {
	my ($gtreep,$v,$vtype,$vstat,$vstatvia,$vwho) = @_;	
	my %returnkids = ();
	my %allowed=();
	my %allowed_via=();
	
	my @vstatlist = split /_/,$vstat;
	foreach my $s (@vstatlist) {
		$allowed{$s}=1;
	}
	@vstatlist = split /_/,$vstatvia;
	foreach my $s (@vstatlist) {
		$allowed_via{$s}=1;
	}
	my @vlist = ($v);
	my %vdone=();
	while (scalar @vlist>0) {
		my $r = shift @vlist;
		next if $vdone{$r};
		my %kids = get_immediate_kids($gtreep,$r,$vtype);
		foreach my $k (keys %kids) {
			my $kstat = get_status($gtreep,$k);
			if (exists $allowed{$kstat}) {
				$returnkids{$k}=1;
				if ($vwho eq 'all') {
					push @vlist,$k;
				}
			} elsif (exists $allowed_via{$kstat}) {
				push @vlist,$k;
			}
		}
		$vdone{$r}=1;
	}
	
	if ($vwho eq 'first') {
		my @poskids = keys %returnkids;
		foreach my $i2 (0..$#poskids) {
			foreach my $i1 (0..$#poskids) {
				next if $i1 == $i2;
				if (has_path_of_type($gtreep,$poskids[$i1],$poskids[$i2],$vtype)==1) {
					if (exists $returnkids{$poskids[$i2]}) {
						delete $returnkids{$poskids[$i2]};
					}
					last;
				}
			}
		}
	}
	return %returnkids;
}	


sub get_parents($$$$$$) {
	my ($gtreep,$v,$vtype,$vstat,$vstatvia,$vwho) = @_;	
	my %returnparents = ();
	my %allowed=();
	my %allowed_via=();
	
	my @vstatlist = split /_/,$vstat;
	foreach my $s (@vstatlist) {
		$allowed{$s}=1;
	}
	@vstatlist = split /_/,$vstatvia;
	foreach my $s (@vstatlist) {
		$allowed_via{$s}=1;
	}
	
	my @vlist = ($v);
	my %vdone=();
	while (scalar @vlist>0) {
		my $r = shift @vlist;
		next if $vdone{$r};
		my %parhash = get_immediate_parents($gtreep,$r,$vtype);
		my @parents = keys %parhash;
		foreach my $p (@parents) {
			my $pstat = get_status($gtreep,$p);
			if (exists $allowed{$pstat}) {
				$returnparents{$p}=1;
				if ($vwho eq 'all') {
					push @vlist,$p;
				}
			} elsif (exists $allowed_via{$pstat}) {
				push @vlist,$p;
			}
		}
		$vdone{$r}=1;
	}
	
	if ($vwho eq 'first') {
		my @posparents = keys %returnparents;
		foreach my $i2 (0..$#posparents) {
			foreach my $i1 (0..$#posparents) {
				next if $i1 == $i2;
				if (has_path_of_type($gtreep,$posparents[$i1],$posparents[$i2],$vtype)==1) {
					if (exists $returnparents{$posparents[$i1]}) {
						delete $returnparents{$posparents[$i1]};
					}
					last;
				}
			}
		}
	}
	return %returnparents;
}	


#return all words that matches a rule v
sub get_possible_words($$) {
	my ($gtreep,$v)=@_;
	my %pos_out = %{$poswords{$v}};
	my %words = ();
	foreach my $out (keys %pos_out) {
		my @outwords = keys %{$poswords{$v}{$out}};
		foreach my $w (@outwords) {
			$words{$w}=1;
		}
	}
	return %words;
}


#return all words that matches rule v - and has an appropriate outcome
sub get_correct_words($$) {
	my ($gtreep,$v)=@_;
	my @outcomes = get_outcomes($gtreep,$v);
	my %words = ();
	foreach my $out (@outcomes) {
		my @outwords = keys %{$poswords{$v}{$out}};
		foreach my $w (@outwords) {
			$words{$w}=1;
		}
	}
	return %words;
}



# 1 if v1's pattern is a containpat of v2's pattern
sub is_containpat($$) {
	my ($v1,$v2)=@_;
	$v1 =~ s/[\[\]]//g;
	$v2 =~ s/[\]\[]//g;
	if ($v1 =~ /$v2/) {
		return 1;
	}
	if ($v2 =~ /$v1/) {
		return -1;
	}
	return 0;
}


sub is_mincomp($$$) {
	my ($gtreep,$v1,$v2)=@_;
	if (exists $mincomp{$v1}{$v2}) {
		return 1;
	} else {
		return 0;
	}
	
	#if (is_containpat($v1,$v2)==1) {
	#	return 0;
	#}
	#if (is_containpat($v2,$v1)==1) {
	#	return 0;
	#}
	#my %v1_words = get_possible_words($gtreep,$v1); #need matchwords
	#my %v2_words = get_possible_words($gtreep,$v2);
	#foreach my $w (keys %v1_words) {
	#	if (exists $v2_words{$w}) {
	#		return 1;
	#	}
	#}
	#return 0;
}


#--------------------------------------------------------------------------
# Draw functions
#--------------------------------------------------------------------------

sub create_tree_dotfile($$$$) {
	my ($gtreep,$gname,$showmin,$fname)=@_;
	
	open FH, ">:encoding(utf8)","$fname" or die "Error writing to $fname\n";
	print FH "digraph G\n {\nlabel=\"$gname\"\n";
	#print FH "digraph G\n {\n";
	my @all_vertices =$$gtreep->vertices();
	my $num_rules = count_rules($gtreep);
	print "Tree for $fname: [$num_rules] $gname\n";
	while ((scalar @all_vertices)>0) {
		my $v1 = shift @all_vertices;
		my $vname = get_display_name($gtreep,$v1);
		my $vstat = get_status($gtreep,$v1);
		
		if (is_single($gtreep,$v1)==1) {
			$vname = "$vname *S";
		}
		if (is_complete($gtreep,$v1)==1) {
			$vname = "$vname *C";
		}
				
		if ($vstat eq 'word') {
			print FH "\t\"$v1\" [label=\"$vname\",color=green,style=filled,fillcolor=green];\n";
		} elsif ($vstat eq 'conflict') {
			print FH "\t\"$v1\" [label=\"$vname\",color=orange,style=filled,fillcolor=orange];\n";
		} else {
			my $vcolor = get_color($gtreep,$v1);
			if ($vstat eq 'minrule') {
				print FH "\t\"$v1\" [label=\"$vname\",color=$vcolor,style=filled,fillcolor=yellow];\n";
			} elsif ($vstat eq "normal") {
				print FH "\t\"$v1\" [label=\"$vname\",color=$vcolor,style=filled,fillcolor=white];\n";
			} else {
				print FH "\t\"$v1\" [label=\"$vname\",color=red,style=filled,fillcolor=red];\n";
				#There shouldn't be any red nodes
			}
		}
	}
	
	my @all_edges = $$gtreep->edges();
	while ((scalar @all_edges)>0) {
		my $v1 = shift @all_edges;
		my $v2 = shift @all_edges;
		if ($$gtreep->has_attribute('possible1',$v1,$v2)) {
			if ($showmin==1) {
				print FH "\t\"$v1\" -> \"$v2\" [color=red];\n";
			}
		} elsif ($$gtreep->has_attribute('possible2',$v1,$v2)) {
			#if (($showmin==1)||($v1 eq '-e-st')||($v2 eq '-e-st')) {
			if ($showmin==1) {
				print FH "\t\"$v1\" -> \"$v2\" [color=orange];\n";
			}
		} elsif ($$gtreep->has_attribute('decided',$v1,$v2))  {
			print FH "\t\"$v1\" -> \"$v2\" [color=black];\n";
		} else {
			print FH "\t\"$v1\" -> \"$v2\" [color=green];\n";
			#There shouldn't be any gree edges
		}
	}
	print FH "}\n";
	close FH;
}


sub draw_tree($$$$){
	my ($gtreep,$gname,$showmin,$fname)=@_;
	my $textfile = "$fname.dat";
	my $imagefile = $fname;
	create_tree_dotfile($gtreep,$gname,$showmin,$textfile);
	system "dot -Tjpeg $textfile -o $imagefile";
}


sub do_draw_tree($$$) {
	my ($nop,$gtreep,$caption)=@_;
	my $startdraw = 5;
	if ($$nop<$startdraw) {
		$$nop++;
		return;
	}
	
	if (($draw_type eq 'both')||($draw_type eq 'decided_only')) {
		$$nop++;
		#$caption="";
		draw_tree($gtreep,$caption,0,"tree_$$nop.jpg");
	}
	if (($draw_type eq 'both')||($draw_type eq 'all')) {
		$$nop++;
		draw_tree($gtreep,$caption,1,"tree_$$nop.jpg");
	}
}

#--------------------------------------------------------------------------
# Graph analysis functions
#--------------------------------------------------------------------------

sub has_single_parent_option($$) {
	my ($gtreep,$v) = @_;
	my %parents = get_next_parents($gtreep,$v);
	my $numopts = scalar keys %parents;
		if ($numopts==1) {
		return 1;
	}
	return 0;
}

#1 if node has only one option child
sub has_single_child_option($$) {
	my ($gtreep,$v) = @_;
	my %kids = get_next_kids($gtreep,$v);
	my $numopts = scalar keys %kids;
	if ($numopts==1) {
		return 1;
	}
	return 0;
}

sub has_conflict_parent($$) {
	my ($gtreep,$v) = @_;
	my %parents = get_next_parents($gtreep,$v); 
	foreach my $p (keys %parents) {
		if (is_conflict($gtreep,$p)==1) {
			return 1;
		}
	}
	return 0;
}

sub has_same_single_outcome($$$) { 
	my ($gtreep,$v1,$v2) = @_;
	@v1n = get_outcomes($gtreep,$v1);
	@v2n = get_outcomes($gtreep,$v2);
	if (@v1n != 1) {
		die "Error: $v1 has more than one outcome [@v1n]\n";
	}
	if (@v2n != 1) {
		die "Error: $v2 has more than one outcome [@v2n]\n";
	}
	if ($v1n[0] eq $v2n[0]) {
		return 1;
	} else {
		return 0;
	}
}


sub have_identical_parents($$$$) {
	my ($gtreep,$v1,$v2,$vtype) = @_;
	#print "Entering have_identical_parents $v1,$v2,$vtype\n" if $debug;
	my %parents1 = get_immediate_parents($gtreep,$v1,$vtype);
	my %parents2 = get_immediate_parents($gtreep,$v2,$vtype);
	if (scalar (keys %parents1) != scalar (keys %parents2)) {return 0;}
	foreach my $k1 (keys %parents1) {
		if (!(exists $parents2{$k1})) {
			return 0;
		}
	}
	return 1;
}

sub have_identical_children($$$$) {
	my ($gtreep,$v1,$v2,$vtype) = @_;
	#print "Entering have_identical_children $v1,$v2,$vtype\n" if $debug;
	my %kids1 = get_immediate_kids($gtreep,$v1,$vtype);
	my %kids2 = get_immediate_kids($gtreep,$v2,$vtype);
	if (scalar keys %kids1 != scalar keys %kids2) {return 0;}
	foreach my $k1 (keys %kids1) {
		if (!(exists $kids2{$k1})) {
			return 0;
		}
	}
	return 1;
}


#Note that each own node is added to other set when comparing
sub have_identical_siblings($$$$) {
	my ($gtreep,$v1,$v2,$vtype) = @_;
	#print "Entering have_identical_children $v1,$v2,$vtype\n" if $debug;
	my %kids1 = get_immediate_kids($gtreep,$v1,$vtype);
	my %kids2 = get_immediate_kids($gtreep,$v2,$vtype);
	my %parents1 = get_immediate_parents($gtreep,$v1,$vtype);
	my %parents2 = get_immediate_parents($gtreep,$v2,$vtype);
	
	my %all1=();
	foreach my $k (keys %kids1) {
		$all1{$k}=1;
	}
	foreach my $p (keys %parents1) {
		$all1{$p}=1;
	}
	
	my %all2=();
	foreach my $k (keys %kids2) {
		$all2{$k}=1;
	}
	foreach my $p (keys %parents2) {
		$all2{$p}=1;
	}
	if (exists $all2{$v1}) {
		$all1{$v1}=1;
	}
	if (exists $all1{$v2}) {
		$all2{$v2}=1;
	}
	
	my $out = get_single_outcome($gtreep,$v1);
	if (scalar keys %all1 != scalar keys %all2) {return 0;}
	foreach my $a (keys %all1) {
		if (!(exists $all2{$a})) {
			return 0;
		}
		if (is_conflict($gtreep,$a)==1) {
			return 0;
		}
		my $a_out = get_single_outcome($gtreep,$a);
		if (!($a_out eq $out)) {
			return 0;
		}
	}
	return 1;
}


#1 if a path of a specific type from <p> to <k>
sub has_path_of_type($$$$) {
	my ($gtreep,$p,$k,$vtype)=@_;
	my @vlist = ($p);
	my %vdone=();
	while (scalar @vlist >0) {
		my $p=shift @vlist;
		next if exists $vdone{$p};
		my %kids = get_immediate_kids($gtreep,$p,$vtype);
		my @kidlist = keys %kids;
		foreach my $kid (@kidlist) {
			if ($kid eq $k) {
				return 1;
			}
		}
		push @vlist,@kidlist;
		$vdone{$p}=1;
	}
	return 0;
}

sub has_noconflict_path_first_agree($$$) {
	my ($gtreep,$v1,$v2)=@_;
	my @vlist = ($v1);
	my %vdone=();
	my %found=();
	my %kids = get_immediate_kids($gtreep,$v1,'possible1_decided');
	my $OK=1;
	foreach my $k (keys %kids) {
		if (($k eq $v2)||(has_path_of_type($gtreep,$k,$v2,'possible1_decided')==1)) {
			if (is_conflict($gtreep,$k)==1) {
				$OK=0;
			} elsif (has_same_single_outcome($gtreep,$k,$v1)==0) {
				$OK=0;
			} 
		}
	}
	return $OK;	
}


#via may never be possible2 - will loop!
sub has_conflicted_path($$$) {
	my ($gtreep,$v1,$v2)=@_;
	my @vlist = ($v1);
	my %vdone=();
	my %found=();
	while (scalar @vlist >0) {
		my $p=shift @vlist;
		#next if exists $vdone{$p};
		my %kids = get_immediate_kids($gtreep,$p,'possible1_decided');
		my @kidlist = keys %kids;
		foreach my $kid (@kidlist) {
			if ((is_conflict($gtreep,$p)==1)||(is_conflict($gtreep,$kid)==1)||(has_same_single_outcome($gtreep,$p,$kid)==0)) {
				$found{$kid}=1;
			}
			if ((exists $found{$kid})&&($kid eq $v2)) {
				return 1;
			}
		}
		push @vlist,@kidlist;
		#$vdone{$p}=1;
	}
	return 0;	
}

#--------------------------------------------------------------------------
# Graph initialisation functions
#--------------------------------------------------------------------------

sub add_edge($$$$) {
	my ($gtreep,$v1,$v2,$type)=@_;
	
	if ($$gtreep->has_edge($v1,$v2)==1) {
		if ($$gtreep->has_attribute($type,$v1,$v2)==1) {
			return 0;
		}
		if (($type eq 'possible1')&&($$gtreep->has_attribute('decided',$v1,$v2)==1)) {
			return 0;
		}
	}
	if (($type eq 'decided')&&(has_path_of_type($gtreep,$v1,$v2,'decided')==1)) {
		return delete_possible2($gtreep,$v1,$v2);
	}
	
		
	if ($$gtreep->has_edge($v1,$v2)==0) {
		$$gtreep->add_edge($v1,$v2);
		print "Adding $type edge: $v1 -> $v2\n" if $debug;
		
	}
	my @atts = $$gtreep->get_attributes($v1,$v2);
	foreach my $a (@atts) {
		$$gtreep->delete_attribute($a,$v1,$v2);
	}
	$$gtreep->set_attribute($type,$v1,$v2,'1');
	if (($type eq 'decided')||($type eq 'possible1')) {
		if ($$gtreep->has_edge($v2,$v1)==1) {
			$$gtreep->delete_edge($v2,$v1);
			print "Removing possible edge: $v2 -> $v1\n" if $debug;
		}
	}
	return 1;
}

sub add_outcome($$$) {
	my ($gtreep,$p,$v) = @_;
	my @outcomes = get_outcomes($gtreep,$v);
	my $outstr = "";
	foreach my $out (@outcomes) {
		if ($out eq $p) {
			return;
		}
		$outstr = $outstr . "$out;"
	}
	$outstr = $outstr."$p";
	$$gtreep->set_attribute('out',"$v","$outstr");
}


#Create tree from patts file
sub fread_gpatts_tree($$$) {
	#Read all patterns from pattsfile <$fname> (related to a single grapheme)
	#and update tree <gtree> creating conflict nodes in the process
	my ($g,$fname,$gtreep) = @_;
	
	%poswords=();
	open IH, "<:encoding(utf8)", "$fname" or die "Error opening $fname\n";
	my $num=0;
	while (<IH>) {
		chomp;
		my ($p,$w) = split ";";
		$w =~ s/ /\#/g;
		if (!(exists $pcolor_index{$p})) {
			$pcolor_num++;
			$pcolor_index{$p}=$pcolor_num;
		}
		print "-------$w-------\n" if $debug;
		
		my $pat = "-$g-";
		if ($$gtreep->has_vertex($pat)!=1) {
			$$gtreep->add_vertex($pat);
			print "Adding node: $pat [$p]\n" if $debug;
			$$gtreep->set_attribute('out',$pat,$p); 
			$$gtreep->set_attribute('status',$pat,'normal');
		}
		push @todo,$pat;
		
		#%patlist=();
		#$patlist{$pat}=1;
		$poswords{$pat}{$p}{"[$w]"}=1;
		while ((scalar @todo)>0) {
			my $prevpat = pop @todo;
			if ($w =~ /(.)$prevpat/) {
				my $pat = $1.$prevpat;
				if ($$gtreep->has_edge($pat,$prevpat)!=1) {
					$$gtreep->add_edge($pat,$prevpat);
					print "Adding edge: $pat -> $prevpat [$p]\n" if $debug;
					$$gtreep->set_attribute('decided',$pat,$prevpat,1); #containpat = decided
					$$gtreep->set_attribute('out',$pat,$p); 
					$$gtreep->set_attribute('status',$pat,'normal');
				} else {
					if (is_outcome_in_node($gtreep,$p,$pat)!=1) {
						$$gtreep->set_attribute('status',$pat,'conflict');
						add_outcome($gtreep,$p,$pat);
						print "Adding outcome: $pat [$p]\n" if $debug;
					}
					if (is_outcome_in_node($gtreep,$p,$prevpat)!=1) {
						$$gtreep->set_attribute('status',$prevpat,'conflict');
						add_outcome($gtreep,$p,$prevpat);
						print "Adding outcome: $prevpat [$p]\n" if $debug;
					}
				} 
				push @todo,$pat;
				$poswords{$pat}{$p}{"[$w]"}=1;
				#$patlist{$pat}=1;
			}
			if ($w =~ /$prevpat(.)/) {
				my $pat = $prevpat.$1;
				if ($$gtreep->has_edge($pat,$prevpat)!=1) {
					$$gtreep->add_edge($pat,$prevpat);
					print "Adding edge: $pat -> $prevpat [$p]\n" if $debug;
					$$gtreep->set_attribute('decided',$pat,$prevpat,1);
					$$gtreep->set_attribute('out',$pat,$p); 
					$$gtreep->set_attribute('status',$pat,'normal');
				} else {
					if (is_outcome_in_node($gtreep,$p,$pat)!=1) {
						$$gtreep->set_attribute('status',$pat,'conflict');
						add_outcome($gtreep,$p,$pat);
						print "Adding outcome: $pat [$p]\n" if $debug;
					}
					if (is_outcome_in_node($gtreep,$p,$prevpat)!=1) {
						$$gtreep->set_attribute('status',$prevpat,'conflict');
						add_outcome($gtreep,$p,$prevpat);
						print "Adding outcome: $prevpat [$p]\n" if $debug;
					}
				}
				push @todo,$pat;
				$poswords{$pat}{$p}{"[$w]"}=1;
				#$patlist{$pat}=1;
			}
		}
		$$gtreep->add_edge("[$w]","$w");
		$$gtreep->set_attribute('status',"[$w]",'word');
		$$gtreep->set_attribute('decided',"[$w]","$w",1);
		$$gtreep->set_attribute('out',"[$w]","$p");
		$num++;
	}
	close IH;
	return $num;
}


#--------------------------------------------------------------------------
#init: conflict nodes

#returns array of conflict nodes
sub get_conflict($\%) {
	my ($gtreep,$fbp) = @_;
	my @vlist=$$gtreep->vertices_unsorted();
	%{$fbp}=();
	foreach my $v (@vlist) {
		if (is_conflict($gtreep,$v)==1) {
			$fbp->{$v}=1;
		}
		$vdone{$v}=1;
	}
	return scalar keys %{$fbp};
}

#--------------------------------------------------------------------------
# init: order_req

sub get_shared_words($$$) {
	my ($gtreep,$v1,$v2)=@_;
	my %swords=();
	foreach my $p (keys %{$poswords{$v1}}) {
		foreach my $w (keys %{$poswords{$v1}{$p}}) {
			if ((exists $poswords{$v2}{$p})&&(exists $poswords{$v2}{$p}{$w})) {
				$swords{$w}=$p;
			}
		}
	}	
	return %swords;
}


# returns 1 if order_req from $v1 to $v2
# returns -1 if order_req from $v2 to $v1
# returns 0 if no shared words left (no order_req in future)
# returns 2 if inconclusive
sub is_order_req($$$) {
	my ($gtreep,$v1,$v2)=@_;
	my $cnt1=0;
	my $cnt2=0;
	return 2 if is_conflict($gtreep,$v1)==1;
	return 2 if is_conflict($gtreep,$v2)==1;
	
	%swords = get_shared_words($gtreep,$v1,$v2);
	my @swlist = keys %swords;
	if (scalar @swlist<=0) {
		return 0;
	}
	my $out1 = get_single_outcome($gtreep,$v1);
	my $out2 = get_single_outcome($gtreep,$v2);
	return 2 if $out1 eq $out2;
	
	if (scalar @swlist >= 1) {
		foreach my $w (@swlist) {
			if ($swords{$w} eq $out1) {
				$cnt1++;
			} elsif ($swords{$w} eq $out2) {
				$cnt2++;
			} 
		}
	}
	
	if ($cnt2==0) {
		return 1;
	}
	if ($cnt1==0) {
		return -1;
	}
	return 2;
}


#--------------------------------------------------------------------------
# init: supercomps

sub poswords_superset($$$) {
	my ($gtreep,$v1,$v2) = @_;
	my %v1_words = get_possible_words($gtreep,$v1);
	my %v2_words = get_possible_words($gtreep,$v2);
	my @wl1 = keys %v1_words;
	my @wl2 = keys %v2_words;
	my $lc = List::Compare->new(\@wl1, \@wl2);
	if ($lc->is_LequivalentR) {
		return 0;
	}
	if ($lc->is_RsubsetL==1) {
		return 1;
	}
	if ($lc->is_LsubsetR==1) {
		return -1;
	}
	return 0;
}

#--------------------------------------------------------------------------
# init: minimal complements

sub get_mincomps($$\%) {
	my ($gtreep,$v,$wlp)= @_;
	my @wlist = keys %$wlp;
	my %mlist = ();
	foreach my $w (@wlist) {
		my @poslist = ($w);
		my %pdone=();
		while (scalar @poslist > 0) {  
			my $p = shift @poslist;
			next if $pdone{$p};
			my $suppat = is_containpat($p,$v);
			my %tmphash = get_immediate_kids($gtreep,$p,'decided');
			my @tmplist = keys %tmphash;
			if ($suppat==1) {
				push @poslist, @tmplist;
			} elsif ($suppat==0) {
				$mlist{$p}=1;
				push @poslist, @tmplist;
			}
			#if $is_subpat==-1 not possible to find further min_comps
			$pdone{$p}=1;
		}
	}
	return keys %mlist;
}

sub delete_possible2($$$) {
	my ($gtreep,$m,$v)=@_;
	if ($$gtreep->has_edge($m,$v)==1) {
		if ($$gtreep->has_attribute('possible2',$m,$v)==1) {
			$$gtreep->delete_edge($m,$v);
			if ($$gtreep->has_edge($v,$m)==1) {
				$$gtreep->delete_edge($v,$m);
			} else {
				print "Warning: why only one possible2 edge?\n";
			}
			return 1;
		}
	}
	return 0;
}

sub possible_outcome_clash($$$) {
	my ($gtreep,$p,$k)=@_;
	if (is_conflict($gtreep,$p)==1) {
		return 1;
	}
	if (is_conflict($gtreep,$k)==1) {
		return 1;
	}
	my $pout = get_single_outcome($gtreep,$p);
	my $kout = get_single_outcome($gtreep,$k);
	if (!($pout eq $kout)) {
		return 1;
	}
	return 0;
}


sub get_first_minrules($$) {
	my ($gtreep,$v)=@_;
	my %first = get_parents($gtreep,$v,'decided','minrule','normal_conflict','all');
	return %first;
}

sub first_minrules_shared($$$) {
	my ($gtreep,$v1,$v2)=@_;
	return 0 if is_minrule($gtreep,$v1);
	return 0 if is_minrule($gtreep,$v2);
	my %minlist1 = get_first_minrules($gtreep,$v1);
	my %minlist2 = get_first_minrules($gtreep,$v2);
	my @minnum1 = keys %minlist1;
	my @minnum2 = keys %minlist2;
	if ((scalar @minnum1==0)&&(scalar @minnum2==0)) {
		return 1;
	}
	if (scalar (keys %minlist1) != scalar (keys %minlist2)) {return 0;}
	foreach my $m1 (keys %minlist1) {
		if (!(exists $minlist2{$m1})) {
			return 0;
		}
		}
	return 1;
}


sub fix_mincomp($$$) {
	my ($gtreep,$v,$m)=@_;
	my $changed=0;
	if (first_minrules_shared($gtreep,$v,$m)==1) {
		my $is_super=poswords_superset($gtreep,$v,$m);
		if ($is_super==1) {
			$changed = add_edge($gtreep,$m,$v,'decided');
			return $changed;
		} elsif ($is_super==-1) {
			$changed = add_edge($gtreep,$v,$m,'decided');
			return $changed;
		}
	}
	$is_oreq=is_order_req($gtreep,$v,$m);
	if ($is_oreq==1) {
		$changed = add_edge($gtreep,$v,$m,'possible1');
	} elsif ($is_oreq==-1) {
		$changed = add_edge($gtreep,$m,$v,'possible1');
	#} elsif (($is_oreq==0)||(possible_outcome_clash($gtreep,$m,$v)==0)) {
	} elsif ($is_oreq==0) {
		$changed = delete_possible2($gtreep,$m,$v);
	}
	return $changed;
}


sub fix_mincomp_one($$) {
	my ($gtreep,$v)=@_;
	my %all=();
	if (exists $mincomp{$v}) {
		%all = %{$mincomp{$v}};
	}
	foreach my $m (keys %all) {
		fix_mincomp($gtreep,$v,$m);
	}
}

sub fix_mincomp_nodeslist($\%) {
	my ($gtreep,$nlp)=@_;
	print "Entering fix_mincomp_nodeslist\n" if $debug;
	my @vlist = keys %{$nlp};	
	my %vmdone=();
	my $changed=0;
	while (scalar @vlist>0) {
		my $v = shift @vlist;
		my %all=();
		if (exists $mincomp{$v}) {
			%all = %{$mincomp{$v}};
		}
		foreach my $m (keys %all) {
			next if exists $vmdone{$v}{$m};
			if (fix_mincomp($gtreep,$v,$m)==1) {
				$changed =1;
			}
			$vmdone{$v}{$m}=1;
			$vmdone{$m}{$v}=1;
		}
	}
	return $changed;
}


sub add_mincomp_nodeslist($\%) {
	my ($gtreep,$nlp)=@_;
	my @vlist = keys %{$nlp};
	
	my %vmdone=();
	while (scalar @vlist>0) {
		my $v = shift @vlist;
		my %all=();
		if (exists $mincomp{$v}) {
			%all = %{$mincomp{$v}};
		}
		foreach my $m (keys %all) {
			next if exists $vmdone{$v}{$m};
			if (fix_mincomp($gtreep,$v,$m)==0) {
				add_edge($gtreep,$v,$m,'possible2');
				add_edge($gtreep,$m,$v,'possible2');
			}
			$vmdone{$v}{$m}=1;
			$vmdone{$m}{$v}=1;
		}
	}
}


#Add initial orderings given a tree currently containing containpats relationships only
#Add orderreq, supercomp and mincomp relations
#Keep track of all mincomps (agree and disagree, possible1 and possible2) in %mincomp
sub add_init_orderings($) {
	my ($gtreep)=shift @_;
	my @vlist = $$gtreep->vertices_unsorted();
	my %vdone=();
	foreach my $v (@vlist) {
		my $vstat = get_status($gtreep,$v);
		next if $vstat eq 'word';
		my %words = get_possible_words($gtreep,$v);  #need matchwords - using possible_words since add_mincomps only called prior to graph manipulation
		my @mlist=get_mincomps($gtreep,$v,%words);
		print "mincomps: [$v] [@mlist]\n" if $debug;
		foreach my $m (@mlist) {
			$mincomp{$v}{$m}=1;
			$mincomp{$m}{$v}=1;
		}
	}
	my %vhash=();
	foreach my $v (@vlist) {
		$vhash{$v}=1;
	}
	add_mincomp_nodeslist($gtreep,%vhash);
}

#--------------------------------------------------------------------------

#Copy all node and edge attributes, since Graph::copy does not

sub copy_attrib_tree($$) {
	my ($gtreep,$ftreep)=@_;
	$$ftreep->delete_attributes();
	my @vlist = $$gtreep->vertices_unsorted();
	foreach my $v (@vlist) {
		my %alist = $$gtreep->get_attributes($v);
		foreach my $a (keys %alist) {
			$$ftreep->set_attribute($a,$v,$alist{$a});
		}
	}
	my @elist = $$gtreep->edges();
	while ((scalar @elist)>1) {
		my $e1=shift @elist;
		my $e2=shift @elist;
		my %alist = $$gtreep->get_attributes($e1,$e2);
		foreach my $a (keys %alist) {
			$$ftreep->set_attribute($a,$e1,$e2,$alist{$a});
		}
	}
}


#--------------------------------------------------------------------------
# Manipulate rule graph
#--------------------------------------------------------------------------

# manipulate: order_req - not currently used

sub change_to_order_req($$$) {
	my ($gtreep,$v1,$v2)=@_;
	if ($$gtreep->has_edge($v2,$v1)) {
		$$gtreep->delete_edge($v2,$v1);
	}
	if ($$gtreep->has_attribute('possible2',$v1,$v2)) {
		$$gtreep->delete_attribute('possible2',$v1,$v2);
	}
	$$gtreep->set_attribute('possible1',$v1,$v2,1);
}


sub add_order_req($$) {
	my ($nop,$gtreep) = @_;
	print "Entering add_order_req \n" if $debug;
	my $changed=0;
	my %vdone=();
	my @vlist = $$gtreep->vertices_unsorted();
	foreach my $v (@vlist) {
		next if exists $vdone{$v};
		next if is_conflict($gtreep,$v)==1;
		my $vout = get_single_outcome($gtreep,$v);
		my %kids = get_immediate_kids($gtreep,$v,'possible2');
		my @kidlist = keys %kids;
		next if (@kidlist==0);
		foreach my $k (@kidlist) {
			my $vcnt=0;
			my $kcnt=0;
			my $ocnt=0;
			next if exists $vdone{$k};
			next if is_conflict($gtreep,$k)==1;
			my $kout = get_single_outcome($gtreep,$k);
			next if $kout eq $vout;
			print "Considering $v to $k\n";
			%swords = get_shared_words($gtreep,$v,$k);
			my @swlist = keys %swords;
			if (scalar @swlist == 1) {
				foreach my $w (keys %swords) {
					if ($swords{$w} eq $vout) {
						$vcnt++;
					} elsif ($swords{$w} eq $kout) {
						$kcnt++;
					} 
				}
			}
			if ($vcnt==0) {
				change_to_order_req($gtreep,$k,$v);
				$changed=1;
			} elsif ($kcnt==0) {
				change_to_order_req($gtreep,$v,$k);
				$changed=1;
			}
		}
		$vdone{$v}=1;
	}
	return $changed;
}

#--------------------------------------------------------------------------
# manipulate: mark complete_upto rules

sub mark_complete_upto($) {
	my $gtreep = shift @_;
	print "Entering mark_complete_upto \n" if $debug;
	my @vlist = $$gtreep->source_vertices();
	my %vdone=();
	my $changed=0;
	while (@vlist > 0) {
		my $v = shift @vlist;
		next if $vdone{$v};
		my $vstat = get_status($gtreep,$v);
		if (($vstat eq 'word')||(is_complete($gtreep,$v)==1)) {
			push @vlist, $$gtreep->successors($v);
			next;
		}
		my %parents = get_parents($gtreep,$v,'possible1_possible2_decided','normal_conflict','minrule','all');
		my @parentlist = keys %parents;
		if (@parentlist == 0) {
			$$gtreep->set_attribute('complete',$v,1);
			print "Marking complete: $v\n" if $debug;
			$changed=1;
			push @vlist, $$gtreep->successors($v);
		}
		$vdone{$v}=1;
	}
	return $changed;
}

#--------------------------------------------------------------------------
#manipulate: mark needed nodes

sub change_to_needed($$$) {
	my ($gtreep,$v,$fbp)=@_;
	print "Marking as needed: $v \n" if $debug;
	$$gtreep->set_attribute('status',$v,'minrule');
	my $vout = get_single_outcome($gtreep,$v);
	my %vwords = ();
	if (exists $poswords{$v}{$vout}) {
	    %vwords = %{$poswords{$v}{$vout}};
	}
	my %kids = get_immediate_kids($gtreep,$v,'decided');
	my @vlist = keys %kids;
	my %vdone=();
	while (scalar @vlist > 0) {
		my $k = shift @vlist;
		next if exists $vdone{$k};
		my %kwords=();
		if (exists $poswords{$k}{$vout}) {
			%kwords = %{$poswords{$k}{$vout}};
		}
		my $deleted=0;
		foreach my $kw (keys %kwords) {
			if (exists $vwords{$kw}) {
				delete $poswords{$k}{$vout}{$kw};
				$deleted=1;
			}
		}
		if ($deleted==1) {
			my @wordsleft = keys %{$poswords{$k}{$vout}};
			if (scalar @wordsleft <=0) {
				if (is_conflict($gtreep,$k)==1) {
					if (is_outcome_in_node($gtreep,$vout,$k)==1) {
						print "Warning: deleting in mark_needed... (replace conflict lose1) \n"; #Do this on systematic basis later
						replace_conflict_lose1($gtreep,$k,$vout,$fbp);
					}
				} else {
					my $kout = get_single_outcome($gtreep,$k);
					if ($kout eq $vout) {
						print "Warning: deleting after mark_needed... (delete node)\n"; #Do this on systematic basis later
						delete_node($gtreep,$k);
					}
				}
			}
		}
		my %todo = get_immediate_kids($gtreep,$k,'decided');
		foreach my $t (keys %todo) {
			push @vlist,$t;
		}
		$vdone{$k}=1;
	}
}


sub mark_necessary_if($$$) {
	my ($gtreep,$v,$fbp)=@_;
	my $vstat = get_status($gtreep,$v);
	return 0 if !($vstat eq 'normal');  #skip word, minrule, conflict
	
	my $vout = get_single_outcome($gtreep,$v);
	my %kids = get_next_kids($gtreep,$v);
	foreach my $k (keys %kids) {
		if (is_outcome_in_node($gtreep,$vout,$k)==1) {
			return 0;
		}
	}
	change_to_needed($gtreep,$v,$fbp);
	return 1;
}


sub mark_needed($$) {
	my ($gtreep,$fbp) = @_;
	print "Entering mark_needed \n" if $debug;
	my $changed=0;
	my %vdone=();
	my @vlist = $$gtreep->source_vertices();
	while (scalar @vlist >0) {
		my $v = shift @vlist;
		next if exists $vdone{$v};
		my %todo=();
		my $vstat = get_status($gtreep,$v);
		if (($vstat eq 'minrule')||($vstat eq 'word')) {
			#skip word, minrule; stop search on conflict
			%todo = get_next_kids($gtreep,$v);
		} elsif ($vstat eq 'normal') {
			my $options=0;
			my $vout = get_single_outcome($gtreep,$v);
			my %kids = get_next_kids($gtreep,$v);
			foreach my $k (keys %kids) {
				if (is_outcome_in_node($gtreep,$vout,$k)==1) {
					$options=1;
					last;
				}
			}
			if ($options==0) {
				%todo = get_next_kids($gtreep,$v);
				change_to_needed($gtreep,$v,$fbp);
				$changed=1;
			}
		}
		my @todolist = keys %todo;
		push @vlist, @todolist;
		$vdone{$v}=1;
	}
	return $changed;
}

#--------------------------------------------------------------------------
#manipulate: single outcomes

sub get_sout_list($$) {
	my ($gtreep,$v)=@_;
	my %olist=();
	if ($$gtreep->has_attribute('sout',$v)==1) {
		$outstr = $$gtreep->get_attribute('sout',$v);
		my @out = split /:/,$outstr;
		shift @out;
		foreach my $o (@out) {
			$olist{$o}=1;
		}
	}
	return %olist;
}

sub add_sout($$$) {
	my ($gtreep,$v,$sout)=@_;
	if ($$gtreep->has_attribute('sout',$v)==0) {
		$$gtreep->set_attribute('sout',$v,":$sout");
		return 1;
	} else {
		my %olist = get_sout_list($gtreep,$v);
		if (exists $olist{$sout}) {
			return 0;
		}
		$olist{$sout}=1;
		my $outstr=" ";
		foreach my $o (keys %olist) {
			$outstr = "$outstr:$o";
		}
		$$gtreep->set_attribute('sout',$v,$outstr);
		return 1;
	}
}

sub valid_other_single($$$) {
	my ($gtreep,$v,$pc)=@_;
	my %slist = get_sout_list($gtreep,$v);
	foreach my $s (keys %slist) {
		if (!($s eq $pc)) {
			return 1;
		}
	}
	return 0;
}


sub valid_this_single($$$) {
	my ($gtreep,$v,$pc)=@_;
	my %slist = get_sout_list($gtreep,$v);
	return 1 if exists $slist{$pc};
	return 0;
}


sub mark_single($) {
	my $gtreep = shift @_;
	print "Entering mark_single \n" if $debug;
	my @vlist = $$gtreep->source_vertices();
	my %vdone=();
	my $changed=0;
	while (@vlist > 0) {
		my $v = shift @vlist;
		#next if $vdone{$v};
		my $vstat = get_status($gtreep,$v);
		if (has_single_child_option($gtreep,$v)==1) {
			my @kids = $$gtreep->successors($v);
			if (is_single($gtreep,$kids[0])==0) {
				$$gtreep->set_attribute('single',$kids[0],1);
				$changed=1;
			}
			if (is_conflict($gtreep,$v)==0) {
				my $sout = get_single_outcome($gtreep,$v);
				next if exists $vdone{$kids[0]}{$sout};
				if (add_sout($gtreep,$kids[0],$sout)==1) {
					print "Marking single: $kids[0] ($sout) \n" if $debug;
				}
				$vdone{$kids[0]}{$sout}=1;
			} else {
				my %slist = get_sout_list($gtreep,$v);
				foreach my $s (keys %slist) {
					next if exists $vdone{$kids[0]}{$s};
					if (add_sout($gtreep,$kids[0],$s)==1) {
						print "Marking single: $kids[0] ($s) \n" if $debug;
					}
					$vdone{$kids[0]}{$s}=1;
				}
			}
			push @vlist, $kids[0];
		}
	}
	return $changed;
}


#--------------------------------------------------------------------------
#manipulate: delete nodes


sub pre_decided($$$$) {
	my ($gtreep,$p,$v,$k)=@_;
	return 0 if $$gtreep->has_attribute('decided',$p,$v)==0;
	return 0 if $$gtreep->has_attribute('decided',$v,$k)==0;
	return 1;
}


#Delete vertex and reconnect all parents and kids
sub delete_node($$) {
	my ($gtreep,$v)=@_;
	print "Entering delete_node: $v \n" if $debug;
	
	my @outcomes=get_outcomes($gtreep,$v);
	foreach my $out (@outcomes) {
		if (exists $poswords{$v}{$out}) {
			delete $poswords{$v}{$out};
		}
		delete $poswords{$v};
	}
	if (exists $mincomp{$v}) {
		foreach my $m (keys %{$mincomp{$v}}) {
			delete $mincomp{$m}{$v};
			delete $mincomp{$v}{$m};
		}
		delete $mincomp{$v};
	}
	
	my %parents = get_next_parents($gtreep,$v);
	my %kids = get_next_kids($gtreep,$v);
	my %predec = ();
	foreach my $p (keys %parents) {
		foreach my $k (keys %kids) {
			$predec{$p}{$k}=pre_decided($gtreep,$p,$v,$k);
		}
	}
	
	$$gtreep->delete_vertex($v);
	print "Deleting node: $v\n" if $debug;
	
	foreach my $p (keys %parents) {
		my @klist = keys %kids;
		#foreach my $m (keys %{$mincomp{$p}}) {
		#	push @klist,$m;
		#}
		my %kdone=();
		while (scalar @klist >0) {
			my $k = shift @klist;
			next if $kdone{$k};
			next if ($p eq $k);
			my $decpat = is_containpat($p,$k);
			#print "HERE $p,$k,$decpat\n";
			if ($decpat==1) {
				if (has_path_of_type($gtreep,$p,$k,'decided')==0) {
					add_edge($gtreep,$p,$k,'decided');
				}
			} elsif ($pre_dec{$p}{$k}==1) {
				add_edge($gtreep,$p,$k,'decided');
			} elsif (is_mincomp($gtreep,$p,$k)==1) {
				fix_mincomp($gtreep,$p,$k);
			} else {
				my %todo = get_next_kids($gtreep,$k);
				foreach my $t (keys %todo) {
					push @klist, $t;
				}
			}
			$kdone{$k}=1;
		}
	}
}

sub delete_if($$) {
	my ($gtreep,$v)=@_;
	if (is_conflict($gtreep,$v)==1) {
		return 0;
	}
	my $vstat = get_status($gtreep,$v);
	if ($vstat eq 'word') {
		return 0;
	}
	my %kids = get_next_kids($gtreep,$v);
	foreach my $kid (keys %kids) {
		if (is_conflict($gtreep,$kid)==1) {
			return 0;
		}
		if (has_same_single_outcome($gtreep,$v,$kid)==0) {
			return 0;
		}
	}
	my @outcomes = get_outcomes($gtreep,$v);
	my $p = pop @outcomes;
	#Use this to keep track of true variants when deleting
	foreach my $k (keys %kids) {
		my @kposwords = keys %{$poswords{$k}{$p}};
		my @vposwords = keys %{$poswords{$v}{$p}};
		my $comp = Array::Compare->new;
		if ($comp->perm(\@kposwords,\@vposwords)) {
			add_variant($k,$v);
		}
	}
	delete_node($gtreep,$v);
	return 1;
}

#--------------------------------------------------------------------------
#manipulate: resolve conflict

sub replace_conflict_lose1($$$$) {
	my ($gtreep,$v,$pc,$fbp)=@_;
	print "Entering replace_conflict_lose1: $v, $pc\n" if $debug;
	my @out = get_outcomes($gtreep,$v);
	my $outstr="";
	if (scalar @out < 2) {
		die "Error: reducing conflict outcomes when already 1 or less [@out]\n";
	} elsif (scalar @out == 2) {
		if ($out[0] eq $pc) {
			$outstr = $out[1];
		} else {
			$outstr = $out[0];
		}
		$$gtreep->set_attribute('out',$v,$outstr);
		$$gtreep->set_attribute('status',$v,'normal');
		delete $fbp->{$v};
	} else {
		%new_out=();
		foreach my $o (@out) {
			if (!($o eq $pc)) {
				$new_out{$o}=1;
			}
		}
		my @new_list = keys %new_out;
		$outstr = join ";",@new_list;
		$$gtreep->set_attribute('out',$v,$outstr);
	}
	#if (exists $poswords{$v}{$pc}) {
	#	%{$poswords{$v}{$pc}}=();
	#}
}


#Replace a conflict node with its equivalent 'best' rule where conflict rule should be kept
sub replace_conflict_win($$$) {
	my ($gtreep,$v,$p)=@_;
	print "Replacing conflict: $v -> $p\n" if $debug;
	$$gtreep->set_attribute('status',$v,'normal');
	$$gtreep->set_attribute('out',$v,"$p");
}


sub replace_conflict_lose($$) {
	my ($gtreep,$v)=@_;
	print "Replacing conflict: deleting $v \n" if $debug;
	#Remember to still add to variants! Do later...
	delete_node($gtreep,$v);
}

sub resolve_conflict_root($$) {
	my ($gtreep,$v)=@_;
	my %inlist = get_next_parents($gtreep,$v);
	my %ptot=();
	my @outcomes = get_outcomes($gtreep,$v);
	foreach my $o (@outcomes) {
		$olist{$o}=1;
	}
	foreach my $i (keys %inlist) {
		return 0 if is_conflict($gtreep,$i)==1;
		my @pi = get_outcomes($gtreep,$i);
		if (exists $olist{$pi[0]}) {
			$ptot{$pi[0]}++;
		}
	}
	my $pmax = "";
	my $totmax = 0;
	foreach my $pi (keys %ptot) {
		if ($ptot{$pi}>$totmax) {
			$totmax=$ptot{$pi};
			$pmax=$pi;
		}
	}
	replace_conflict_win($gtreep,$v,$pmax);
	return 1;
}

#--------------------------------------------------------------------------
# Allowed operations
#--------------------------------------------------------------------------

#allowed_ops: remove redundant edges

sub remove_redundant_edges_nodelist($$\%) {
	my ($nop,$gtreep,$wlp) = @_;
	print "Entering remove_redundant_edges_nodelist\n" if $debug;
	my $changed=0;
	my @vlist = keys %$wlp;
	my %vdone=();
	while ( scalar @vlist>=1) {
		my $v = shift @vlist;
		next if exists $vdone{$v};
		my $vstat = get_status($gtreep,$v);
		my %vhash = get_immediate_kids($gtreep,$v,"decided");
		my @vkids = keys %vhash;
		foreach my $ki (0..$#vkids) {
			my @vj_list=();
			foreach my $kj (0..$#vkids) {
				next if $ki eq $kj;
				if (has_path_of_type($gtreep,$vkids[$ki],$vkids[$kj],"decided")==1) {
					print "Removing unnecessary edge: $v -> $vkids[$kj]\n" if $debug;
					$$gtreep->delete_edge($v,$vkids[$kj]);
					$changed=1;
				}
			}
		}
		push @vlist,@vkids;
		$vdone{$v}=1;
	}
	return $changed;
}


sub remove_redundant_edges($$) {
	my ($nop,$gtreep) = @_;
	print "Entering remove_redundant_edges\n" if $debug;
	my $changed=0;
	my @vlist = $$gtreep->vertices_unsorted();
	foreach my $v (@vlist) {
		my $vstat = get_status($gtreep,$v);
		#next if ($vstat eq 'word');
		my %vhash = get_immediate_kids($gtreep,$v,"decided_possible1");
		my @vkids = keys %vhash;
		foreach my $ki (0..$#vkids) {
			my @vj_list=();
			foreach my $kj (0..$#vkids) {
				next if $ki eq $kj;
				my $match_all=1;
				@vj_list=($vkids[$kj]);
				foreach my $k (@vj_list) {
					if (has_path_of_type($gtreep,$vkids[$ki],$k,"decided_possible1")!=1) {
						$match_all=0;
						last;
					}
				}
				if ($match_all==1) {
					print "Removing unnecessary edge: $v -> $vkids[$kj]\n";
					$$gtreep->delete_edge($v,$vkids[$kj]);
					$changed=1;
				}
			}
		}
	}
	return $changed;
}


#--------------------------------------------------------------------------

#allowed_ops: preparing to resolve

sub has_def_replacement($$) {
	my ($gtreep,$v)=@_;
	return 0 if (is_conflict($gtreep,$v)==1);
	#return 0 if (is_single($gtreep,$v)==0);
	
	my %kids = get_immediate_kids($gtreep,$v,'decided');
	foreach my $k (keys %kids) {
		if ((is_single($gtreep,$k)==1)&&(is_conflict($gtreep,$k)==0)) {
			my $kout = get_single_outcome($gtreep,$k);
			my $vout = get_single_outcome($gtreep,$v);
			if ($vout eq $kout) {
				return 1;
			}
		}
	}
	return 0;
}


sub get_set_name($\%\%) {
	my ($gtreep,$setp,$wp)=@_;
	my @wlist = keys %$wp;
	foreach my $setnum (keys %$setp) {
		my %cmpset = %{$setp->{$setnum}};
		next if scalar @wlist != scalar (keys %cmpset);
		my $match = 1;
		foreach my $w (@wlist) {
			if (!(exists $cmpset{$w})) {
				$match=0;
				last;
			}
		}
		if ($match==1) {
			return $setnum;
		}
	}
	$newsetnum = (scalar keys %$setp)+1;
	foreach my $w (@wlist) {
		$setp->{$newsetnum}{$w}=1;
	}
	return $newsetnum;
}


sub set_contain(\%\%) {
	my ($lp1,$lp2)=@_;
	foreach my $i (keys %{$lp2}) {
		if (!(exists $lp1->{$i})) {
			return 0;
		}
	}
	return 1;
}


#Number of word sets (rules) that will definitely be replaced by $v1 if $v1 resolved to $p, for each possible $p
#Number of word sets (rules) that will possibly, but not definitely, replaced by $v1 if $v1 resolved to $p, for each possible $p
#Updates posp->{$p}{$setname}
#Updates defp->{$p}{$setname}
sub get_replace_cnt($$\%\%\%\%) {
	my ($gtreep,$v1,$setp,$posp,$defp,$allp) =@_;
	%{$posp}=();
	%{$defp}=();
	my %parents = get_next_parents($gtreep,$v1);
	foreach my $parent (keys %parents) {
		my %rwords =  get_correct_words($gtreep,$parent);
		foreach my $w (keys %rwords) {
			if (is_match($w,$v1)==0) {
				delete $rwords{$w};
			}
			my $wout = get_single_outcome($gtreep,$w);
			if (is_outcome_in_node($gtreep,$wout,$v1)==0) {
				delete $rwords{$w};
			}
		}
		my %tmpset=();
		foreach my $w (keys %rwords) {
			my $wout = get_single_outcome($gtreep,$w);
			$tmpset{$wout}{$w}=1;
		}
		
		my @out = get_outcomes($gtreep,$parent);
		if (($$gtreep->has_attribute('decided',$parent,$v1)==1)
			&&(is_single($gtreep,$parent)==1)&&(has_single_child_option($gtreep,$parent)==1)&&(is_conflict($gtreep,$parent)==0)) {
			my $p = $out[0];
			my $setname = get_set_name($gtreep,%{$setp},%rwords);
			${$defp->{$p}}{$setname}++;
			${$allp->{$p}}{$setname}++;
		} else {
			if ($$gtreep->has_attribute('possible1',$parent,$v1)==0) {
				#possible1 always order_req - not counted
				foreach my $p (@out) {
					if (exists $tmpset{$p}) {
						my %tmpwords = %{$tmpset{$p}};
						my $setname = get_set_name($gtreep,%{$setp},%tmpwords);
						#if (has_def_replacement($gtreep,$parent)==0) {
							${$posp->{$p}}{$setname}++;
							${$allp->{$p}}{$setname}++;
						#}
					}
				}
			}
		}
	}
	my %redlist=();
	foreach my $o (keys %{$posp}) {
		my @setlist=();
		push @setlist, keys %{$posp->{$o}};
		foreach my $i (0..$#setlist-1) {
			foreach my $j (1..$#setlist) {
				my $cmpval = set_contain(%{$setp->{$setlist[$i]}},%{$setp->{$setlist[$j]}});
				if ($cmpval==1) {
					delete $posp->{$o}{$setlist[$j]};
					delete $allp->{$o}{$setlist[$j]};
				}
				$cmpval = set_contain(%{$setp->{$setlist[$j]}},%{$setp->{$setlist[$i]}});
				if ($cmpval==1) {
					delete $posp->{$o}{$setlist[$i]};
					delete $allp->{$o}{$setlist[$i]};
				}
			}
		}
	}
}


sub def_and_pos_leq_1(\%) {
	my ($allcntp)= shift @_;
	foreach my $p (keys %$allcntp) {
		my @setlist = keys %{$allcntp->{$p}};
		if (scalar @setlist > 1) {
			return 0;
		}
	}
	return 1;
}


sub def_clear_win(\%\%\%$) {
	my ($poscntp,$defcntp,$allcntp,$pcp)=@_;

	my @deflist = keys %$defcntp;
	if (scalar @deflist < 1) {
		return 0;
	}
	my $winner;
	foreach my $pc (keys %{$defcntp}) {
		my $setcnt_target = scalar keys %{$defcntp->{$pc}};
		next if ($setcnt_target <= 1);
		$winner=1;
		foreach my $pc2 (keys %{$allcntp}) {
			next if $pc eq $pc2;
			my $setcnt_cmp = scalar keys %{$allcntp->{$pc2}};
			if ($setcnt_cmp>$setcnt_target) {
				$winner=0;
				last;
			} 
		}
		if ($winner==1) {
			$settot = $setcnt_target;
			$maxp=$pc;
			last;
		}
	}
	$$pcp = $maxp;
	return $winner;
}

sub def_and_pos_lose_1($$\%$) {
	my ($gtreep,$v,$allcntp,$pcp)=@_;
	my @outlist = get_outcomes($gtreep,$v);
	my %olist=();
	foreach my $o (@outlist) {
		$olist{$o}=1;
	}
	foreach my $p (keys %$allcntp) {
		next if !(exists $olist{$p});
		my @setlist = keys %{$allcntp->{$p}};
		if (scalar @setlist <= 1) {
			if (valid_other_single($gtreep,$v,$p)==1) {
				$$pcp = $p;
				return 1;
			}
		}
	}
	return 0;
}


#--------------------------------------------------------------------------
# allowed_ops: resolving

#Remove conflict nodes that do not contribute, irrespective of choice
#Resolve conflict where parents all agree
#Resolve conflict nodes that provide definite win, even if parents don't all agree
sub resolve_conflict_definite($$\%) {
	my ($nop,$gtreep,$fbp) = @_;
	print "Entering resolve_conflict_definite \n" if $debug;
	my @vlist = keys %{$fbp};
	my %vdone=();
	my $changed=0;
	my $info="";
	#Can actually just run through vlist - change later if no ordering according to which fallback resolved
	while ((scalar @vlist)>0) {
		my $v = shift @vlist;
		next if $vdone{$v};
		next if is_conflict($gtreep,$v)==0;
		
		#print "Considering $v\n" if $debug;
		#my %kids = get_immediate_kids($gtreep,$v,'decided');
		my $pc="";
		my $changedv=0;
		my %poscnt=();
		my %defcnt=();
		my %allcnt=();
		my %cmpset=();	
		get_replace_cnt($gtreep,$v,%cmpset,%poscnt,%defcnt,%allcnt);
		my %parents = get_next_parents($gtreep,$v);
		if (def_and_pos_leq_1(%allcnt)==1) {
			if ($$gtreep->is_sink_vertex($v)) {
				$changedv = resolve_conflict_root($gtreep,$v);
				if ($changedv==1) {
					delete $fbp->{$v};
					$info="conflict lost - root";
				}
			} else {
				replace_conflict_lose($gtreep,$v);
				delete $fbp->{$v};
				$changedv=1;
				$info="conflict lost";
			}
		} elsif (def_clear_win(%poscnt,%defcnt,%allcnt,\$pc)==1) {
			if (valid_this_single($gtreep,$v,$pc)==1) {
				replace_conflict_win($gtreep,$v,$pc);
				fix_mincomp_one($gtreep,$v);
				delete $fbp->{$v};
				$changedv=1;
				$info="conflict won";
			}
		} else {
			#if ($$gtreep->is_sink_vertex($v)) {
			#	#resolve_conflict_root($gtreep,$v);
			#} else {
				my @outs = get_outcomes($gtreep,$v);
				foreach my $out (@outs) {
					if ((def_and_pos_lose_1($gtreep,$v,%allcnt,\$pc)==1)&&(is_single($gtreep,$v)==1)) {
						replace_conflict_lose1($gtreep,$v,$pc,$fbp);
						$info="removed 1 option";
						fix_mincomp_one($gtreep,$v);
						$changedv=1;
						foreach my $setname (keys %{$allcnt{$pc}}) {
							delete $allcnt{$pc}{$setname};
							if (exists $defcnt{$pc}{$setname}) {
							    delete $defcnt{$pc}{$setname};
							}
							if (exists $poscnt{$pc}{$setname}) {
							    delete $poscnt{$pc}{$setname};
							}
						}
					}
					delete $allcnt{$pc};
					delete $defcnt{$pc};
					delete $poscnt{$pc};
					
				}
			#}
		}
		
		if ($changedv==1) {
			#my %updatelist=();
			#my $needed_update=0;
			#my @dolist = keys %parents;
			#my %pdone=();
			#while (scalar @dolist > 0) {
			#	my $p = shift @dolist;
			#	next if $pdone{$p};
			#	my %newpar = get_next_parents($gtreep,$v);
			#	if (delete_if($gtreep,$p)==0) {
			#		if (mark_necessary_if($gtreep,$p,$fbp)==1) {
			#			$updatelist{$p}=1;
			#			$needed_update=1;
			#		}
			#	} else {
			#		foreach my $np (keys %newpar) {
			#			push @dolist,$np;
			#		}
			#	}
			#	$pdone{$p}=1;
			#}
	
					
			#remove_redundant_edges_nodelist($nop,$gtreep,%updatelist);
			#my @warray = $$gtreep->source_vertices();
			#foreach my $w (@warray) {
			#	$wlist{$w}=1;
			#}
			#my @allarray = $$gtreep->vertices_unsorted();
			#foreach my $a (@allarray) {
			#	$alist{$a}=1;
			#}
			#
			#mark_needed($gtreep,$fbp);
			#fix_mincomp_nodeslist($gtreep,%alist);
			#remove_redundant_edges_nodelist($nop,$gtreep,%wlist);
			#trim_tree_normal_agree($nop,$gtreep);
			#mark_single($gtreep);
		}
		
		if ($changedv==1) {
			#foreach my $k (keys %kids) {
			#	if (is_conflict($gtreep,$k)==1) {
			#		$fbsrcp->{$k}=1;
			#		push @vlist,$k;
			#	}
			#}
			do_draw_tree($nop,$gtreep,"internal: 1 conflict node resolved - $v ($info)");
			print "Resolved: $v\n" if $msg;
			$changedv=0;
			$changed=1;
		}	
		$vdone{$v}=1;
	}
	return $changed;
}


#--------------------------------------------------------------------------

#allowed_ops: remove unnecessary patterns from tree
# (remove parent where parent agrees with all kids) <-prev
# (remove parent when all kids are resolved, and at least one agrees) <-new
sub trim_tree_normal_agree($$) {
	my ($nop,$gtreep) = @_;
	print "Entering trim_tree_normal_agree \n" if $debug;
	my @vlist = $$gtreep->source_vertices();
	my %vdone=();
	my $changed=0;
	while ((scalar @vlist)>0) {
		my $v = shift @vlist;
		next if $vdone{$v};
		#print "Considering $v\n" if $debug;
		my $keep=0;
		my $kstat = get_status($gtreep,$v);
		
		#agreecomp will always agree - don't have to consider explicitly
		my %kids = get_next_kids($gtreep,$v);
		if (is_conflict($gtreep,$v)==1) {
			$keep=1;
		} elsif ($kstat eq 'word') {
			$keep=1;
		} elsif ($$gtreep->is_sink_vertex($v)==1) {
			$keep=1;
		} else {
			foreach my $kid (keys %kids) {
				if (is_conflict($gtreep,$kid)==1) {
					$keep=1;
					last;
				}
				if (has_noconflict_path_first_agree($gtreep,$v,$kid)==0) {
					$keep=1;
					last;
				}
			}
		}
	
		if ($keep==0) {
			my $p = get_single_outcome($gtreep,$v);
			#Use this to keep track of true variants when deleting
			#Change to use set_contain when checking variant code
			foreach my $k (keys %kids) {
				my @kposwords = keys %{$poswords{$k}{$p}};
				my @vposwords = keys %{$poswords{$v}{$p}};
				my $comp = Array::Compare->new;
				if ($comp->perm(\@kposwords,\@vposwords)) {
					add_variant($k,$v);
				}
			}
			delete_node($gtreep,$v);
			$changed=1;
			#do_draw_tree($nop,$gtreep,"Trimming...[$v]");
		}	
		foreach my $t (keys %kids) {
			push @vlist,$t;
		}
		$vdone{$v}=1;
	}
	return $changed;
}

#--------------------------------------------------------------------------

# allowed_ops: combine variants

sub add_variant($$) {
	my ($v,$c)=@_;
	$variants{$v}{$c}=1;
	if (exists $variants{$c}) {
		foreach my $prev_var (keys %{$variants{$c}}) {
			$variants{$v}{$prev_var}=1;
		}
	}
}


sub trim_tree_variants_combine($$\%) {
	my ($nop,$gtreep,$fbp) = @_;
	print "Entering trim_tree_variants_combine \n" if $debug;
	my $changed=0;
	my %vdone=();
	my @vlist = $$gtreep->vertices_unsorted();
	foreach my $v (@vlist) {
		next if exists $vdone{$v};
		next if is_conflict($gtreep,$v)==1;
		#my %kids = get_immediate_kids($gtreep,$v,'possible2');
		my @kidlist=();
		if (exists $mincomp{$v}) {
			my %kids = %{$mincomp{$v}};
			@kidlist = keys %kids;
		}
		next if (@kidlist==0);
		foreach my $k (@kidlist) {
			#print "Considering $v to $k\n";
			next if is_conflict($gtreep,$k)==1;
			if (have_identical_children($gtreep,$v,$k,'decided_possible1')==1) {
				if (have_identical_parents($gtreep,$v,$k,'decided_possible1')==1) {
					if (have_identical_siblings($gtreep,$v,$k,'possible2')==1) {
						print "Variants: [$v] now includes [$k]\n";
						add_variant($v,$k);
						delete_node($gtreep,$k);
						$vdone{$k}=1;
						$changed=1;
					}
				}
			} 
		}
		$vdone{$v}=1;
	}
	
	#if ($changed==1) {
	#	my @warray = $$gtreep->source_vertices();
	#	foreach my $w (@warray) {
	#		$wlist{$w}=1;
	#	}
	#	my @allarray = $$gtreep->vertices_unsorted();
	#	foreach my $a (@allarray) {
	#		$alist{$a}=1;
	#	}
	#	mark_needed($gtreep,$fbp);
	#	fix_mincomp_nodeslist($gtreep,%alist);
	#	remove_redundant_edges_nodelist($nop,$gtreep,%wlist);
	#	trim_tree_normal_agree($nop,$gtreep);
	#	mark_single($gtreep);
	#}
	return $changed;
}

#--------------------------------------------------------------------------

# allowed_ops: removing double paths: not used! (rather change replace_cnt)

sub rm_dpaths($$$) {
	my ($gtreep,$w,$v)=@_;
	my %kids = get_immediate_kids($gtreep,$w,'decided');
	my $changed=0;
	foreach my $k (keys %kids) {
		if (!($k eq $v)) {
			$$gtreep->delete_edge($w,$k);
			$changed=1;
		}
	}
	return $changed;
}


sub trim_tree_rm_dpaths_definite($$) {
	my ($nop,$gtreep)= @_;
	print "Entering trim_tree_rm_dpaths_definite \n" if $debug;
	my @vlist = $$gtreep->vertices_unsorted();
	my $changed=0;
	my %vdone=();
	my $keep=0;
	foreach my $v (@vlist) {
		next if exists $vdone{$v};
		next if (is_single($gtreep,$v)==0);
		my %parents = get_immediate_parents($gtreep,$v,'decided1');
		foreach my $p (keys %parents) {
			my $pstat = get_status($gtreep,$p);
			if ($pstat eq 'word') {
				if (rm_dpaths($gtreep,$p,$v)==1) {
					$changed=1;
				}
			}
		}
		$vdone{$v}=1;
	}
	return $changed;
}


#--------------------------------------------------------------------------
# Report on rule set status
#--------------------------------------------------------------------------

sub count_rules($) {
	my ($gtreep) = @_;
	my @vlist = $$gtreep->vertices_unsorted();
	my $rulecnt=0;
	foreach my $v (@vlist) {
		my $vstat = get_status($gtreep,$v);
		next if $vstat eq 'word';
		$rulecnt++;
	}
	return $rulecnt;
}


#Write rules in order based on current tree
#Also write to <fname> in olist format
sub traverse_rules($$) {
	my ($gtreep,$fname) = @_;
	print "Entering write_top_tree \n" if $debug;		
	my @vlist=$$gtreep->toposort();
	my $i=1;
	my @rlist=();
	foreach my $v (@vlist) {
		my $vstat = get_status($gtreep,$v);
		my $vout = get_single_outcome($gtreep,$v);
		next if $vstat eq 'word';
		#next if $vstat eq 'off';
		print "[$i] $v";
		if (exists $variants{$v}) {
			my @varlist = keys %{$variants{$v}};
			print "( @varlist )"
		}
		print " -> $vout\n";
		$i++;
		unshift @rlist,$v;
	}
	
	open OH, ">:encoding(utf8)", "$fname" or die "Error opening $fname\n";
	$i=0;
	foreach my $r (@rlist) {
		my $vout = get_single_outcome($gtreep,$r);
		$r =~ /(.*)-(.)-(.*)/;
		print OH "$2;$1;$3;$vout;$i\n";
		$i++;
	}
	close OH;
}


#--------------------------------------------------------------------------
# Main Functions - level 2
#--------------------------------------------------------------------------

sub minimise_tree($\%$) {
	my ($gtreep,$fbp,$nop)=@_;
	my ($changed1,$changed2,$changed3,$changed4,$changed5,$changed6,$changed7,$changed8,$changed9)=(0,0,0,0,0,0,0,0,0);
	my $busy=1;
	while ($busy==1) {
		
		$changed1 = mark_needed($gtreep,$fbp);
		if ($changed1==1) {
			do_draw_tree($nop,$gtreep,'Needed rules marked');
		#	#traverse_rules($gtreep);
		}

		my @allarray = $$gtreep->vertices_unsorted();
		foreach my $a (@allarray) {
			$alist{$a}=1;
		}
		$changed2 = fix_mincomp_nodeslist($gtreep,%alist);
		if ($changed2==1) {
			do_draw_tree($nop,$gtreep,'supercomp relations and order_req identified');
		#	#traverse_rules($gtreep);
		}

		my @warray = $$gtreep->source_vertices();
		foreach my $w (@warray) {
			$wlist{$w}=1;
		}
		$changed3 = remove_redundant_edges_nodelist($nop,$gtreep,%wlist);
		if ($changed3==1) {
			do_draw_tree($nop,$gtreep,'redundant edges removed');
		#	#traverse_rules($gtreep);
		}

		$changed4 = trim_tree_normal_agree($nop,$gtreep);
		if ($changed4==1) {
			do_draw_tree($nop,$gtreep,'leaves trimmed');
			#traverse_rules($gtreep);
		} 

		if ((scalar keys %$fbp)>=1) {
			$changed5 = mark_single($gtreep);
		} else {
			$changed5=0;
		}
		if ($changed5==1) {
			do_draw_tree($nop,$gtreep,'singles marked');
		#	#traverse_rules($gtreep);
		}

		if ((scalar keys %$fbp)>=1) {
			$changed6 = resolve_conflict_definite($nop,$gtreep,%$fbp);
		} else {
			$changed6=0;
		}
		if ($changed6==1) {
			#do_draw_tree($nop,$gtreep,'deterministic conflict resolved');
			#traverse_rules($gtreep,%$gcntp);
		} 

		$changed7 = trim_tree_variants_combine($nop,$gtreep,%$fbp);
		if ($changed7==1) {
			do_draw_tree($nop,$gtreep,'Variant rules combined');
			#traverse_rules($gtreep,%$gcntp);
		}
				
		#$changed5 = trim_tree_rm_dpaths_definite($nop,$gtreep);
		#if ($changed5==1) {
		#	do_draw_tree($nop,$gtreep,'deterministic double paths removed');
		#	#traverse_rules($gtreep,%$gcntp);
		#}
		
		#$changed8 = add_order_req($nop,$gtreep);
		#if ($changed8==1) {
		#	do_draw_tree($nop,$gtreep,'deterministic conflict resolved');
		#	#traverse_rules($gtreep,%$gcntp);
		#}
		
		#$changed2 = identify_supercomps($nop,$gtreep);
		#if ($changed2==1) {
		#	do_draw_tree($nop,$gtreep,'supercomp relations identified');
		#	#traverse_rules($gtreep);
		#}
		#
		
		$busy=($changed1||$changed2||$changed3||$changed4||$changed5||$changed6||$changed7||$changed8||$changed9);
	}
}

#--------------------------------------------------------------------------

#csp-based

sub add_solutions(\@\@) {
	my ($vlp,$plp)=@_;
	my @newlist=();
	foreach my $v (@$vlp) {
		foreach my $p (@$plp) {
			push @newlist, "$v$p";
		}
	}
	@$vlp = @newlist;
}


sub solve_tree($\@$) {
	my ($gtreep,$varp,$sol)=@_;
	@slist = split //,$sol;
	foreach my $i (0..$#$varp) {
		my $vi = $varp->[$i];
		my $si = $slist[$i];		
		if ($si eq "-") {
			replace_conflict_lose($gtreep,$vi);
		} else {
			replace_conflict_win($gtreep,$vi,$si);
		}
		#$no++;
		#draw_tree($gtreep,"Solving... $vi = $si","tree_$no.jpg");
	}
}

sub do_csp($\%$$) {
	my ($gtreep,$fbp,$nop,$rfn) = @_;
	
	my @fb_id=(); #As array to keep order - necessaray for conflict resolution when solving csp
	my %fb_val=();
	my %fb_done=();
	
	my @vlist = keys %$fbp;
	while (scalar @vlist>0) {
		my $v = shift @vlist;
		next if $fb_done{$v};
		my @plist = get_outcomes($gtreep,$v);
		push @fb_id,$v;
		if ($v !~ /^-.-$/) {
			push @plist,'-';
		}
		@{$fb_val{$v}} = @plist;
		$fb_done{$v}=1;
		my %kids = get_next_kids($gtreep,$v);
		foreach my $k (keys %kids) {
			if (is_conflict($gtreep,$k)==1) {
				push @vlist, $k;
			}
		}
	}
		
	print "Searching solution set for: @fb_id\n";
	foreach my $f (@fb_id) {
		print "$f: @{$fb_val{$f}}\n";
	}
	
	foreach my $i (0..$#fb_id) {
		$fb_key[$i]=0;
	}
	
	#my $besttree;
	my $min_rules=900000;
	my $best_sol="";
	my $best_var="";
	
	my %minlist=();
	my %newpos=();
	my %newmin=();
	my %newvar=();
	copy_var_to(%newpos,%newmin,%newvar);
	my $busy=1;
	
	while ($busy==1) {
		$busy=0;
		my $s="";
		foreach my $i (0..$#fb_id) {
			my $v = $fb_id[$i];
			my $vkey = $fb_key[$i];
			$s = $s.${$fb_val{$v}}[$vkey];
		}
		foreach my $i (0..$#fb_id) {
			my $v = $fb_id[$i];
			if ($fb_key[$i]<$#{$fb_val{$v}}) {
				$fb_key[$i]++;
				if ($i>0) {
					foreach my $j (0..$i-1) {
						$fb_key[$j]=0;
					}
				}
				$busy=1;
				last;
			}
		}
		print "-------------> Testing $s\n";
		my $ctree = $$gtreep->copy();
		copy_attrib_tree($gtreep,\$ctree);
		copy_var_from(%newpos,%newmin,%newvar);	
		solve_tree(\$ctree,@fb_id,$s);
		#$$nop++;
		#draw_tree(\$ctree,'Solved, not minimised',"tree_$$nop.jpg");
		my %new_fb=();
		minimise_tree(\$ctree,%new_fb,$nop);
		
		#final tweaking
		#my $busy=1;
		#$no=300;
		#while ($busy==1) {
		#	my $changed = trim_tree_sets_combine(\$ctree,%$gcntp);
		#	#my $changed = 0;
		#	if ($changed==1) {
		#		do_draw_tree(\$no,$ctree,'Set comparison - variants removed');
			#		#traverse_rules($gtreep,%$gcntp);
		#	}
		#	$busy=$changed;
		#}
		
		#if ($res>=0) {
			my $rulecnt = count_rules(\$ctree);
			print "Rules:\t$rulecnt\n"; # [$var variation(s)]\n";
			if ($rulecnt<$min_rules) {
				$min_rules=$rulecnt;
				$best_sol=$s;
				$$bestp = $ctree->copy();
				copy_attrib_tree(\$ctree,$bestp);
				$minlist{$min_rules}{$best_sol}=1;
			} elsif ($rulecnt==$min_rules) {
				$minlist{$rulecnt}{$s}=1;
			}
		#}
	}
	
	do_draw_tree(\$no,$bestp,'Best tree!');
	print "Minimum rules: $min_rules (solution $best_sol)\n"; #[$best_var variation(s)]\n";
	my @sollist=keys %{$minlist{$min_rules}};
	print "All min solutions: @sollist\n";	
	traverse_rules($bestp,$rfn);
}

#--------------------------------------------------------------------------

# backtrack-based

sub get_worst_conflict($\%) {
	my ($gtreep,$fbp)=@_;
	my $wtype = "first";
	
	my @vlist = keys %{$fbp};
	if ($wtype eq 'first') {
		my $v = pop @vlist;
		return $v;
	} else {
		my %vdone=();
		my $max=0;
		my $worst;
		while (scalar @vlist >0) {
			my $v = shift @vlist;
			next if $vdone{$v};
			next if (is_conflict($gtreep,$v)==0);
			my %in = get_next_parents($gtreep,$v);
			my @inlist = keys %in;
			if (scalar @inlist > $max) {
				$max = scalar @inlist;
				$worst = $v;
			}
			my %out = get_next_kids($gtreep,$v);
			my @todo = keys %out;
			push @vlist,@todo;
			$vdone{$v}=1;
		}
		return $worst;
	}
}

sub copy_var_to(\%\%\%) {
	my ($posp,$minp,$varp)=@_;
	%$posp=();
	foreach my $v (keys %poswords) {
		foreach my $out (keys %{$poswords{$v}}) {
			foreach my $w (keys %{$poswords{$v}{$out}}) {
				$posp->{$v}{$out}{"$w"}=1;
			}
		}
	}
	%$minp=();
	foreach my $v (keys %mincomp) {
		foreach my $m (keys %{$mincomp{$v}}) {
			$minp->{$v}{$m}=1;
		}
	}
	%$varp=();
	foreach my $v (keys %variants) {
		foreach my $c (keys %{$variants{$v}}) {
			$varp->{$v}{$c}=1;
		}
	}
}


sub copy_var_from(\%\%\%) {
	my ($posp,$minp,$varp)=@_;
	%poswords=();
	foreach my $v (keys %$posp) {
		foreach my $out (keys %{$posp->{$v}}) {
			foreach my $w (keys %{$posp->{$v}{$out}}) {
				$poswords{$v}{$out}{"$w"}=1;
			}
		}
	}
	%mincomp=();
	foreach my $v (keys %$minp) {
		foreach my $m (keys %{$minp->{$v}}) {
			$mincomp{$v}{$m}=1;
		}
	}
	%variants=();
	foreach my $v (keys %$varp) {
		foreach my $c (keys %{$varp->{$v}}) {
			$variants{$v}{$c}=1;
		}
	}	
}

sub backtrack_recurse($$$$\%) {
	my ($gtreep,$nop,$min_rules,$bestp,$minlistp)=@_;
	get_conflict($gtreep,%fb);	
	my $next = get_worst_conflict($gtreep,%fb);
	my @out = get_outcomes($gtreep,$next);
	unshift @out,'-';
	my %newpos=();
	my %newmin=();
	my %newvar=();
	copy_var_to(%newpos,%newmin,%newvar);
	foreach my $o (@out) {
		print "-------------> Testing $next as $o\n";
		my $ctree = $$gtreep->copy();
		copy_attrib_tree($gtreep,\$ctree);
		copy_var_from(%newpos,%newmin,%newvar);
		if ($o eq '-') {
			replace_conflict_lose(\$ctree,$next);
			delete $fb{$next};
		} else {
			replace_conflict_win(\$ctree,$next,$o);
			delete $fb{$next};
		}
		do_draw_tree($nop,\$ctree,'About to minimise again...');
		get_conflict(\$ctree,%fb);
		minimise_tree(\$ctree,%fb,$nop);
		get_conflict(\$ctree,%fb);	
		my @numfb = keys %fb;
		if (scalar @numfb <=0) { 
			my $rulecnt = count_rules(\$ctree);
			print "Rules:\t$rulecnt\n"; # [$var variation(s)]\n";
			if ($rulecnt<$min_rules) {
				$min_rules=$rulecnt;
				$best_sol="$next as $o";
				$$bestp = $ctree->copy();
				copy_attrib_tree(\$ctree,$bestp);
				$minlistp->{$min_rules}{$best_sol}=1;
			} elsif ($rulecnt==$min_rules) {
				$minlistp->{$rulecnt}{"$next as $o"}=1;
			}
		} else {
			my $numconf = scalar @numfb;
			print "About to recurse: \trulemin = $min_rules \tconflicted = $numconf\n"; # [$var variation(s)]\n";
			backtrack_recurse(\$ctree,$nop,$min_rules,$bestp,$minlistp);
		}
	}
}


sub do_backtrack($\%$$$) {
	my ($gtreep,$fbp,$nop,$min_rules,$rfn) = @_;	
	my $besttree = Graph->new();
	my %minlist = ();
	backtrack_recurse($gtreep,$nop,$min_rules,\$besttree,%$minlist);
	do_draw_tree($nop,\$besttree,'Best tree!');
	print "Minimum rules: $min_rules\n"; 
	my @sollist=keys %{$minlist{$min_rules}};
	print "All min solutions: @sollist\n";	
	traverse_rules(\$besttree,$rfn);
}


#--------------------------------------------------------------------------
# Main Functions - level 1
#--------------------------------------------------------------------------

sub solve_csp($\%) {
	my ($gtreep,$gcntp)=@_;
	#$no++;
	#draw_tree($gtreep,'initial',1,"tree_$no.jpg");
	#add_mincomp($gtreep);
	#do_draw_tree(\$no,$gtreep,'conflicted nodes combined');
	#
	#my %fallback=();
	#get_conflict($gtreep,%fallback);
	#my $res = minimise_tree($gtreep,%fallback,\$no);
	#do_draw_tree(\$no,$gtreep,'Minimised tree');
		
	my @fb_list = keys %fallback;
	my $searched=0;
	if (scalar @fb_list > 0) {
		my $besttree = Graph->new();
		do_csp($gtreep,%fallback,\$no,"dummy");
		#do_backtrack($gtreep,%fbsrc,\$no,\$besttree);
		$searched=1;
	}
		
	if ($searched==0) {
		#traverse_rules($gtreep);
	}
}


sub solve_analytical($\%$) {
	my ($gtreep,$gcntp,$nop)=@_;
	
	do_draw_tree($nop,$gtreep,'initial tree');
	
	print "Tree initialising... \n" if $msg;
	add_init_orderings($gtreep);	
	do_draw_tree($nop,$gtreep,'aditional orderings added');
	
	#trim_tree_normal_agree($nop,$gtreep);
	#do_draw_tree($nop,$gtreep,'leaves trimmed');
	#
	#my @vlist = $$gtreep->source_vertices();
	#my %wlist=();
	#foreach my $v (@vlist) {
	#	$wlist{$v}=1;
	#}
	#remove_redundant_edges_nodelist(\$no,$gtreep,%wlist);
	#do_draw_tree($nop,$gtreep,'redundant edges removed');
	#
	#trim_tree_normal_agree($nop,$gtreep);
	#do_draw_tree($nop,$gtreep,'leaves trimmed');
	#
	##mark_complete_upto($gtreep);
	#mark_single($gtreep);
	#do_draw_tree($nop,$gtreep,'Singles marked');	
	
	my %fallback=();
	get_conflict($gtreep,%fallback);
	print "Tree minimising... \n" if $msg;
	my $res = minimise_tree($gtreep,%fallback,$nop);
	do_draw_tree($nop,$gtreep,'Minimised tree');
	
	#$no++;
	#draw_tree($gtreep,'Minimised tree',1,"tree_$no.jpg");
	#my $var=0;
	#my $rulecnt = count_rules($gtreep);
	#print "Rules: $rulecnt [$var variation(s)]\n";
	
	#restrict1_tree($g,\$gtree,%gcnt); #won't inflence num of rules, but accuracy for unseen
	#$no++;
	#draw_tree(\$gtree,'Additional ordering added',"tree_$no.jpg");
	my @numleft = keys %fallback;
	return scalar @numleft;
}

#--------------------------------------------------------------------------
# Main Function - level 0
#--------------------------------------------------------------------------

sub fbuild_tree($$$) {
	my ($g,$pattsfile,$rfn)=@_;
	print "Entering build_tree: [$g][$pattsfile][$rfn]\n" if $debug; 
	my $gtree = Graph->new();
	$gtree->directed(1);
	my %gcnt=();
	my $no=0;
	my $cnt=0;
	if (-e $pattsfile) {
		$cnt=fread_gpatts_tree($g,$pattsfile,\$gtree);
		my $tmpFH=select (STDOUT);
		$|=1;
		select($tmpFH);
	}
	if ($cnt==0) {
		open OH, ">:encoding(utf8)", "$rfn" or die "Error opening $rfn\n";
		print OH "$g;;;0;0\n";
		close OH;
	} else {
		my $res = solve_analytical(\$gtree,%gcnt,\$no);
		#solve_csp(\$gtree,%gcnt);
		if ($res == 0) {
			traverse_rules(\$gtree,$rfn);
		} else {
			print "Not all conflict rules resolved yet - starting csp... \n";
			my %fallback=();
			get_conflict(\$gtree,%fallback);
			do_csp(\$gtree,%fallback,\$no,$rfn);
			#do_backtrack(\$gtree,%fallback,\$no,1000,$rfn);
		}
	}
}


#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

