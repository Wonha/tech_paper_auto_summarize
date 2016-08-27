#!/usr/bin/perl
use strict;
use utf8;
binmode(STDOUT, ":utf8"); 

$_ = 'ああああああああ | 3.123213';
my %hs = /(\w+) \| (\d+\.?\d*)/gu;
print "$_: $hs{$_}\n" for (keys %hs);
