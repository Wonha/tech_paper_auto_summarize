#!/usr/bin/perl
use strict;

use MeCab;

my $sentence = "本稿では自動要約システムの誤り分析の枠組みを提案する";

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
