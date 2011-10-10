package g2pShow;

use CGI qw(:standard *table);
use g2pFiles;
use g2pArchive;
use g2pSound;
use g2pRules;
use g2pDict;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;
	$eroot = url;
	$eroot =~ s/\/[^\/]*$//;

	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&show_archive &print_status &print_expstat &print_top &show_rules &show_result &show_sounds $eroot &show_param &show_stable &show_correct1 &show_correct2 &show_listen &show_soundButton );
}


#--------------------------------------------------------------------------

sub show_param() {
	my @names = param;
	print "Values passed: @names\n";
	foreach $n (@names){ $v=param($n);print "$n=$v\n"}
}

#show_archive -> uses global @archive
sub show_archive() {
	my $aname = "$lname/$ename";
	print "-- Enter show_archive $aname\n" if $debug;
	print h3("Language: ".em($lname));
	print h3("Experiment: ".em($ename));
	if ($#archive < 0) {
		print p("New experiment - no data in archive.");
	} else {
		print start_table({-border=>undef});
		print Tr(th(["State","Action","Updated","Info"]));
		foreach my $state (@archive) {
			my @toprint; my @info = split /;/,$state;	
			foreach my $item (@info) {push @toprint,td($item) }
			print Tr("@toprint");
		}
	print end_table;
	}
}

sub print_status() {
        print h2("Current status");
        read_archive;
        show_archive;
	print p,hr;
        return;
}

sub print_expstat {
	local (%dict,%estat); 
	fcount_dict("$cdir/$mpt",%estat);
	if ($cutoff>$estat{$verdictValue{'Correct'}}) { $phase = 1 }
	else { $phase = 2 }
	print h2("Current status");
	print start_table;
	print Tr(td("Number correct:"),td($estat{$verdictValue{'Correct'}}));
	print Tr(td("Number wrong:"),td($estat{$verdictValue{'Wrong'}}));
	print Tr(td("Number not sure of:"),td($estat{$verdictValue{'Uncertain'}}));
	print Tr(td("Multiple pronunciations:"),td($estat{$verdictValue{'Ambiguous'}}));
	print Tr(td("Number not yet verified:"),td($estat{$verdictValue{'Notverified'}}));
	print Tr(td("Invalid words:"),td($estat{$verdictValue{'Invalid'}}));
	print Tr(td("Total words:"),td($estat{'total'}));
	print Tr(td("Phase:"),td($phase));
	print end_table;
}

sub print_top {
	print h2(em("DictionaryMaker"));
}

#show_rules - uses global %context,%rule
sub show_rules() {
	print "-- Enter show_rules\n" if $debug;
	foreach my $g (sort keys %context){
		my @gcont = @{$context{$g}};
		foreach my $i (0 .. $#gcont){
			print " [$gcont[$i] -> $rule{$gcont[$i]}] ";
		}
	}
}

sub show_result(\%) {
	my $resultp = shift @_;
	print "-- Enter show_result" if $debug;
	my @s = split / /,$resultp->{same};
	my @d = split / /,$resultp->{diff};
	my @m = split / /,$resultp->{missing};
	my @e = split / /,$resultp->{extra};
	my $t = $#s+$#d+$#m+3 ; my $s = $#s+1; my $m = $#m+1; my $e = $#e+1;
	my $matched = $t-$m;
        my $acc; if ($t==0) { $acc=0 } else { $acc=$s/$t*100;}
        my $macc; if ($matched==0) { $macc=0 } else { $macc=$s/$matched*100 } 

	print h2("Results");
	print sprintf "%s%.2f%s","Accuracy: ",$acc," ( $s / $t )";
	print sprintf "%s%.2f%s","Matched accuracy: ",$macc," ( $s / $matched )";
	print p,"Missing: $m",p,"Extra: $e";
	print h2("Detail:");
	print "Diff: @d",p,"Extra: @e",p,"Missing: @m", p,"Same: @s";
}


sub show_soundButton($$$$) {
	my ($w,$h,$text,$fname) = @_;
	print "-- Enter show_soundButton $w,$h,$text,$fname\n" if $debug;
	print "<applet width=$w height=$h code=PictButton.class\n";
	print "codebase=http://127.0.0.1/g2pdocs/ archive=PictButton.jar>\n";
	print "<param name=text value=$text>\n";
	print "<param name=wavFile value=$fname>\n";
	print "</applet>";

}

sub show_sounds(){
	local %sounds;
	read_sounds(%sounds);
        open CATS,"<:encoding(utf8)",$catt or die;
        my $max = 7; my @tdarray;
        #print start_table({-border=>undef});
        print start_table;
        while (<CATS>) {
                @tdarray = (); chomp;
                @line = split ";";
	        #push @tdarray, td($line[0]);
	        foreach my $i (1 .. $max) {
                        if (exists $line[$i]) {
                                $p = $line[$i];
				if (exists $sounds{$p}) {
                                	$pname = $sounds{$p}->[0];
                                	$pfile = "$sroot/".$sounds{$p}->[1].".wav";
                                	$peg = $sounds{$p}->[2];
                                	$pegfile = "$sroot/$peg.wav";
                                	push @tdarray, td({-bgColor=>"Moccasin"},"<a href=$pfile> $pname </a>");
                                	push @tdarray, td("<a href=$pegfile> $peg </a>");
				} else {
					push @tdarry, td([$p," "]);
				}
                        } else {
                                push @tdarray, td(" ");
                                push @tdarray, td(" ");
                        }

               }
               print Tr(@tdarray);
      }
      print end_table;
      close CATS;
}


#--------------------------------------------------------------------------

sub show_stable($){
	my $tname = shift @_;
	print start_table({-align=>'left'});
	open CATS,"<:encoding(utf8)",$catt or die;
	my $max = 7; 
	while (<CATS>) {
		chomp;
		@line = split ";";
		@tdarray = (td({-width=>150}," "));
		foreach my $i (1 .. $max) {
			if (exists $line[$i]) {
			$p = $line[$i];
			$pname = $sounds{$p}->[0];
			$pfile = "$sroot/".$sounds{$p}->[1];
			push @tdarray, td({-align=>'center',-bgColor=>"Moccasin"},"<button name=$tname value=$p type=submit> $pname </button>");
			} else {
				push @tdarray, td({-bgColor=>"Moccasin"}," ");
			}
		}
		print Tr(@tdarray);
	}
	close CATS;
	print end_table;
}


sub show_correct1($$) {
	my ($word,$sound) = @_;
	print "-- Enter show_correct $word $sound\n" if $debug;
	local (%sounds,@phones,@snd,@phn,@nsnd,@nphn); 
	my ($newsound,$stable,$p1x,$p2x);

	if (!param('newsound')) {$newsound=$sound}
	else {$newsound=param('newsound')}

	print startform({-name=>'correct',-method=>'POST',-target=>'status'});
	$stable=0;
	if (param('p1')){
		$stable=1; $p1x=param('p1');
		if (param('p2')){
			$p1x =~ s/P//;
			$stable=0;
			$p2x=param('p2');
			my $len = length $newsound; my ($l,$r);
			if ($p2x eq 'add'){
				$l = substr $newsound,0,$p1x+1;
				$r = substr $newsound,$p1x+1,$len-$p1x-1;
				$newsound = $l . " " .$r;
				$stable=1; $p1x=$p1x+1;
				param('p1',"P$p1x");
				print "add $newsound\n" if $debug;
				print hidden({-name=>'p1'});
			}elsif($p2x eq 'del'){
				$l = substr $newsound,0,$p1x;
				$r = substr $newsound,$p1x+1,$len-$p1x-1;
				$newsound = $l . $r;
				print "del $newsound\n" if $debug;	
			}else{
				$l = substr $newsound,0,$p1x;
				$r = substr $newsound,$p1x+1,$len-$p1x-1;
				$newsound = $l . $p2x .$r;
				print "change $newsound\n" if $debug;	
			}
		}else{
			param('p1',$p1x);
	                print hidden(-name=>'p1');
		}
	}

	if ($newsound !~ /^ .*$/) {$newsound=" ".$newsound;}
	@newsnd = split //,$newsound;
	read_sounds(%sounds);
	mk_phon(%sounds,@newsnd,@newphn);

	param(-name=>'newsound',-value=>$newsound);
	print hidden({-name=>'word',-default=>$word});
	print hidden({-name=>'sound',-default=>$sound});
	print hidden({-name=>'newsound',-default=>$newsound});
	
	$newsound =~ s/ //g;
	#my $fname = &g2pSound::create_sound($word,$newsound);
	my $fname = create_sound($word,$newsound);
	
	print start_table({-align=>'left'});
	my @tdarray = (td([$word,"->"]));
	if (!$stable) { 
		foreach my $i (0..$#newsnd) {
			push @tdarray, td({-width=>30,-height=>30,-bgColor=>"LightGray"},"<button name=p1 value=P$i type=submit> $newphn[$i] </button>");
		} 
		print Tr(@tdarray,td("  ",submit('OK'),submit('Cancel')));
		print end_table;
	} else {
		foreach my $i (0..$#newsnd) {
			if (($p1x =~ /^P$i$/)||($p1x=~/^$i$/)) {
				push @tdarray, td({-width=>30,-height=>30,-align=>'center',-bgColor=>"Moccasin"}," $newphn[$i] ");
			}else{
				push @tdarray, td({-width=>30,-height=>30,-align=>'center',-bgColor=>"LightGray"}," $newphn[$i] ");
			}
		} 
		print Tr(@tdarray,td("       ",submit('OK'),submit('Cancel')));
		print end_table,br,p;
		print start_table({-align=>'left'});
		print Tr(td({-bgColor=>"Moccasin"},"<button name=p2 value=add type=submit> Add </button>"),
			td({-bgColor=>"Moccasin"},"<button name=p2 value=del type=submit> Delete </button>"));
		print end_table,br,p;
		show_stable('p2');
	}

	print endform;
}

#--------------------------------------------------------------------------

sub show_correct2($$$$) {
	my ($word,$sound,$newsound,$dogen) = @_;
	print "-- Enter show_correct $word,$sound,$newsound\n" if $debug;
	local (%sounds,@phones,@snd,@phn,@nsnd,@nphn); 
	my ($p1chosen,$p1x,$p2x);

	print startform({-name=>'correct',-method=>'POST',-target=>'status'});
	param(-name=>'sound',-value=>$sound);
	param(-name=>'word',-value=>$word);
	param(-name=>'newsound',-value=>$newsound);

	if (!(param('currentp1'))) {
		$p1x = 0;
	}else{
		$p1x = param('currentp1');
		$p1x =~ s/P//;
	}
	
	if (param('p1')){
		$p1x = param('p1');
		$p1x =~ s/P//;
	}

	if (param('p2')){
		$p2x=param('p2');
		my $len = length $newsound; my ($l,$r);
		if ($p2x eq 'add'){
			$l = substr $newsound,0,$p1x+1;
			$r = substr $newsound,$p1x+1,$len-$p1x-1;
			$newsound = $l . " " .$r;
			$p1x=$p1x+1;
			print "add $newsound at [P$p1x]\n" if $debug;	
		}elsif($p2x eq 'del'){
			$l = substr $newsound,0,$p1x;
			$r = substr $newsound,$p1x+1,$len-$p1x-1;
			$newsound = $l . $r;
			$p1x=$p1x-1;
			print "del $newsound\n" if $debug;	
		}else{
			$l = substr $newsound,0,$p1x;
			$r = substr $newsound,$p1x+1,$len-$p1x-1;
			$newsound = $l . $p2x .$r;
			print "change $newsound\n" if $debug;	
		}
	} 
	param('currentp1',"P$p1x");
	print hidden(-name=>'currentp1');

	if ($newsound !~ /^ .*$/) {$newsound=" ".$newsound;}
	@newsnd = split //,$newsound;
	read_sounds(%sounds);
	mk_phon(%sounds,@newsnd,@newphn);

	param(-name=>'newsound',-value=>$newsound);
	print hidden({-name=>'word',-default=>$word});
	print hidden({-name=>'sound',-default=>$sound});
	print hidden({-name=>'newsound',-default=>$newsound});

	my $fname;
	if ($dogen) {
		$newsound =~ s/ //g;
		$fname = create_sound($word,$newsound);
		write_tlog("Generate","[$word][$newsound]");
	}

	print start_table({-align=>'left'});
	my @tdarray = td({-width=>150,-align=>'right'},"$word -> ");
	foreach my $i (0..$#newsnd) {
		if (($p1x =~ /^P$i$/)||($p1x=~/^$i$/)) {
			push @tdarray, td({-width=>30,-height=>30,-bgColor=>"Moccasin"},"<button name=p1 value=P$i type=submit> $newphn[$i] </button>");
		}else{
			push @tdarray, td({-width=>30,-height=>30,-bgColor=>"LightGray"},"<button name=p1 value=P$i type=submit> $newphn[$i] </button>");
		}
	}

	print Tr(@tdarray);
	print end_table;
	if ($dogen) {
		show_soundButton(75,40,"Play","$sroot/tmp/$ename/$fname");
	}else{
		print "<table><tr height=30><td><button name=dogen value=1 type=submit> Generate </button></td></tr></table>"
	}
	print br({-clear=>'left'}),hr;

	show_stable('p2');
	print start_table({-align=>'left',-border=>undef});
	print Tr(td({-align=>'center',-bgColor=>"Moccasin"},"<button name=p2 value=add type=submit> Add </button>"));
	print Tr(td({-align=>'center',-bgColor=>"Moccasin"},"<button name=p2 value=del type=submit> Delete </button>"));
	print end_table;

	print br({-clear=>'left'}),hr;
	print start_table({-align=>'left'});
	print "<tr><td width=150> </td><td>\n";
	param(-name=>'verdict',-value=>'Correct');
	foreach $name ('Correct','Uncertain','Ambiguous','Invalid') {
		print radio_group({-name=>'verdict',-values=>$name,-default=>'Correct',-linebreak=>'true'});
	}
	print "</td><td width=150 align=center>";
	print submit('Done!');
	print submit('Cancel');
	print "</td></tr>";
	print end_table;
	print endform;
	print br({-clear=>'left'}),hr;
}

sub show_listen(){
	print "-- Enter show_listen\n" if $debug;
	local %sounds;
	read_sounds(%sounds);
	print start_table;
	open CATS,":encoding(utf8)",$catt or die;
	my $max = 7; 
	while (<CATS>) {
		chomp;
		@line = split ";";
		print "<tr bgColor=Moccasin>";

		foreach my $i (1 .. $max) {
			if (exists $line[$i]) {
			$p = $line[$i];
			$pname = $sounds{$p}->[0];
			$pfile = "$sroot/".$sounds{$p}->[1].".wav";
			print "<td align=center>";
			show_soundButton(50,40,$pname,$pfile);
			print "</td>\n";
			} else {
				print "<td></td>\n";
			}
		}
	}
	close CATS;
	print end_table;
}
	

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

