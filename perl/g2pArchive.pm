package g2pArchive;

use g2pFiles;
#use g2pAlign;
use g2pDict;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;
        $tlog = "timelog";
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(@archive $tlog &read_archive &addstate &store_file &write_tlog &analyse_tlog &analyse_vlog);
}

#--------------------------------------------------------------------------

sub read_archive() {
	print "-- Enter read_archive: $adir\n" if $debug;
	$#archive = -1; 
	open FH,"$adir/$at" or die "Unable to open archive $adir/$at";
	while (<FH>) {
		chomp; print "\t$_\n" if $debug;
		push @archive,$_;
	}
	close FH;
}

sub laststate() {
	read_archive;
	my $state = $archive[$#archive];
	my @info = split /;/,$state;
	shift @info;
}

sub change { s/^(.*);.*;(.*);.*$/$1;$2/g; return $_ }

sub lastupdated($) {
		my $ftype = shift @_;
	print "-- Enter lastupdated: $ftype\n" if $debug;
	read_archive;
 	my @states = map change,@archive; 
	@states = grep /$ftype/,@states;
	my $state = pop @states;
	my @info = split /;/,$state;
	shift @info;
}

#--------------------------------------------------------------------------

sub addstate($) {
	my $msg = shift @_;
	print "-- Enter addstate: $msg, $adir/$at\n" if $debug;
	read_archive;
	my $id = laststate; $id++;
	my $state =  "$id;$msg";
	push @archive,$state;
	`echo "$state" >> "$adir/$at"`;
	write_tlog("newState",$state);
}

#store_file(filetype) - from current to archive
sub store_file($) {
	my $ftype = shift @_;
	print "-- Enter store_file $ftype\n" if $debug;
	my $state = lastupdated($ftype);
	`cp $cdir/$ftype $adir/$ftype.$state`; 
}

#--------------------------------------------------------------------------


sub init_tlog() {
	my $fname = "$cdir/$tlog";
	print "-- Enter init_tlog: $fname\n" if $debug;
	open FH,">$fname" or die;
	print FH "TLOG_VERSION 1.1\n";
	close FH;
	write_tlog("init","$fname");
}

sub write_tlog($$) {
	use Time::Local;
	my ($event,$info) = @_;
	my $fname = "$cdir/$tlog";
	print "-- Enter write_tlog: $event,$info,$fname\n" if $debug;
	open FH,">>$fname" or die;
	my ($sec, $min, $hour,$mday,$mon,$year) = gmtime();
	my $cnt = timelocal(gmtime());
	$year=$year-100; $mon++;
	print FH "${year}/${mon}/${mday};${hour}:${min}:$sec;$cnt;$event;$info\n";
	close FH;
}

#--------------------------------------------------------------------------

sub get_time_v1($){
	use Time::Local;
	my $tname = shift @_;
	my @t = split /:/,$tname;
	my $tcount = timelocal($t[2],$t[1],$t[0],1,1,2001);
	$tcount = $tcount - timelocal(0,0,0,1,1,2001);
	return $tcount;
}

sub writeEvent_v1($\$$\%\%$) {
	my ($state,$startp,$now,$ltp,$wp,$msg) = @_;
	my $secs = $now-$$startp;
	#HACK - solves problem removed in TLOG v1.1 + Fix code properly later
	if ($secs<0){$secs = $secs + timelocal(0,0,0,2,1,2001)-timelocal(0,0,0,1,1,2001);}
	$ltp->{$state} += $secs; 
	$wp->{$state}++;
	print "$state;$secs;$msg\n";
	$$startp=$now;
}

sub writeEvent($\$$\%\%$) {
	my ($state,$startp,$now,$ltp,$wp,$msg) = @_;
	my $secs = $now-$$startp;
	$ltp->{$state} += $secs; 
	$wp->{$state}++;
	print "$state;$secs;$msg\n";
	$$startp=$now;
}

sub analyse_tlog_v1_0 ($) {
	my ($line1) = shift @_;
	my @log=(); my $i=0;
	
	my @line = split /;/,$line1; 
	$log[$i]{'time'} = get_time_v1($line[0]);
	$log[$i]{'event'} = $line[1];
	$log[$i]{'info'} = $line[2];
	while (<IH>) {
		$i++;
		chomp; my @line = split ";",$_; 
		$log[$i]{'time'} = get_time_v1($line[0]);
		$log[$i]{'event'} = $line[1];
		$log[$i]{'info'} = $line[2];
	}

	my %ltime=(); $ltime{'verify'}=0; $ltime{'redo'}=0; $ltime{'idle'}=0;
	my %word=(); $word{'verify'}=0; $word{'redo'}=0;$word{'idle'}=0;
	my $state = "init";
	my $start=0; my $from=""; 
	foreach my $i (0 .. $#log) {
		my $now=$log[$i]{'time'};
		my $event=$log[$i]{'event'};
		my $inf=$log[$i]{'info'};
		#print "$now $event $inf\n";
		if (($event eq "verifyNext")||($event eq "doRedo")) {
			$inf =~ s/^\[(.*)\]\[(.*)\]$/$1$2/g;
			$text=$1; $from=$2;
		}

		if ($event eq "Generate") {
			$inf =~ s/\[(.*)\]\[(.*)\]/$1$2/g;
			$togen = "$1;$2";
		} elsif ($event eq "Play") {
			$toplay = $inf;
			if ($toplay =~ /.*\/tmp\/.*.wav/) {
				print "playword;0;$togen\n";
			} else {
				$toplay =~ s/.*\/([^\/]*).wav/$1/g;
				print "playsound;0;$toplay\n";
			}
		} elsif ($state eq "init") {
			$start=$now;
			if ($event eq "verifyNext"){$state="verify";}
			elsif ($event eq "chooseRedo"){$state="redo"}
			else {$state="idle"}
		} elsif ($state eq "idle"){
			if ($event eq "verifyNext"){
				if ($now-$start>2) { writeEvent_v1("idle",$start,$now,,%ltime,%word,"");}
				$state="verify"
			} elsif ($event eq "chooseRedo"){
				if ($now-$start>2) { writeEvent_v1("idle",$start,$now,,%ltime,%word,""); }
				$state="redo"
			} else {$state="idle"}
		} elsif ($state eq "verify") {
			if ($event eq "verifyNext"){
				writeEvent_v1("idle",$start,$now,,%ltime,%word,"");
				$state="verify";
			} elsif ($event eq "chooseRedo"){
				writeEvent_v1("idle",$start,$now,,%ltime,%word,"");
				$state="redo";
			} elsif ($event eq "done") {
				if ($inf !~ s/\[(.*)\]\[(.*)\]\[(.*)\]/$1$2$3/) { print "Warning: Error reading logfile at $inf\n";}
				else {writeEvent_v1("verify",$start,$now,,%ltime,%word,"$3;$text;$from;$2");}
				$state="idle";
			} 
		} elsif ($state eq "redo") {
			if ($event eq "verifyNext"){
				#HACK - doneRedo was not logged. Assume chooseRedo always after actually done - over conservative; verdict unavailable from logs
				writeEvent_v1("redo",$start,$now,,%ltime,%word,";0;$text;$from;");
				$state="verify"
			} elsif ($event eq "chooseRedo"){
				#HACK - doneRedo was not logged. Assume chooseRedo always after actually done - over conservative; verdict unavailable from logs
				writeEvent_v1("redo",$start,$now,,%ltime,%word,";0;$text;$from;");
				$state="redo";
			} elsif ($event eq "doRedo") {
				if ($inf !~ s/^(.*),(.*)$/$1$2/) { print "Warning: Error reading logfile at $inf\n";}
				$text=$1;$from=$2;
				$state="redo";
			} 
		} 
	}
	#print "Verifying: total time = $ltime{'verify'}\n";
	#print "Verifying: total words = $word{'verify'}\n";
	#print "Correcting: total time = $ltime{'redo'}\n";
	#print "Correcting: total words = $word{'redo'}\n";
	#print "Idle: total time = $ltime{'idle'}\n";
	#print "Idle: number of times = $word{'idle'}\n";
}

sub analyse_tlog_v1_1 () {
	my @log=(); my $i=0; 

	while (<IH>) {
		chomp; my @line = split ";",$_; 
		$log[$i]{'time'} = ($line[2]);
		$log[$i]{'event'} = $line[3];
		$log[$i]{'info'} = $line[4];
		$i++;
	}

	my %ltime=(); $ltime{'verify'}=0; $ltime{'redo'}=0; $ltime{'idle'}=0;
	my %word=(); $word{'verify'}=0; $word{'redo'}=0;$word{'idle'}=0;
	my $state = "init";
	my $start=0; my $from=""; my $togen=""; 
	foreach my $i (0 .. $#log) {
		my $now=$log[$i]{'time'};
		my $event=$log[$i]{'event'};
		my $inf=$log[$i]{'info'};
		#print "$now $event $inf\n";
		if (($event eq "verifyNext")||($event eq "doRedo")) {
			$inf =~ s/\[(.*)\]\[(.*)\]/$1$2/g;
			$text=$1; $from=$2;
		}

		if ($event eq "Generate") {
			$inf =~ s/\[(.*)\]\[(.*)\]/$1$2/g;
			$togen = "$1;$2";
		} elsif ($event eq "Play") {
			$toplay = $inf;
			if ($toplay =~ /.*\/tmp\/.*.wav/) {
				print "playword;0;$togen\n";
			} else {
				$toplay =~ s/.*\/([^\/]*).wav/$1/g;
				print "playsound;0;$toplay\n";
			}
		} elsif ($state eq "init") {
			$start=$now;
			if ($event eq "verifyNext"){ $state="verify";}
			elsif ($event eq "chooseRedo"){$state="redo"}
			else {$state="idle"}
		} elsif ($state eq "idle"){
			if ($event eq "verifyNext"){
				if ($now-$start>2) {writeEvent("idle",$start,$now,,%ltime,%word,"");}
				$state="verify"
			} elsif ($event eq "chooseRedo"){
				if ($now-$start>2) {writeEvent("idle",$start,$now,,%ltime,%word,"");}
				$state="redo"
			} else {$state="idle"}
		} elsif ($state eq "verify") {
			if ($event eq "verifyNext"){
				writeEvent("idle",$start,$now,,%ltime,%word,"");
				$state="verify";
			} elsif ($event eq "chooseRedo"){
				writeEvent("idle",$start,$now,,%ltime,%word,"");
				$state="redo";
			} elsif ($event eq "done") {
				if ($inf !~ s/\[(.*)\]\[(.*)\]\[(.*)\]/$1$2$3/) { print "Warning: Error reading logfile at $inf\n";}
				else {writeEvent("verify",$start,$now,,%ltime,%word,"$3;$text;$from;$2");}
				$state="idle";
			} 
		} elsif ($state eq "redo") {
			if ($event eq "verifyNext"){
				writeEvent("idle",$start,$now,,%ltime,%word,"");
				$state="verify"
			} elsif ($event eq "chooseRedo"){
				writeEvent("idle",$start,$now,,%ltime,%word,"");
				$state="redo";
			} elsif ($event eq "doRedo") {
				$state="redo";
			} elsif ($event eq "doneRedo") {
				if ($inf !~ s/\[(.*)\]\[(.*)\]/$1$2/) { print "Warning: Error reading logfile at $inf\n";}
				else {writeEvent("redo",$start,$now,,%ltime,%word,";0;$text;$from;$2");}
				$state="idle";
			} 
		} 
	}
	#print "Verifying: total time = $ltime{'verify'}\n";
	#print "Verifying: total words = $word{'verify'}\n";
	#print "Correcting: total time = $ltime{'redo'}\n";
	#print "Correcting: total words = $word{'redo'}\n";
	#print "Idle: total time = $ltime{'idle'}\n";
	#print "Idle: number of times = $word{'idle'}\n";
}


sub analyse_tlog ($) {
	my $lname = shift @_;
	open IH, $lname or die "Cannot open $lname";
	my @log=(); my $i=0; my $logver;

	my $line1 = <IH>; chomp($line1);
	my @id = split " ",$line1;
	if ($id[0] eq "TLOG_VERSION") {$logver = $id[1]; print "TLOG_VERSION $logver\n";}
	else {print "TLOG_VERSION Warning: Possibly not log file. Assuming tlog version 1.0\n";$logver="1.0"}

	if ($logver=="1.0") {analyse_tlog_v1_0($line1);}
	elsif ($logver=="1.1") {analyse_tlog_v1_1;}
	else {die "Error: unknown log file format\n";}
	close IH;
}

#--------------------------------------------------------------------------


sub analyse_vlog_dict ($$) {
	my ($lname,$dname) = @_;
	open LH, $lname or die "Cannot open $lname";
	my %dict=(); my %stat=();
	fread_dict($dname,%dict,%stat);
	
	<LH>;
	while (<LH>) {
		chomp;
		my @line=split ";",$_;
		if ($line[0] eq "verify") {
			my ($time,$verdict,$word,$from,$to);
			if ($#line==5){($time,$verdict,$word,$from,$to) = ($line[1],$line[2],$line[3],$line[4],$line[5])};
			if ($#line==4){($time,$verdict,$word,$from,$to) = ($line[1],$line[2],$line[3],$line[4],"")};
			if ($#line==3){($time,$verdict,$word,$from,$to) = ($line[1],$line[2],$line[3],"","")};
			#print "[$time],[$verdict],[$word],[$from],[$to]\n";
			my %res=(); my $status=0;
			if (!exists $stat{$word}) {print "Warning: word not in reference dict, not analysing!!\n";next}
			if ($verdict==1) {
				compare_words($from,$to,%res);
				my $strlen = length $word;
				if (!($stat{$word}==1)){
					$status=$stat{$word};
				}else{
					if ($dict{$word} eq $to){
						$status=1;
					} else {
						$status=0;
					}
				}
				#print "$time;1;$status;$res{'total'};$word;$from;$to\n";
				print "$time;1;$status;$res{'total'};$strlen\n";
			} else {
				if ($stat{$word}!=$verdict){
					$status=0;
				}else{
					$status=1;
				}
				print "$time;$verdict\n";
			}	
		}
	}
	close LH
}


sub analyse_vlog ($) {
	my ($lname) = @_;
	open LH, $lname or die "Cannot open $lname";
	
	<LH>;
	while (<LH>) {
		chomp;
		my @line=split ";",$_;
		if ($line[0] eq "verify") {
			my ($time,$verdict,$word,$from,$to);
			if ($#line==5){($time,$verdict,$word,$from,$to) = ($line[1],$line[2],$line[3],$line[4],$line[5])};
			if ($#line==4){($time,$verdict,$word,$from,$to) = ($line[1],$line[2],$line[3],$line[4],"")};
			if ($#line==3){($time,$verdict,$word,$from,$to) = ($line[1],$line[2],$line[3],"","")};
			#print "[$time],[$verdict],[$word],[$from],[$to]\n";
			my %res=(); my $status=0;
			if ($verdict==1) {
				compare_words($from,$to,%res);
				my $strlen = length $word;
				my $status = 0;
				print "$time;1;$status;$res{'total'};$strlen\n";
			} else {
				print "$time;$verdict\n";
			}	
		}
	}
	close LH
}


#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------
