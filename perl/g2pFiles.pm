package g2pFiles;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;
	$cutoff = 200;
	$cmax = 1000;
	
	#$custom_use = 'context_and_1feat';	#1extra
	$custom_use = 'context_only';		#std
	#$custom_use = 'bio_specific';		#bio

	$homedir = `pwd`; 
	chomp($homedir);
	$homedir = "$homedir/experiments";
	
	sub read_id($){
		my $id = shift @_;
		if (open FH, "<:encoding(utf8)", "$id") { 
			$name = <FH>; chomp $name;
			close FH;
			return $name;
		} else {
			#print "Warning: Error reading $id\n";
		}
	}

	$langid = "$homedir/language";
	$lname = read_id($langid);

	$expid = "$homedir/$lname/expname";
	$ename = read_id($expid);

	$cdir = "$homedir/$lname/$ename/current";
	$adir = "$homedir/$lname/$ename/archive";
	$eroot = "http://127.0.0.1/g2pdocs/sound/$lname";

	#filetype names
	$wt = "words"; 			
	$pt = "prdict";			
	$rt = "rules";
	$mpt = "dictmaster";			
	$mwt = "wordmaster"; 			
	@allft = ($wt, $pt, $rt,$mpt,$mwt);
	$ct = "changed";
	$at = "info";

        #sound specification files
	$grpt = "$cdir/graphs.txt";
        $phnt = "$cdir/phones.txt";
        $sndt = "$cdir/sounds.txt";
        $catt = "$cdir/categories.txt";

	#sound locations
	$sdir = "../../g2pdocs/sound/$lname";
	$sroot = "http://127.0.0.1/g2pdocs/sound/$lname";
	
	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw($custom_use $cutoff $cmax $homedir $expid $langid $lname $ename $cdir $adir $eroot $wt $pt $rt $ct $mpt $mwt @allft $ct $at $grpt $phnt $sndt $catt $sdir $sroot &read_id &write_expid &write_langid &read_graphs &read_phones &verify_file &new_exp &cp_exp &reset_homedir &fread_graphs);
}

#--------------------------------------------------------------------------

sub reset_homedir($) {
	my $dirname = shift @_;
	
	chomp($dirname);
	$homedir = "$dirname";
	
	$langid = "$homedir/language";
	$lname = read_id($langid);

	$expid = "$homedir/$lname/expname";
	$ename = read_id($expid);

	$cdir = "$homedir/$lname/$ename/current";
	$adir = "$homedir/$lname/$ename/archive";
	$eroot = "http://127.0.0.1/g2pdocs/sound/$lname";
}


sub write_langid($) {
	my $lname = shift @_;
	print "-- Enter write_lid: $lname\n" if $debug;
	if (open FH,">:encoding(utf8)","$langid") {
		print FH "$lname";
		close FH;
		return 0;
	}
	return 1;
}

sub write_expid($) {
	my $ename = shift @_;
	print "-- Enter write_expid: $ename\n" if $debug;
	if (open FH,">:encoding(utf8)","$expid") {
		print FH "$ename";
		close FH;
		return 0;
	}
	return 1;
}

#--------------------------------------------------------------------------

sub read_graphs(\@) {
        my $gp = shift @_;
        print "-- Enter read_graphs $grpt\n" if $debug;
        open GH, "<:encoding(utf8)","$grpt" or die "Unable to open $grpt\n";
        while (<GH>) { chomp; push @$gp,$_ }
        print "graphs: @$gp" if $debug;
        close GH;
}


sub fread_graphs($\@) {
        my ($gf,$gp) = @_;
        print "-- Enter read_graphs $grpt\n" if $debug;
        open IH, "<:encoding(utf8)", "$gf" or die "Unable to open $gf\n";
        while (<IH>) { chomp; push @$gp,$_ }
        print "graphs: @$gp" if $debug;
        close IH;
}

sub read_phones(\@) {
        my $pp = shift @_;
        print "-- Enter read_phones $phnt\n" if $debug;
        open PH, "<:encoding(utf8)", "$phnt" or die;
        while (<PH>) { chomp; push @$pp,$_ }
        print "phones: @$pp" if $debug;
        close PH;
}

#--------------------------------------------------------------------------

sub verify_file($\@) {
	my ($ftype,$errlistp) = @_;
	print "-- Enter verify_file $cdir/$ftype\n" if $debug;
	local (@graphs, @phones);
	open IH, "<:encoding(utf8)", "$cdir/$ftype" or die "Cannot open $cdir/$ftype";
	my $err = 0; my ($gstr,$pstr,$tstr); 
	read_graphs(@graphs); $gstr=join ",",@graphs; 
	read_phones(@phones); push @phones,"0"; $pstr=join ",",@phones; 
	while (<IH>) {
		chomp; 
		if (($ftype eq $wt)||($ftype eq $mwt)) {
			$tstr = '^['."$gstr".']+$';
			#print "[$tstr]\n";
		} elsif (($ftype eq $pt)||($ftype eq $mpt)) {
			$tstr = '^['."$gstr".']+;['."$pstr".']*;(1|0|-1|-2|-3|-4)$';
			#print "[$tstr]\n";
		} elsif ($ftype eq $rt) {
			$tstr = '^['."$gstr".'];[ ,'."$gstr".']*;[ ,'."$gstr".']*;['."$pstr".']$';
			#print "[$tstr]\n";
		}
		unless (/$tstr/) { push @$errlistp,$_; $err = 1 }
	}
	return $err;
}

#--------------------------------------------------------------------------

sub new_exp($) {
	$ename = shift @_;
	print "-- Enter new_exp: $ename\n" if $debug;
	my $edir = "$homedir/$lname/$ename";
	if (-e "$edir") { 
		return 1; #"Experiment already exists" 
	} else {
		`mkdir $edir`;
		$adir = "$edir/archive";
		$cdir = "$edir/current";
		`mkdir $adir`;
		`mkdir $cdir`;
		if (! -e "$sdir/tmp") { `mkdir $sdir/tmp` }
		`mkdir $sdir/tmp/$ename`;
		`echo "0;create;words.rules.prdict.dictmaster.wordmaster;-" > "$adir/$at"`;
		foreach my $ft (@allft) {
			`touch "$adir/$ft.0"`;
			`cp "$adir/$ft.0" "$cdir/$ft"`;
			`touch "$cdir/$ct"`;
		}
		`cp $homedir/$lname/default/*.txt $cdir`;
		write_expid($ename);
		&g2pArchive::init_tlog();
		return 0;
	}
}


sub cp_exp($$) {
	my ($oldname,$newname) = @_;
	print "-- Enter cp_exp: $homedir/$lname/$newname" if $debug;
	if (-e "$homedir/$lname/$newname") { return 1 } 

	`mkdir "$homedir/$lname/$newname"`;
	`cp -r "$homedir/$lname/$oldname/archive" "$homedir/$lname/$newname/archive"`;
	`cp -r "$homedir/$lname/$oldname/current" "$homedir/$lname/$newname/current"`;
	write_expid($newname);
	if (! -e "$sdir/tmp") { `mkdir $sdir/tmp` }
	if (! -e "$sdir/tmp/$newname") { `mkdir $sdir/tmp/$newname` }

	$ename = $newname;
	$adir = "$homedir/$lname/$ename/archive";
	$cdir = "$homedir/$lname/$ename/current";
	return 0;
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

