package g2pDo;

use g2pFiles;
use g2pArchive;
use g2pDict;
use g2pAlign;
use g2pRules;
use g2pSound;
use g2pShow;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;

	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw(&do_wlist_fromdict &load_file &import_file &wlist_frommaster &run_g2p &gen_rules &prep_continuous);
}

#--------------------------------------------------------------------------

sub do_wlist_fromdict($$) {
	my ($max,$test) = @_;
	print "-- Enter do_wlist_fromdict $max, $test\n" if $debug;
	my $n = fwlist_fromdict($max,$test,"$cdir/$pt","$cdir/$wt");
	addstate("auto;$wt;$pt.first.$max.$test.$n");
	store_file($wt);
	return $n;
}

#--------------------------------------------------------------------------

sub load_file($$) {
	my ($fname,$ftype) = @_;
	print "-- Enter load_file $fname, $ftype\n" if $debug;
	`cp $adir/$fname $cdir/$ftype`; 
	addstate("load;$ftype;$fname");
	store_file($ftype);
	return 0;
}


sub import_file($$) {
	my ($ftype,$fh) = @_;
	print "-- Enter import_file: $ftype, copy $fh to $cdir/$ftype\n" if $debug;
	open IH, ">:encoding(utf8)","$cdir/$ftype" or die;
	while (<$fh>) { print IH }
	close IH; close $fh;
	addstate("import;$ftype;$fh");
	store_file($ftype);
	return 0;
}

#--------------------------------------------------------------------------

#run_g2p - updates current prdict
sub run_g2p(){
        print "-- Enter run_g2p: $cdir/$wt\n $cdir/$pt\n" if $debug;
        local (%dict,%stat,%olddict,%oldstat,%gnulls);
	fread_rules("$cdir/$rt");
	fread_gnull_list("$cdir/$mpt.gnulls",%gnulls);
        g2p_wordlist("$cdir/$wt",%gnulls,%dict,%stat);
        fread_dict("$cdir/$mpt",%olddict,%oldstat);
        add_stat(%dict,%stat,%olddict,%oldstat);
        #while ( ($w,$s) = each %dict ) { print "<p> New after: $w $s $stat{$w}" }
        fwrite_dict("$cdir/$pt",%dict,%stat);
        addstate "auto;prdict;dec";
        store_file($pt);
}


sub gen_rules() {
        print "-- Enter gen_rules" if $debug;
        #local (%dict,%agd,%apd,@graphs,%gwords);
        $dname = "$cdir/$mpt"; my $rtype = "win_min";
        fgen_rules($dname,0,"$dname.aligned","$dname.gnulls");
        fwrite_rules("$cdir/$rt");
        addstate "auto;rules;$mpt.$rtype.noprealign";
        store_file($rt);
}

sub prep_continuous() {
        my $dname = "$cdir/$mpt";
        my $wname = "$cdir/$wt";
	my $mname = "$cdir/$mwt";
	my $otype = 'mostFrequent';

	if ($otype eq 'mostFrequent') { $exact=0 }
	elsif ($otype eq 'growingContext') { $exact=1 }
	else { die "Unknown ordering type\n" }
        print "-- Enter prep_continuous $dname, $mname, $rtype, $cmax,$otype,$exact,$wname\n" if $debug;

	print "Write all unknown contexts\n";
	local %chash=(); local %dict=(); local %stat=();
	fread_dict($dname,%dict,%stat);
        fextract_contexts($wname,1,$cmax,%chash);
	frm_certain_contexts(%stat,%chash,$cmax);
        fwrite_contexts("$wname.context",%chash,$cmax,$exact);
	addstate "prep;contexts;1-3";

        print "<p>Generate new rule set\n";
        fgen_rules($dname,0,"$dname.aligned","$dname.gnulls");
        fwrite_rules("$cdir/$rt");
        addstate "auto;rules;$pt.$rtype.noprealign";
        store_file($rt);

	print "<p>Generating new full dict\n";
	run_g2p;
	fadd_dict("$cdir/$pt","$cdir/$mpt");
	addstate("add;$mpt;$pt");
	store_file($mpt);
}

#--------------------------------------------------------------------------

sub wlist_frommaster($$) {
	my ($max,$otype) = @_;
	print "-- Enter wlist_frommaster: $max,$otype\n" if $debug;
	my $mname = "$cdir/$mwt";
	my $wname = "$cdir/$wt";
	my $dname = "$cdir/$mpt";
	my $tsize=0;
	if ($otype eq 'predict') {
		$tsize = fwlist_frommaster_predict($mname,"$mname.context",$dname,$max,'mostFrequent',0,$wname);
	} else {
		$tsize = fwlist_frommaster($mname,$dname,$max,$otype,$wname);
	}
	addstate("auto;words;$mwt.$otype.$max.$tsize");
	store_file($wt);
	return $tsize;
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------
