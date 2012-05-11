package GNode;
use strict;

#--------------------------------------------------------------------------

sub new {
	my $class = shift;
	my $self = {};
	bless ($self,$class);
	$self->init();
	return $self;
}

sub init {
	my $self = shift;
	$self->{NAME} = undef;
	$self->{MAX} = 0;
	$self->{OUTCOME} = undef;
	%{$self->{COUNT}} = ();
	#$self->{BEFORE} = undef;
	#$self->{AFTER} = undef;
	@{$self->{PARENTS}} = ();
	@{$self->{KIDS}} = ();
	$self->{DONE}=0;
	$self->{FLAG}=0;
	$self->{ACTIVE}=1;
}

#--------------------------------------------------------------------------

sub name {
	my $self = shift;
	if (@_) { $self->{NAME} = shift }
	return $self->{NAME};
}

sub max {
	my $self = shift;
	if (@_) { $self->{MAX} = shift }
	return $self->{MAX};
}

sub outcome {
	my $self = shift;
	return $self->{OUTCOME};
}

sub parents {
	my $self = shift;
	return $self->{PARENTS};
}

sub kids {
	my $self = shift;
	return $self->{KIDS};
}

#sub before {
#	my $self = shift;
#	if (@_) { $self->{BEFORE} = shift }
#	return $self->{BEFORE};
#}
#
#sub after {
#	my $self = shift;
#	if (@_) { $self->{AFTER} = shift }
#	return $self->{AFTER};
#}

sub done {
	my $self = shift;
	return $self->{DONE};
}

sub set_done {
	my $self = shift;
	$self->{DONE}=1;
}

sub clear_done {
	my $self = shift;
	$self->{DONE}=0;
}

sub flag {
	my $self = shift;
	return $self->{FLAG};
}

sub set_flag {
	my $self = shift;
	$self->{FLAG}=1;
}

sub clear_flag {
	my $self = shift;
	$self->{FLAG}=0;
}

sub active {
	my $self = shift;
	return $self->{ACTIVE};
}

sub set_inactive {
	my $self = shift;
	$self->{ACTIVE}=0;
}

sub countstr {
	my $self = shift;
	my @str=();
	foreach my $p (keys %{$self->{COUNT}}) {
		push @str, "$p($self->{COUNT}{$p})";
	}
	my $countstr = join ";",@str;
	return $countstr;
}

#sub outcomes {
#	my $self = shift;
#	return keys %{$self->{COUNT}};
#}

#--------------------------------------------------------------------------

sub add_parent {
	my $self = shift;
	die  "Error: must provide parent node as argument to method 'add_parent'" if !@_;
	my $newparent = shift;
	my @current = @{$self->{PARENTS}};
	my %set = map {$_=>1} @current;
	if (!(exists $set{$newparent})) {
		push @{$self->{PARENTS}},$newparent;
	}
	return $self->{PARENTS};
}

sub add_kid {
	my $self = shift;
	die  "Error: must provide kid node as argument to method 'add_kid'" if !@_;
	my $newkid = shift;
	my @current = @{$self->{KIDS}};
	my %set = map {$_=>1} @current;
	if (!(exists $set{$newkid})) {
		push @{$self->{KIDS}},$newkid;
	}
	return $self->{KIDS};
}
	
#sub add_after {
#	my $self = shift;
#	die  "Error: must provide next node as argument to method 'add_after'" if !@_;
#	$self->{AFTER} = shift;
#	return $self->{AFTER};
#}
#
#sub add_before {
#	my $self = shift;
#	die  "Error: must provide previous node as argument to method 'add_before'" if !@_;
#	$self->{BEFORE} = shift;
#	return $self->{BEFORE};
#}
	
sub inc {
	my ($self,$p) = @_;
	$self->{COUNT}{$p}++;
	#return $self->update_max;
}

sub dec {
	my ($self,$p) = @_;
	$self->{COUNT}{$p}--;
	#return $self->update_max;
}

sub inc_all {
	my $self = shift;
	my $inc=1;
	if (@_) {$inc=shift}
	foreach my $p (keys %{$self->{COUNT}}) {
		$self->{COUNT}{$p}+=$inc;
	}
	#return $self->update_max;
}

sub dec_all {
	my $self = shift;
	my $dec=1;
	if (@_) {$dec=shift}
	foreach my $p (keys %{$self->{COUNT}}) {
		$self->{COUNT}{$p}-=$dec;
	}
	#return $self->update_max;
}

sub match {
	my ($self,$pat) = @_;
	my $name = $self->{NAME};
	if ($pat =~ /$name/) {
		return 1;
	} else {
		return 0;
	}
}

sub update_max {
	my $self=shift;
	my $max=0;
	my $maxp=$self->{OUTCOME};
	foreach my $p (keys %{$self->{COUNT}}) {
		my $cnt = $self->{COUNT}{$p};
		if ($cnt>$max) {
			$max=$cnt;
			$maxp=$p;
		}
	}
	$self->{MAX}=$max;
	$self->{OUTCOME}=$maxp;
	return $max;
}

#--------------------------------------------------------------------------

1;
