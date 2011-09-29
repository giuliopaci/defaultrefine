package g2pSound;

use g2pFiles;

#--------------------------------------------------------------------------

BEGIN {
	# Global vars
	$debug = 0;

	$praat = "/usr/local/bin/praat";

	use Exporter();
	@ISA = qw(Exporter);
	@EXPORT = qw($sdir $sroot &create_sound &read_sounds &mk_phon &clean_sound);
}

#--------------------------------------------------------------------------

sub read_sounds(\%) {
        my $sp = shift @_;
	print "-- Enter read_sounds\n" if $debug;
	%$sp = ();
        open SOUNDS,$sndt or die;
        while (<SOUNDS>) {
                chomp;
                @line = split "_";
                my $p = shift @line;
                @{$sp->{$p}} = @line;
        }
        close SOUNDS;
}

#--------------------------------------------------------------------------

sub mk_phon(\%\@\@) {
	my ($infop,$sp,$pp) = @_;
	print "-- Enter mk_phon @$sp\n" if $debug;
	@$pp = ();
	foreach $i (0 .. $#$sp) {
		$pp->[$i] = $infop->{$sp->[$i]}->[0];
	}
	print "-- Leave mk_phon @$pp\n" if $debug;
}

#--------------------------------------------------------------------------

sub create_sound($$) {
	my ($word,$sound) = @_;
	print "-- Enter create_sound: $word ($sound)\n" if $debug;
	local %sounds;
	read_sounds(%sounds);
	my @toplay = split //,$sound;
	my $name = $word.substr(rand,2,4);

	$outdir = "$sdir/tmp/$ename";
	open PF, ">tmp.praat" or die;
	foreach my $i (0 .. $#toplay) {
		my $phone = $sounds{$toplay[$i]}[1];
		print PF "Read from file... $sdir/$phone.wav\n";
		print PF "Rename... p$i\n";
	}
	print PF "select Sound p0\n";
	foreach my $i (1 .. $#toplay) {
		print PF "plus Sound p$i\n";
	}
	print PF "Concatenate\n";
	print PF "select Sound chain\n";
	print PF "Write to WAV file... $outdir/$name.wav\n";
	`chmod +x tmp.praat`;
	`$praat tmp.praat`;
	`chmod +x $outdir/$name.wav`;
	return "$name.wav";
}

sub clean_sound {
	print "-- Enter clean_sound\n" if $debug;
	$outdir = "$sdir/tmp/$ename";
	my $cmnd = "rm -f $outdir/*.wav";
	`$cmnd`;
}

#--------------------------------------------------------------------------

return 1;

END { }

#--------------------------------------------------------------------------

