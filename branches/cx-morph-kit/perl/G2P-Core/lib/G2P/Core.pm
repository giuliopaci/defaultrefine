package G2P::Core;

use 5.014002;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use G2P::Core ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('G2P::Core', $VERSION);

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

G2P::Core - Perl extension to the C++ G2P library originally written
by Marelie Davel.


=head1 SYNOPSIS

  use G2P::Core;
  
  G2P::Core::set_grapheme($graph);
  G2P::Core::add_pattern($id, $phone, " $context ");
  
  @rules = G2P::Core::generate_rules();
  
  G2P::Core::clear_patterns();
  G2P::Core::set_rules(@rules);
  
  $predicted = G2P::Core::predict_pronunciation($word);


=head1 DESCRIPTION

This module provides an interface to the C++ G2P library originally written
by Marelie Davel.


=head2 EXPORT

None by default.


=head1 METHODS

The following methods are available:

=over 4

=item G2P::Core::set_grapheme($graph);

Set the grapheme for prediction rule generation.

=item G2P::Core::add_pattern($id, $phone, $context);

Add pattern to list of patterns for prediction rule generation.

=item G2P::Core::G2P::Core::generate_rules();

Returns list of rules for given grapheme and patterns.

=item G2P::Core::clear_patterns();

Clears the patterns for the current grapheme. Call before adding
patterns for a different grapheme.

=item G2P::Core::set_rules(@rules);

Update rules with given list.

=item G2P::Core::predict_pronunciation($word);

Returns the predicted pronunciation for the given word.



=head1 SEE ALSO

See the official website for more information: http://code.google.com/p/defaultrefine/


=head1 AUTHOR

Martin Schlemmer, E<lt>mschlemmer.ctxt@gmail.comE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 Martin Schlemmer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
