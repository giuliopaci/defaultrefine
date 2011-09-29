
package GTree;
use strict;

use GNode;
use Timestamp;
use g2pRulesHelper;

my %order=();
my $debug=0;

#--------------------------------------------------------------------------

sub new {
	my $class = shift;
	my $self = {};
	bless ($self,$class);
	my $name=shift;
	$self->init($name);
	return $self;
}

sub init {
	my $self = shift;
	my $name = shift;
	my $root = new GNode();
	$root->name($name);
	$self->{ROOT}=$root;
	#$self->{BEGIN}=$root;
	my $log = new Timestamp();
	$self->{LOG}=$log;
	#%{$self->{ORDER}} = ();
	$self->{BEST}=0
}

#--------------------------------------------------------------------------

# Functions used to provide information about GTree

#sub begin {
#	my $self=shift;
#	return $self->{BEGIN};
#}

sub logging {
	my $self=shift;
	return $self->{LOG};
}

sub best {
	my $self=shift;
	if (@_) {$self->{BEST}=shift;}
	return $self->{BEST};
}

sub find_node {
	my ($self,$pat)=@_;
	my $found=0;
	my $busy=1;
	my $pointer=undef;
	my $next = $self->{ROOT};
	while (($found==0)&&($busy==1)) {
		if ($next->name eq $pat) {
			$pointer = $next;
			$found=1;
		} else {
			my @kids = @{$next->kids};
			$busy=0;
			foreach my $k (@kids) {
				my $kname = $k->name;
				if ($pat =~ /$kname/) {
					$next = $k;
					$busy=1;
					last;
				}
			}
		}
	}
	return $pointer;
}

sub leaves {
	my ($self,$node) = @_;
	my %done=();
	my @leaves = ();
	my @nodes = ( $node );		
	while (scalar @nodes > 0) {
		my $n = shift @nodes;
		next if $done{$n->name};
		my @kids = @{$n->kids};
		if (scalar @kids == 0) {
			push @leaves,$n;
		} else {
			foreach my $k (@kids) {
				push @nodes,$k;
			}
		}
		$done{$n->name}=1;
	}
	return @leaves;	
}

sub traverse {
	my $self=shift;	
	my @nodes = ($self->{ROOT});
	while (scalar @nodes > 0) {
		my $n = shift @nodes;
		if ($n->flag == 0) {
			printf "%s %s %d: ",$n->name,$n->countstr,$n->max;
			my @kids = @{$n->kids};
			foreach my $k (@kids) {
				printf "%s;",$k->name;
				push @nodes,$k;
			}
			print "\n";
			$n->set_flag;
		}
	}
	$self->clear_flags;
}

sub get_winning_rule {
	my $self=shift;
	$self->update_best;
	my $best=$self->{BEST};
	return undef if $best==0;
	my @possible = keys %{$order{$best}};
	return undef if scalar @possible==0;
	
	#Do conflict resolution
	my $maxpat = shift @possible;	
	my $maxsize=length $maxpat;
	foreach my $pat (@possible) {
		my $size = length $pat;
		if (($size<$maxsize)||
			(($size==$maxsize)&&((get_sym($pat)<get_sym($maxpat))||
								 ((get_sym($pat)==get_sym($maxpat))&&(right_first($pat)>(right_first($maxpat))))))) {
			$maxpat=$pat;
			$maxsize=$size;
		}
	}
	return $self->find_node($maxpat);
}

#--------------------------------------------------------------------------

# Functions used to build a GTree

#sub build_tree {
#    my ($self,$wordp)=@_;
#    my $log=$self->logging;
#    foreach my $word (keys %$wordp) {
#	$log->record('build-start',$word);
#        if ($word !~ /(.*)-(.)-(.*)/) {
#		die "Error: rule format error in build_tree [$word]\n";
#	}
#        #print "Adding word [$word]\n";
#        my $p = $wordp->{$word};
#	my $left=$1;
#	my $g=$2;
#	my $right=$3;
#	my $leftlen=length $left;
#	my $rightlen=length $right;
#	my $wordlen = $leftlen + $rightlen;
#        
#        my %prev_level=();
#        my %current_level=();
#                
#        #Add nodes for each subpattern including the word pattern
#        foreach my $sizelimit (0..$wordlen) {
#            foreach my $partleft (0..$sizelimit) {
#		last if ($partleft)>$leftlen;
#                my $partright = $sizelimit - $partleft;
#                next if ($partright)>$rightlen;
#		my $newleft=substr $left,$leftlen-$partleft,$partleft;
#                my $newright=substr $right,0,$partright;
#                my $newpat = "$newleft-$g-$newright";
#                my @parentlist=();
#                foreach my $pat (keys %prev_level) {
#                    if ($newpat =~ /$pat/) {
#                        push @parentlist,$pat;
#                    }
#                }
#                #print "Add $newpat with parents @parentlist\n";
#		#Add pattern to structure without updating counts, max or best
#                $self->add_pattern($newpat,\@parentlist);
#                $current_level{$newpat}=1;
#            }           
#            foreach my $pat (keys %prev_level) {
#                delete $prev_level{$pat};
#            }
#            foreach my $pat (keys %current_level) {
#                $prev_level{$pat}=1; delete $current_level{$pat};
#            }
#        }
#       $log->record('build-patts',$word); 
#        #Update the node counts to reflect that $word was added, without updating max or best
#        $self->update_counts_add($word,$p);
#	$log->record('build-counts',$word); 
#    }
#    #Create hash tracking ordering of nodes, also update max per node and best
#    $self->create_order;
#    $log->record('build-order'); 
#}

sub add_pattern_info {
	my ($self,$pat,$parentp,$cntp)=@_;
	my $newnode;
	if (length $pat>3) {
		$newnode=new GNode();
		$newnode->name($pat);
		foreach my $parent (@$parentp) {
			my $parentnode=$self->find_node($parent);
			die "Error: wrong calculation of parents: $parent not parent of $pat" if (!$parentnode);
			$newnode->add_parent($parentnode);
			$parentnode->add_kid($newnode);
		}
	} else {
		$newnode=$self->{ROOT};
	}
	$newnode->{MAX}=0;
	foreach my $p (keys %{$cntp}) {
		$newnode->{COUNT}{$p}=$cntp->{$p};
		if ($cntp->{$p}>$newnode->{MAX}) {
			$newnode->{MAX}=$cntp->{$p};
			$newnode->{OUTCOME}=$p;
		}
	}
	$order{$newnode->{MAX}}{$pat}=1;
	return $newnode->{MAX};
}

sub build_tree {
	my ($self,$patp)=@_;
	$self->{BEST}=0;
	#my $log=$self->logging;
	foreach my $len (sort {$a <=> $b} keys %{$patp}) {
		foreach my $pat (keys %{$patp->{$len}}) {
			if ($pat !~ /(.*)-(.)-(.*)/) {
				die "Error: rule format error in build_tree [$pat]\n";
			}
			my $left=$1; 
			my $g=$2;
			my $right=$3;
			my @parents=();
			if (length $left>0) {
				my $newleft = substr $left,1;
				push @parents, "$newleft-$g-$right";
			}
			if (length $right>0) {
				my $newlen=(length $right)-1;
				my $newright = substr $right,0,$newlen;
				push @parents, "$left-$g-$newright";
			}
			#$log->record('before_add',"$pat");
			my $max = $self->add_pattern_info($pat,\@parents,\%{$patp->{$len}{$pat}});
			#$log->record('after_add',"$pat");
			if ($max>$self->{BEST}) {
				$self->{BEST}=$max;
			}
		}
	}
}

sub add_pattern {
	my ($self,$pat,$parentp)=@_;
	my $newnode=$self->find_node($pat);
	if (!$newnode) {
	        $newnode=new GNode();
	        $newnode->name($pat);
	}
	foreach my $parent (@$parentp) {
		my $parentnode=$self->find_node($parent);
		die "Error: wrong calculation of parents" if (!$parentnode);
		$newnode->add_parent($parentnode);
		$parentnode->add_kid($newnode);
	}
	return $newnode;
}

sub update_counts_add{
	my ($self,$word,$p)=@_;	
	my %done=();
	my @nodes = ($self->{ROOT});
	while (scalar @nodes > 0) {
		my $n = shift @nodes;
		next if (exists $done{$n->name});
		if ($n->match($word)) {
			$n->inc($p);
			my @kids = @{$n->kids};
			foreach my $k (@kids) {
				push @nodes,$k;
			}
		}
		$done{$n->name}=1;
	}
}

sub create_order{
	my $self=shift;
	my $best=0;
	my %done=();
	my @nodes = ($self->{ROOT});
	while (scalar @nodes > 0) {
		my $n = shift @nodes;
		my $name=$n->{NAME};
		next if (exists $done{$name});
		my $max = $n->update_max;
		#$self->{ORDER}->{$n->max}->{$n->name}=1;
		$order{$max}{$name}=1;
		if ($max>$best) {
			$best=$max;
		}
		my @kids = @{$n->kids};
			foreach my $k (@kids) {
				push @nodes,$k;
			}
		$done{$name}=1;
	}
	$self->{BEST}=$best;
}

#--------------------------------------------------------------------------
# Functions used to manipulate a GTree

sub remove_rule {
	my ($self,$rule)=@_;
	$rule->set_inactive;
	$self->delete_order($rule);
	my @inc=();
	my @dec=();
	my @wordnodes = $self->leaves($rule);
	foreach my $w (@wordnodes) {
		if ($w->outcome eq $rule->outcome) {
			if (!$w->done) {
				#$self->update_counts_move($w);
				push @dec,$w;
				$w->set_done;
			}
		} else {
			if ($w->done) {
				#$self->update_counts_return($w);
				push @inc,$w;
				$w->clear_done;
			}
		}
	}
	
	#update counts, max and order, using flag to indicate which nodes have been done
	my $log=$self->logging;
	#$log->record('before update');
	$self->update_info_for_tree($self->{ROOT},\@inc,\@dec);
	#$log->record('after update');
	$self->clear_flags;
	#$log->record('clear');
	return 1;
}

#sub update_counts_move{
#	my ($self,$word,$p)=@_;	
#	my %done=();
#	my @nodes = ($self->{ROOT});
#	while (scalar @nodes > 0) {
#		my $n = shift @nodes;
#		next if (exists $done{$n->name});
#		if ($n->match($word->name)) {
#			my $prev = $n->max;
#			my $max = $n->dec_all;
#			$self->update_order($n->name,$prev,$max);
#			my @kids = @{$n->kids};
#			foreach my $k (@kids) {
#				push @nodes,$k;
#			}
#		}
#		$done{$n->name}=1;
#	}
#}
#
#sub update_counts_return{
#	my ($self,$word,$p)=@_;	
#	my %done=();
#	my @nodes = ($self->{ROOT});
#	while (scalar @nodes > 0) {
#		my $n = shift @nodes;
#		next if (exists $done{$n->name});
#		if ($n->match($word)) {
#			my $prev = $n->max;
#			my $max = $n->inc_all;
#			$self->update_order($n->name,$prev,$max);
#			my @kids = @{$n->kids};
#			foreach my $k (@kids) {
#				push @nodes,$k;
#			}
#		}
#		$done{$n->name}=1;
#	}
#}

sub delete_order {
	my ($self,$rule)=@_;
	my $best = $rule->max;
	#delete $self->{ORDER}->{$best}->{$rule->name};
	#my @siblings = keys (%{$self->{ORDER}->{$best}});
	delete $order{$best}{$rule->name};
	my @siblings = keys (%{$order{$best}});
	if (scalar @siblings == 0) {
		delete $order{$best}
	}
}

sub update_best {
	my $self=shift;
	my $best = $self->{BEST};
	my $found=0;
	while ($best>0) {
		if (exists $order{$best}) {
			if (scalar keys %{$order{$best}}==0) {
				delete $order{$best};
				$best--;
			} else {
				$self->{BEST}=$best;
				$found=1;
				last;
			}
		} else {
			$best--;
		}
	}
	if ($found==0) {
		$self->{BEST}=0;
	}
	return $self->{BEST};
}

#sub update_info_for_tree{
#	my ($self,$node,$incp,$decp)=@_;
#	next if $node->flag;
#	#my $log = $self->logging;
#	if ($node->active==1) {
#		my $add = scalar @{$incp};
#		my $del = scalar @{$decp};
#		my $prev=$node->max;
#		$node->inc_all($add-$del);	
#		my $new=$node->update_max;
#		$self->update_order($node->name,$prev,$new);
#		#my $name=$node->name;
#		#$log->record("update",$name);
#	}
#	$node->set_flag;
#	my @kids = @{$node->kids};
#	foreach my $k (@kids) {
#		next if $k->flag;
#		my @new_inc=();
#		my @new_dec=();
#		my $work=0;
#		foreach my $word (@{$incp}) {
#			if ($k->match($word->name)) {
#				push @new_inc,$word;
#				$work=1;
#			}
#		}
#		foreach my $word (@{$decp}) {
#			if ($k->match($word->name)) {
#				push @new_dec,$word	;
#				$work=1;
#			}
#		}
#		if ($work==1) {
#			$self->update_info_for_tree($k,\@new_inc,\@new_dec);
#		}
#	}		
#}

sub update_info_for_tree{
	my ($self,$node,$incp,$decp)=@_;
	next if $node->{FLAG}==1;
	#my $log = $self->logging;
	my $name=$node->{NAME};
	#$log->record("update-start",$name);
	if ($node->{ACTIVE}==1) {
		my $add = scalar @{$incp};
		my $del = scalar @{$decp};
		my $prev=$node->{MAX};
		$node->inc_all($add-$del);	
		my $new=$node->update_max;
		#$log->record("update-max",$name);		
		$self->update_order($name,$prev,$new);
		#$log->record("update-order",$name);
	}
	$node->{FLAG}=1;
	my @kids = @{$node->{KIDS}};
	foreach my $k (@kids) {
		next if $k->{FLAG}==1;
		my @new_inc=();
		my @new_dec=();
		my $work=0;
		foreach my $word (@{$incp}) {
			my $pat=$k->{NAME};
			if ($word->{NAME} =~ /$pat/) {
				push @new_inc,$word;
				$work=1;
			}
		}
		foreach my $word (@{$decp}) {
			my $pat=$k->{NAME};
			if ($word->{NAME} =~ /$pat/) {
				push @new_dec,$word	;
				$work=1;
			}
		}
		if ($work==1) {
			#$log->record("update-kids",$name);
			$self->update_info_for_tree($k,\@new_inc,\@new_dec);
		}
	}		
}


sub update_order {
	my ($self,$name,$prev,$new)=@_;
	#delete $self->{ORDER}->{$prev}->{$name};
	#my @siblings = keys (%{$self->{ORDER}->{$prev}});
	delete $order{$prev}{$name};
	#my @siblings = keys (%{$order{$prev}});
	#f (scalar @siblings == 0) {
	#	delete $self->{ORDER}->{$prev}
	#	delete $order{$prev}
	#}
	#$self->{ORDER}->{$new}->{$name}=1;
	$order{$new}{$name}=1;	
}

sub clear_flags {
	my $self=shift;
	my %done=();
	my @nodes = ($self->{ROOT});
	while (scalar @nodes > 0) {
		my $n = shift @nodes;
		next if (exists $done{$n->name});
		$n->clear_flag;
		my @kids = @{$n->kids};
		foreach my $k (@kids) {
			if ($k->flag==1) {push @nodes,$k}
		}
		$done{$n->name}=1;
	}
}

#--------------------------------------------------------------------------

#sub create_net{
#	my $self=shift;	
#	my %done=();
#	my %counts=();
#	my @nodes = ($self->{ROOT});
#	my $best=0;
#	while (scalar @nodes > 0) {
#		my $n = shift @nodes;
#		next if (exists $done{$n->name});
#		my $max = $n->max;
#		push @{$counts{$max}},$n;
#		if ($max>$best) {
#			$best=$max;
#		}
#		my @kids = @{$n->kids};
#		foreach my $k (@kids) {
#			push @nodes,$k;
#		}
#		$done{$n->name}=1;
#	}
#	
#	my $start = new GNode;
#	$self->{BEGIN}=$start;
#	$start->name('start');
#	$start->max(10000);
#	my $head=shift @{$counts{$best}};
#	$start->after($head);
#	$head->before($start);
#	my $cnt=$best;
#	while ($cnt>0) {
#		if (exists $counts{$cnt}) {
#			while (scalar @{$counts{$cnt}}>0) {
#				my $next=shift @{$counts{$cnt}};
#				$head->add_after($next);
#				$next->add_before($head);
#				$head=$next;
#			}
#		}
#		$cnt--;
#	}
#	my $end = new GNode;
#	$end->name('end');
#	$end->max(-10000);
#	$head->after($end);
#	$end->before($head);
#}
#
#
#sub traverse_net {
#	my $self=shift;	
#	my $next = $self->{BEGIN};
#	while ($next) {
#		printf "%s %s %d\n",$next->name,$next->countstr,$next->max;
#		$next=$next->{AFTER};
#	}
#	$self->clear_tree;
#}
#
#sub net_add_rule {
#	my ($self,$rule,$before)=@_;
#	my $after = $before->after;
#	if ($before) {
#		$before->add_after($rule);
#		$rule->add_before($before);
#	}
#	if ($after) {
#		$after->add_before($rule);
#		$rule->add_after($before);
#	}
#}
#
#sub net_remove_rule {
#	my ($self,$rule)=@_;
#	my $before = $rule->before;
#	my $after = $rule->after;
#	if ($before) {
#		$before->add_after($after);
#	}
#	if ($after) {
#		$after->add_before($before);
#	}
#	$rule->before(undef);
#	$rule->after(undef);
#}
#
#sub net_order {
#	my ($self,$node)=@_;
#	my $from_orig = $node->before;
#	my $to_orig = $node->after;
#	my $from = $from_orig;
#	my $to = $to_orig;
#	my $log = $self->{LOG};
#	if (($from)&&($node->max > $from->max)) {
#		while ($node->max > $from->max) {
#			$from=$from->before;
#		}
#		#$log->record('find');
#		my $new_after = $from->after;
#		$from->after($node);
#		$node->before($from);
#		$node->after($new_after);
#		$new_after->before($node);
#		$from_orig->after($to_orig);
#		$to_orig->before($from_orig);
#		#$log->record('move');
#	} elsif (($to)&&($node->max < $to->max)) {
#		while ($node->max < $to->max) {
#			$to=$to->after;
#		}
#		#$log->record('find');
#		my $new_before = $to->before;
#		$new_before->after($node);
#		$node->before($new_before);
#		$node->after($to);
#		$to->before($node);
#		$from_orig->after($to_orig);
#		$to_orig->before($from_orig);		
#		#$log->record('move');
#	}
#	#printf "HERE----- found right place for %s\n",$node->name;
#	#$self->traverse_net;
#}
#sub get_winning_rule {
#	my $self=shift;
#	#Do conflict resolution here... xxx
#	my $winner = $self->begin->after;
#	if ($winner->max<=0) {
#		$winner = undef;
#	}
#	return $winner;
#}

#--------------------------------------------------------------------------

1;
