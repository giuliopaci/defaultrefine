#!/usr/bin/perl -w


#--------------------------------------------------------------------------
use g2pFiles;
use g2pArchive;
use g2pDict;
use g2pAlign;
use g2pRules;
use g2pSound;
use g2pShow;
use g2pDo;

#--------------------------------------------------------------------------

sub test_files() {
	local (@graphs,@phones);
	read_graphs @graphs;
	read_phones @phones;
	print "Graphs: @graphs\nPhones: @phones\n";

	local @errors = ();
	foreach my $ft ( @allft ) {
		verify_file $ft,@errors;
		print "Possible errors: @errors\n";
	}

	print "Test rest by hand - see script\n";
	#write_expid 'Afrikaans';
	#write_langid 'gen040507';
	#new_exp 'test2';
	#cp_exp 'gen040507','test3';
}

	
sub test_archive() {
	read_archive;
	my $archstr = join "\n",@archive;
	print "Archive:\n$archstr\n";
	my $last = &g2pArchive::laststate;
	print "Laststate: $last\n";
	foreach my $ft ( @allft ) {
		$last = &g2pArchive::lastupdated($ft);
		print "Last $ft updated: $last\n";
	}

	my $aname = "$adir/$at";
	my $lname = "$cdir/$tlog";
	print "Before:\n";
	read_archive;
	$archstr = join "\n",@archive;
	print "Archive:\n$archstr\n";
	print "Text archive:\n"; 
	print `cat $aname`;
	print "Log:\n"; 
	print `tail $lname`;
	print "$aname $lname\n";

	addstate("test;;testing");
	print "After:\n"; 
	$archstr = join "\n",@archive;
	print "Archive:\n$archstr\n";
	print "Text archive:\n"; 
	print `cat $aname`;
	print "Log:\n"; 
	print `tail $lname`;
}

sub test_dict() {
	my @words = ('one','two','three','four');
	fwrite_words('test.words',@words);
	print `cat test.words`;

	@words = ();
	fread_words('test.words',@words);
	print "words: @words\n";
	
	my %tdict=(); my %tstat=();
	$tdict{'one'} = 'win';
	$tdict{'two'}='tu';
	$tdict{'three'}='Tri';
	$tdict{'four'}='for';
	$tstat{'one'}=1;
	$tstat{'two'}=1;
	$tstat{'three'}=-1;
	$tstat{'four'}=0;
	fwrite_dict('test.dict1',%tdict,%tstat);
	print "\ntest.dict1\n";
	print `cat test.dict1`;

	%tdict=(); %tstat=();
	fread_dict('test.dict1',%tdict,%tstat);
	while ( my ($word,$val) = each %tdict) {
		print "$word = $val = $tstat{$word}\n";
	}

	%tdict=(); %tstat=();
	$tdict{'one'} = 'wan';
	$tdict{'two'}='t';
	$tdict{'three'}='Tri';
	$tdict{'four'}='fo';
	$tdict{'five'}='faiv';
	$tdict{'six'}='siks';
	$tstat{'one'}=1;
	$tstat{'two'}=0;
	$tstat{'three'}=1;
	$tstat{'four'}=1;
	$tstat{'five'}=1;
	$tstat{'six'}=0;
	fwrite_dict('test.dict2',%tdict,%tstat);
	print "\ntest.dict2\n";
	print `cat test.dict2`;

	fadd_dict('test.dict2','test.dict1');
	print "\ntest.dict2 added to test.dict:\n";
	print `cat test.dict1`;

	my %tdict3=(); %tstat3=();
	$tdict3{'two'} = 'n';
	$tdict3{'four'}='fo';
	$tdict3{'six'}='siks';
	$tdict3{'seven'}='sev1n';
	$tstat3{'two'}=0;
	$tstat3{'four'}=0;
	$tstat3{'six'}=1;
	$tstat3{'seven'}=-1;
	fwrite_dict('test.dict3',%tdict3,%tstat3);
	print "\ntest.dict3\n";
	print `cat test.dict3`;

	%tdict=(); %tstat=();
	fread_dict('test.dict2',%tdict,%tstat);
	add_stat(%tdict3,%tstat3,%tdict,%tstat);
	print "\nStats updated: test.dict3 updated with test.dict2\n";
	while ( my ($word,$val) = each %tdict3) {
		print "$word = $val = $tstat3{$word}\n";
	}
	
	fread_dict('test.dict3',%tdict,%tstat);
	rm_uncertain_dict(%tdict,%tstat);
	print "\nUncertain removed from test.dict3\n";
	while ( my ($word,$val) = each %tdict) {
		print "$word = $val = $tstat{$word}\n";
	}
	
	fread_dict('test.dict3',%tdict,%tstat);
	rm_notcorrect_dict(%tdict,%tstat);
	print "\nNot correct removed from test.dict3\n";
	while ( my ($word,$val) = each %tdict) {
		print "$word = $val = $tstat{$word}\n";
	}

	print "\ntest.dict2\n";
	print `cat test.dict2`;
	fwlist_fromdict(4,0,'test.dict2','test.words');
	print "\ntest.words (first 4)\n";
	print `cat test.words`;
	fwlist_fromdict(3,1,'test.dict2','test.words');
	print "\ntest.words (first uncertain 3)\n";
	print `cat test.words`;

	@words = ('one','two','three','four','five','six');
	fwrite_words('test.words',@words);
	print "\ntest.words\n";
	print `cat test.words`;

	%tdict=(); %tstat=();
	fread_dict('test.dict2',%tdict,%tstat);
	print "\ntest.dict2\n";
	print `cat test.dict2`;
	@words=();
	fwlist_first('test.words',%tstat,1,3,@words);
	print "\nWords (first 3 uncertain from master): @words\n";
	@words=();
	fwlist_first('test.words',%tstat,0,3,@words);
	print "\nWords (first 3 from master): @words\n";
	@words=();
	fwlist_even('test.words',%tstat,0,3,@words);
	print "\nWords (even 3 from master): @words\n";
	@words=();
	fwlist_even('test.words',%tstat,1,2,@words);
	print "\nWords (even 2 uncertain from master): @words\n";

	
}

sub test_align() {


}

sub test_rulesmod() {
}


#--------------------------------------------------------------------------

if (@ARGV != 1) {
	print "Usage: g2ptest [ files | archive | dict | align | rules ]\n";
	exit;
}

if ($ARGV[0] eq "files") {
	test_files;
} elsif ($ARGV[0] eq "archive") {
	test_archive;
} elsif ($ARGV[0] eq "dict") {
	test_dict;
} elsif ($ARGV[0] eq "align") {
	test_align;
} elsif ($ARGV[0] eq "rules") {
	test_rulesmod;
} else {
	print "Usage: g2ptest [ files | archive | dict | align | rules ]\n";
}

#--------------------------------------------------------------------------
