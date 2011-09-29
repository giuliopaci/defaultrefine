package Timestamp;
use strict;

use Time::Local;

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
	$self->{CURRENT}=timelocal(gmtime());
	%{$self->{ACC}}=();
}

#--------------------------------------------------------------------------

sub record {
	my $self=shift;
	my $activity="";
	my $comment="";
	if (@_) {$activity=shift}
	if (@_) {$comment=shift}
	my $cnt = timelocal(gmtime());
	my $diff = $cnt - $self->{CURRENT};
	$self->{CURRENT} = $cnt;
	$self->{ACC}->{$activity}+= $diff;
	print "$cnt\t$diff\t$activity\t$comment\n";
}

sub summarise {
	my $self=shift;
	foreach my $a (keys %{$self->{ACC}}) {
		print "$a\t$self->{ACC}->{$a}\n";
	}
}

#--------------------------------------------------------------------------

1;

