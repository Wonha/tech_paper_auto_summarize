package GlobalTF;
use strict;
use utf8;

use open IO=> ':encoding(utf8)';
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use lib qw(lib);
use Storable qw(nstore retrieve);

use CabCommon ':all';

use Exporter 'import';
our @EXPORT_OK = qw(
	make_global_tf_table
	dump_global_tf_table
	make_tf_idf_table
	dump_tf_idf_table
	calc_tf_idf_score
	dump_high_tf_idf_sent
);
our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
);


### input 1  : reference to the global tf hash
### input 2  : reference to hash for document frequency
### input 3  : log directory to current file
### output 1 : global tf table into input 1
### output 2 : document frequency table into input 2
sub make_global_tf_table {
	my ($global_tf, $doc_freq, $log_dir) = @_;

	my $local_tf_path = File::Spec->catfile($log_dir, "local_tf");
	my $local_tf = retrieve $local_tf_path;

	for (keys %$local_tf) {
		$global_tf->{$_} += $local_tf->{$_};
		$doc_freq->{$_}++;
	}
}


### input 1  : reference to the global tf hash
### input 2  : path to log directory 
### output 1 : dump global_tf into './logs/global_tf' in format of hash reference
sub dump_global_tf_table {
	my ($global_tf, $log_dir) = @_;
	
	my $out_path = File::Spec->catfile($log_dir, "global_tf");
	nstore $global_tf, $out_path;
### debug
#	open my $fh, '>', 'global_tf_test' or die "Can't open tf_idf_test: $!";
#	print $fh "$_ : $global_tf->{$_}\n" for (keys %$global_tf);
#	close $fh;
###
}


### input 1  : reference to tf idf table hash for this file
### input 2  : reference to global tf table hash
### input 3  : reference to document frequency hash
### input 4  : total number of document 
### input 5  : scalar for log directory
### output 1 : tf idf table for this file into input 1
sub make_tf_idf_table {
	my ($tf_idf, $global_tf, $doc_freq, $doc_total, $log_dir) = @_;

	my $local_tf_path = File::Spec->catfile($log_dir, "local_tf");
	my $local_tf = retrieve $local_tf_path;

	for (keys %$local_tf) {
		$tf_idf->{$_} = $local_tf->{$_} * log ($doc_total / $doc_freq->{$_}) / log 10;
	}
}


### input 1  : reference to tf idf table hash for this file
### input 2  : path to log directory
### output 1 : dump tf idf of this file into log directory
sub dump_tf_idf_table {
	my ($tf_idf, $log_dir) = @_;

	my $out_path = File::Spec->catfile($log_dir, "tf_idf");
	nstore $tf_idf, $out_path;
}


### output 1 : tf_idf_score to struct and store in file
sub calc_tf_idf_score {
	my ($tf_idf, $log_dir) = @_;

	my $struct_path = File::Spec->catfile($log_dir, "struct");
	my $struct = retrieve $struct_path;

	for my $i (0..$#{$struct->[0]}) {
		$struct->[0][$i]{tf_idf_score} += $tf_idf->{$_} for (keys %{$struct->[0][$i]{morpheme}});
	}

	for my $i (0..$#{$struct->[0]}) {
		$struct->[0][$i]{tf_idf_score} = sigmoid($struct->[0][$i]{tf_idf_score});
	}

	nstore $struct, $struct_path;
}


### output 1 : dump high scored sent by tf idf scoring into 'sum_tf_idf'
sub dump_high_tf_idf_sent {
	my ($log_dir) = @_;
	my $struct_path = File::Spec->catfile($log_dir, "struct");
	my $struct = retrieve $struct_path;

	my $out_path = File::Spec->catfile($log_dir, "sum_tf_idf");
	open my $fh, '>', $out_path or die "Can't open $out_path: $!";

	for my $i (1..$#$struct) {
		my $start_idx = $struct->[$i]{start};	
		my $end_idx = $struct->[$i]{end};	

		my @sorted_idx = sort { 
			$struct->[0][$b]{tf_idf_score} <=> $struct->[0][$a]{tf_idf_score} 
		} $start_idx..$end_idx;
#print "@sorted_idx\n";

		print $fh "================================================================\n";
		print $fh "[section type  : $struct->[$i]{type}]\n";
		print $fh "[section title : $struct->[$i]{title}]\n";
		print $fh "================================================================\n";
		my @sorted_high_idx = sort { $a <=> $b } @sorted_idx[0..2]; 
		for (0..$#sorted_high_idx) {  
			shift @sorted_high_idx if (not defined $sorted_high_idx[$_])
		}
		for (@sorted_high_idx) {
			printf $fh "[i:%d, score:%5.5f] ", $_, $struct->[0][$_]{tf_idf_score};
			print $fh "$struct->[0][$_]{sent}\n";
		}

		if ( defined $struct->[$i]{subsec} ) {
			for my $j (0..$#{$struct->[$i]{subsec}}) {
				my $start_idx = $struct->[$i]{subsec}[$j]{start};	
				my $end_idx = $struct->[$i]{subsec}[$j]{end};	
				my @sorted_idx = sort { 
					$struct->[0][$b]{tf_idf_score} <=> $struct->[0][$a]{tf_idf_score} 
				} $start_idx..$end_idx;

				print $fh "-----------------------------------------------------\n";
				print $fh "  [subsection title : $struct->[$i]{subsec}[$j]{title}]\n";
				print $fh "-----------------------------------------------------\n";
				printf $fh "  [i:lead, score:%5.5f] ", $struct->[0][$start_idx]{tf_idf_score};
				print $fh "$struct->[0][$start_idx]{sent}\n";
				print $fh ".....\n";
				my @sorted_high_idx = sort { $a <=> $b } @sorted_idx[0..2]; 
				for (0..$#sorted_high_idx) {  
					shift @sorted_high_idx if (not defined $sorted_high_idx[$_])
				}
				for (@sorted_high_idx) {
					printf $fh "  [i:%d, score:%5.5f] ", $_, $struct->[0][$_]{tf_idf_score};
					print $fh "$struct->[0][$_]{sent}\n";
				}
			}
		}
		print $fh "\n";
	}
	close $fh;
}
