package CabCommon;
use strict;
use warnings;

use Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( read_all_line );

### input: path of file
### output: contents of file with one scalar value
sub read_all_line {
	my $pth_file = shift;
	local $/;
	local $SIG{__WARN__} = sub { die $_[0]."[[$pth_file]]" }; # turn warning into the fetal error.
	local @ARGV = ( $pth_file );
	return <>;
}

1;
