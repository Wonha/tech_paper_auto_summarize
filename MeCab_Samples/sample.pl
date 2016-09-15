#!/usr/bin/perl
use strict;

use lib qw(extlib/lib/perl5);
use Text::MeCab;

my $sentence = "太郎はこの木を二郎を見た女性に渡した。{";

my $model = new Text::MeCab::Model( '' );
my $c = $model->createTagger();
my %hash;

for (my $m = $c->parseToNode($sentence); $m; $m = $m->{next}) {
	
	$hash{$m->{surface}}++;
	printf("%s\t%s\n", $m->{surface}, $m->{feature});
}

for (keys %hash) {
	print "$_ : $hash{$_}\n";
}
