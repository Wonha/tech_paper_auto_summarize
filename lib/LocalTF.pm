package LocalTF;
use strict;
use utf8;

use open IO=> ':encoding(utf8)';
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use lib qw(lib);
use File::Basename qw( fileparse basename );
use File::Spec;
use Storable qw(nstore retrieve);

use CabCommon ':all';

use Exporter 'import';
our @EXPORT_OK = qw(
	make_local_tf_table
	dump_local_tf_table
	calc_local_tf_score
	dump_high_local_tf_sent

	debug_calc_local_tf_score
);
our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
);


### input 1  : sent_struct
### input 2  : reference to local tf hash
### output1 : reference to local tf hash
sub make_local_tf_table {
	my ($sent_struct, $local_tf) = @_;
### make local term frequency hash
	{
		my ($key, $value);
		for my $i (0..$#$sent_struct) {
			while ( ($key, $value) = each %{$sent_struct->[$i]{morpheme}} ) {
				$local_tf->{$key} += $value;
			}
		}
	}
}


### input 1  : sent_struct
### input 2  : log path for this file
### output 1 : dump local tf into local_tf.md
### output 2 : dump local tf into local_tf in format of hash reference
sub dump_local_tf_table {
	my ($local_tf, $log_dir) = @_;

### dump to file local_tf.md
	my $out_path_md = File::Spec->catfile($log_dir, "local_tf.md");
	push my @first_row, &basename($log_dir);
	create_markdown($local_tf, $out_path_md, "local term", \@first_row);

### dump to file local_tf 
	my $out_path_marshall = File::Spec->catfile($log_dir, "local_tf");
	nstore $local_tf, $out_path_marshall;

}


### input 1  : sent_struct
### output 1 : local_tf_score in sent struct
sub calc_local_tf_score {
	my ($sent_struct, $local_tf) = @_;

	for my $i (0..$#$sent_struct) {
		$sent_struct->[$i]{local_tf_score} += $local_tf->{$_} for (keys %{$sent_struct->[$i]{morpheme}});
	}
}


### output 1 : dumping high scored sent by local tf scoring into 'high_local_tf'
sub dump_high_local_tf_sent {
	my ($struct, $log_dir) = @_;

	my $out_path = File::Spec->catfile($log_dir, "high_local_tf_sent");
	open my $fh, '>', $out_path or die "Can't open $out_path: $!";

	for my $i (1..$#$struct) {
		my $start_idx = $struct->[$i]{start};	
		my $end_idx = $struct->[$i]{end};	

		my @sorted_idx = sort { 
			$struct->[0][$b]{local_tf_score} <=> $struct->[0][$a]{local_tf_score} 
		} $start_idx..$end_idx;

		print $fh "================================================================\n";
		print $fh "[section type  : $struct->[$i]{type}]\n";
		print $fh "[section title : $struct->[$i]{title}]\n";
		print $fh "================================================================\n";
		printf $fh "[%d] ", $struct->[0][$sorted_idx[0]]{local_tf_score};
		print $fh "$struct->[0][$sorted_idx[0]]{sent}\n";

		if ( defined $struct->[$i]{subsec} ) {
			for my $j (0..$#{$struct->[$i]{subsec}}) {
				my $start_idx = $struct->[$i]{subsec}[$j]{start};	
				my $end_idx = $struct->[$i]{subsec}[$j]{end};	
				my @sorted_idx = sort { 
					$struct->[0][$b]{local_tf_score} <=> $struct->[0][$a]{local_tf_score} 
				} $start_idx..$end_idx;

				print $fh "-----------------------------------------------------\n";
				print $fh "  [subsection title : $struct->[$i]{subsec}[$j]{title}]\n";
				print $fh "-----------------------------------------------------\n";
				printf $fh "  [%d] ", $struct->[0][$sorted_idx[0]]{local_tf_score};
				print $fh "$struct->[0][$sorted_idx[0]]{sent}\n";
			}
		}
		print $fh "\n";
	}
	close $fh;
}



sub debug_calc_local_tf_score {
	my $struct = shift;
	for my $i (0..$#{$struct->[0]}) {
		print "local tf score for sent [$i] = $struct->[0][$i]{local_tf_score}\n";
	}
}

1;
