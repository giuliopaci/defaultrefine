# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl G2P-Core.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use utf8;

use FindBin;
use IO::File;
use Test::More; # tests => 1;

BEGIN { use_ok('G2P::Core') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#use G2P::Core;

my $fh_pat = IO::File->new();
my $fh_rul = IO::File->new();
my $fh_dic = IO::File->new();

eval {
    $fh_pat->open("$FindBin::Bin/data/setswana/tn.pat", '<');
    $fh_rul->open("$FindBin::Bin/data/setswana/tn.rul", '<');
    $fh_dic->open("$FindBin::Bin/data/setswana/tn.dic", '<');
};
if ($@) {
    BAIL_OUT("Failed to open input files: $@");
}

my @patterns;
my %graphemes = ( '0' => 1 );
my $pat_id = 0;

while ( my $line = $fh_pat->getline() ) {
    chomp($line);

    if ( $line =~ /^([^;]);([^;]*\-([^;])\-[^;]*)$/ ) {
        my $graph = $3;
        my $phone = $1;
        my $context = $2;

        if ( !exists($graphemes{$graph}) ) {
            $graphemes{$graph}++;
        }

        push(
            @patterns,
            {
                graph => $graph,
                phone => $phone,
                context => $context,
                id => $pat_id++
            }
        );
    }
    else {
        diag("Invalid pattern: $line");
    }
}

$fh_pat->close();

my @tn_rules;

while ( my $line = $fh_rul->getline() ) {
    chomp($line);

    if ( $line =~ /^[^;];[^;]*;[^;]*;[^;];\d+;\d+$/ ) {
        push(@tn_rules, $line);
    }
    else {
        diag("Invalid rule: $line");
    }
}

$fh_rul->close();

my %words;

while ( my $line = $fh_dic->getline() ) {
    chomp($line);

    if ( $line =~ /^(\S+)\s(\S+)$/ ) {
        my $word = $1;
        my $pronunc = $2;

        $words{$word} = $pronunc;
    }
    else {
        diag("Invalid dictionary entry: $line");
    }
}

$fh_dic->close();

my @rules;

foreach my $graph ( sort keys %graphemes ) {
    G2P::Core::set_grapheme($graph);

    foreach my $pattern ( @patterns ) {
        my $g = $pattern->{graph};

        next if ( $g ne $graph );

        my $phone = $pattern->{phone};
        my $context = $pattern->{context};
        my $id = $pattern->{id};

        # TODO: Check why spaces around $context is needed.
        G2P::Core::add_pattern($id, $phone, " $context ");
    }

    my @new_rules = G2P::Core::generate_rules();

    push(@rules, @new_rules);

    G2P::Core::clear_patterns();
}

#my $fh = IO::File->new();
#
#$fh->open('rules.txt', '>');
#
#foreach my $rule ( @rules ) {
#    $fh->print("$rule\n");
#}
#
#$fh->close();

ok( scalar(@rules) == scalar(@tn_rules), 'Check rule number' );

subtest "Check rule generation" => sub {
    plan skip_all => 'Rule count do not match',
        if ( scalar(@rules) != scalar(@tn_rules) );

    my @test_rules1 = sort @rules;
    my @test_rules2 = sort @tn_rules;

    foreach my $i ( 0 .. $#rules ) {
        # XXX: Rule ordering/id may differ ...
        my($rule1) = ( $test_rules1[$i] =~ /^(.+);\d+;\d+$/ );
        my($rule2) = ( $test_rules2[$i] =~ /^(.+);\d+;\d+$/ );

        ok( $rule1 eq $rule2, "Check rule: $rule1, $rule2" );
    }
};

G2P::Core::set_rules(@rules);

foreach my $word ( sort keys %words ) {
    my $predict = G2P::Core::predict_pronunciation($word);

    ok(
        $predict eq $words{$word},
        "Check word prediction: $word = $words{$word}, $predict"
    );
}

done_testing();


1;
