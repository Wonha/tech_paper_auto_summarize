#!/usr/bin/perl

$test = "hi
my name is 
Fuck!!!
";

@arr = split /\n/, $test;
$" = '//';
print "@arr\n";
