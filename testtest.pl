#!/usr/bin/perl
use strict;
use warnings;

my $val1 = 100;

my ($ret1, $ret2) = &sub1({
		par1 => $val1,
		par2 => 200 });

sub sub1 {
	my ($arg_href) = @_;

	print $arg_href->{par1}."\n";
	print $arg_href->{par2}."\n";
}
