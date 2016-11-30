package RelParagMatching;
use strict;
use utf8;

use open IO=> ':encoding(utf8)';
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use lib qw(lib);

use CabCommon ':all';

use Exporter 'import';
our @EXPORT_OK = qw(
	bind_sec_to_parag
	get_score_by_pattern_matching_paragraph
	get_highest_scored_paragraph
	add_rel_score

	bind_sent_to_parag
	make_imitate_struct
	dump_rel_paragraph

	dump_rel_paragraph

	debug_bind_sec_to_parag
	debug_get_score_by_pattern_matching_paragraph
	debug_get_highest_scored_paragraph
	debug_add_rel_score

	debug_bind_sent_to_parag
	debug_make_imitate_struct

	seperate_paragraph
	count_sent
	get_surface_term_freq
	get_parag_score_by_rel_keyword_matching
);
our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
);


### input 1  : var reference for file path
### output 1 : array reference that elem is token(paragraph).
sub seperate_paragraph {
	my ($path_origin) = @_;

	my $contents = read_all_line($path_origin);
#	print $contents;
	my @paragraphs = split /(?:\n)(?:\h)*(?:\n){1,}/, $contents;
#print scalar @paragraphs."\n";
	return \@paragraphs;
}

### input 1  : array ref of paragraphs
### output 1 : array ref of sentence numbers corresponding to arr for paragraphs
sub count_sent {
	my ($parags) = @_;

	my @nums_dots;
	for my $parag (@$parags) {
		my @tmps = $parag =~ /(．|。)/ug;
		my $num_dots = @tmps;
		push @nums_dots, scalar @tmps; 
	}
	return \@nums_dots;
}

### input 1  : arr ref of paragraphs.
### output 1 : arr of hash ref. hash indicates frequency of each term in paragraph.
sub get_surface_term_freq {
	my ($origin_parag_aref) = @_;

	my $model = new MeCab::Model( '' );
	my $c = $model->createTagger();
	my $term;
	my @term_freq_for_parag_aoh; # array of ananomous hash where the hash indicates term frequency for 'surface word'. each index of array is parags in cur doc.
	my $term_freq_for_parag_aohref = \@term_freq_for_parag_aoh;
	for my $idx (0..$#$origin_parag_aref) {
		for (my $m = $c->parseToNode($origin_parag_aref->[$idx]); $m; $m = $m->{next}) {
			$term = $m->{surface};
			$term = decode('utf8',$term);
			if ( ($term =~ /^\w+$/u) && ($term ne '') ) { # filetering special characters
				$term_freq_for_parag_aohref->[$idx]->{$term}++;
			}
		}
	}
	return $term_freq_for_parag_aohref;
}

### input 1  : arr ref of paragraphs, and term freq for paragraph aohref.
sub get_parag_score_by_rel_keyword_matching {
	my ($origin_parag_aref, $term_freq_for_parag_aohref) = @_;
#	my $rel_regex = qr/
#		我々|本(?:研究|手法|論文)|本稿|
#		これ(?:まで|ら)の(?:研究|手法|方法)|
#		cite|提案|比較|
#		研究|方法|手法|
#		しかし|一方|ただ|
#		違い|異なる|異なり|
#		(?:で|て)(?:は)?ない|いない|できない
#		/ux;
#	my $rel_regex2 = qr/
#		これ(?:まで|ら)の(?:研究|手法|方法)|
#		cite|提案|比較|
#		研究|方法|手法
#		/uxpm;
#	my $rel_regex3 = qr/
#		しかし|一方|ただ|
#		違い|異なる|異なり|
#		(?:で|て)(?:は)?ない|いない|できない
#		/uxpm;
	my @score_parag_a;
	for my $idx (0..$#$origin_parag_aref) {
		$score_parag_a[$idx] = 0;
#		for my $key (keys %{$term_freq_for_parag_aohref->[$idx]}) {
			while ( $origin_parag_aref->[$idx] =~ /われわれ|我々|本(?:研究|手法|論文|稿)|特徴|具体/uxpg ) {
				$score_parag_a[$idx] += 10; 
#				print "$origin_parag_aref->[$idx]\n${^MATCH}\n\n";
			}	
			while ( $origin_parag_aref->[$idx] =~ /これ(?:まで|ら)の(?:研究|手法|方法)|cite|提案|比較|研究|方法|手法/uxpg) {
				$score_parag_a[$idx] += 3;
			}	
			while ( $origin_parag_aref->[$idx] =~ /しかし|一方|ただ|違い|異なる|異なり|(?:で|て)(?:は)?ない|いない|できない|でき(?:る|た)/uxpg) {
				$score_parag_a[$idx] += 2;
			}
		$score_parag_a[$idx] = sigmoid($score_parag_a[$idx])+1;
	}
	return \@score_parag_a;
}
### input 1  : $struct
### output 1 : paragraphs in chunk
### output 2 : both end index of each paragraph
sub bind_sent_to_parag {
	my ($struct) = @_;
	my @parag_chunk;
	my $both_end_idx;
	for my $n (2..$#$struct) { # abstract section is not binded
### get start and end position of paragraph in section
		for my $i (0..$#{$struct->[$n]{parag}}) {
			if ( ($struct->[$n]{parag}[$i] == $struct->[$n]{parag}[$i+1]) && (defined $struct->[$n]{parag}[$i+1])) {
				next;
			}
			my $par_start = $struct->[$n]{parag}[$i];
			my $par_end = do {
				if ( defined $struct->[$n]{parag}[$i+1] ) {
					$struct->[$n]{parag}[++$i]-1;
				} else {
					$struct->[$n]{end};
				}
			};
### make paragraph and get both_end_idx
			my $par = "";
			for my $m ($par_start..$par_end) {
				$par .= $struct->[0][$m]{sent};
			}
			push @parag_chunk, $par;
			$both_end_idx->[$#parag_chunk]{start} = $par_start;
			$both_end_idx->[$#parag_chunk]{end} = $par_end;
		}
### get start and end position of paragraph in subsection
		if ( defined $struct->[$n]{subsec} ) {
			for my $sub (0..$#{$struct->[$n]{subsec}}) {
				for my $i (0..$#{$struct->[$n]{subsec}[$sub]{parag}}) {
					if (($struct->[$n]{subsec}[$sub]{parag}[$i] == $struct->[$n]{subsec}[$sub]{parag}[$i+1]) && (defined $struct->[$n]{subsec}[$sub]{parag}[$i+1])) {
						next;
					}
					my $par_start = $struct->[$n]{subsec}[$sub]{parag}[$i];
					my $par_end = do {
						if ( defined $struct->[$n]{subsec}[$sub]{parag}[$i+1] ) {
							$struct->[$n]{subsec}[$sub]{parag}[++$i]-1;
						} else {
							$struct->[$n]{subsec}[$sub]{end};
						}
					};
### make paragraph and get both_end_idx
					my $par = "";
					for my $m ($par_start..$par_end) {
						$par .= $struct->[0][$m]{sent};
					}
					push @parag_chunk, $par;
					$both_end_idx->[$#parag_chunk]{start} = $par_start;
					$both_end_idx->[$#parag_chunk]{end} = $par_end;
				}
			}
		}
	}
	return (\@parag_chunk, $both_end_idx);
}

sub get_score_by_pattern_matching_paragraph {
	my ($origin_parag_aref) = @_;

	my @score_parag_a;
	for my $idx (0..$#$origin_parag_aref) {
		$score_parag_a[$idx] = 0;
#		for my $key (keys %{$term_freq_for_parag_aohref->[$idx]}) {
			while ( $origin_parag_aref->[$idx] =~ /われわれ|我々|本(?:研究|手法|論文|稿)|特徴|具体/ouxpg ) {
				$score_parag_a[$idx] += 10; 
#				print "$origin_parag_aref->[$idx]\n${^MATCH}\n\n";
			}	
			while ( $origin_parag_aref->[$idx] =~ /これ(?:まで|ら)の(?:研究|手法|方法)|cite|提案|比較|研究|方法|手法/ouxpg) {
				$score_parag_a[$idx] += 3;
			}	
			while ( $origin_parag_aref->[$idx] =~ /しかし|一方|ただ|違い|異なる|異なり|(?:で|て)(?:は)?ない|いない|できない|でき(?:る|た)/ouxpg) {
				$score_parag_a[$idx] += 2;
			}
		$score_parag_a[$idx] = sigmoid($score_parag_a[$idx])+1;
	}
	return \@score_parag_a;

}

### input 1  : struct
### input 2  : index of target section
sub bind_sec_to_parag {
	my ($struct, $n) = @_;
	my @parag_chunk;
	my $both_end_idx;
### get start and end position of paragraph in section
	for my $i (0..$#{$struct->[$n]{parag}}) {
		if ( ($struct->[$n]{parag}[$i] == $struct->[$n]{parag}[$i+1]) && (defined $struct->[$n]{parag}[$i+1])) {
			next;
		}
		my $par_start = $struct->[$n]{parag}[$i];
		my $par_end = do {
			if ( defined $struct->[$n]{parag}[$i+1] ) {
				$struct->[$n]{parag}[++$i]-1;
			} else {
				$struct->[$n]{end};
			}
		};
### make paragraph and get both_end_idx
		my $par = "";
		for my $m ($par_start..$par_end) {
			$par .= $struct->[0][$m]{sent};
		}
		push @parag_chunk, $par;
		$both_end_idx->[$#parag_chunk]{start} = $par_start;
		$both_end_idx->[$#parag_chunk]{end} = $par_end;
	}
### get start and end position of paragraph in subsection
	if ( defined $struct->[$n]{subsec} ) {
		for my $sub (0..$#{$struct->[$n]{subsec}}) {
			for my $i (0..$#{$struct->[$n]{subsec}[$sub]{parag}}) {
				if (($struct->[$n]{subsec}[$sub]{parag}[$i] == $struct->[$n]{subsec}[$sub]{parag}[$i+1]) && (defined $struct->[$n]{subsec}[$sub]{parag}[$i+1])) {
					next;
				}
				my $par_start = $struct->[$n]{subsec}[$sub]{parag}[$i];
				my $par_end = do {
					if ( defined $struct->[$n]{subsec}[$sub]{parag}[$i+1] ) {
						$struct->[$n]{subsec}[$sub]{parag}[++$i]-1;
					} else {
						$struct->[$n]{subsec}[$sub]{end};
					}
				};
### make paragraph and get both_end_idx
				my $par = "";
				for my $m ($par_start..$par_end) {
					$par .= $struct->[0][$m]{sent};
				}
				push @parag_chunk, $par;
				$both_end_idx->[$#parag_chunk]{start} = $par_start;
				$both_end_idx->[$#parag_chunk]{end} = $par_end;
			}
		}
	}
	return (\@parag_chunk, $both_end_idx);
}

sub get_highest_scored_paragraph {
	my ($score_parag_aref, $last_parag_idx) = @_;

	my $highest_score_parag_idx = 0;
	for my $idx (1..$last_parag_idx) {
		if ( $score_parag_aref->[$idx] > $score_parag_aref->[$highest_score_parag_idx] ) {
			$highest_score_parag_idx = $idx;
		}
	}

	return $highest_score_parag_idx;

}

### making psudo section (copying paragraph from another struct)
### the title of this psudo section is 'related_study'
### output 1 : imitate related_study struct
### output 2 : tf_idf_score + highest paragraph score
sub make_imitate_struct {
	my ($struct, $parag_score, $both_end_idx, $parag_high_idx) = @_;

	$struct->[$#$struct+1]{type} = 'related_study';
#	$struct->[$#$struct]{start} = do {
#		if ($parag_high_idx >= 2 ) {
#			$both_end_idx->[$parag_high_idx-2]{start}; 
#		} elsif ($parag_high_idx == 1 ) {
#			$both_end_idx->[$parag_high_idx-1]{start}; 
#		} else {
#		 $both_end_idx->[$parag_high_idx]{start}; 
#		}
#	};

	if ($parag_high_idx >= 2 ) {
		$struct->[$#$struct]{start} = $both_end_idx->[$parag_high_idx-2]{start}; 
		push @{$struct->[$#$struct]{parag}}, $both_end_idx->[$parag_high_idx-2]{start};
		push @{$struct->[$#$struct]{parag}}, $both_end_idx->[$parag_high_idx-1]{start};
		push @{$struct->[$#$struct]{parag}}, $both_end_idx->[$parag_high_idx]{start};
	} elsif ($parag_high_idx == 1 ) {
		$struct->[$#$struct]{start} = $both_end_idx->[$parag_high_idx-1]{start}; 
		push @{$struct->[$#$struct]{parag}}, $both_end_idx->[$parag_high_idx-1]{start};
		push @{$struct->[$#$struct]{parag}}, $both_end_idx->[$parag_high_idx]{start};
	} else {
		$struct->[$#$struct]{start} = $both_end_idx->[$parag_high_idx]{start}; 
		push @{$struct->[$#$struct]{parag}}, $both_end_idx->[$parag_high_idx]{start};
	}

	$struct->[$#$struct]{end} = $both_end_idx->[$parag_high_idx]{end}; 
	$struct->[$#$struct]{sec_end} = $both_end_idx->[$parag_high_idx]{end}; 
	$struct->[$#$struct]{title} = "related_study";

	for my $i ($struct->[$#{$struct}]{start}..$struct->[$#{$struct}]{end}) {
		$struct->[0][$i]{rel_score} = $struct->[0][$i]{tf_idf_score} + $parag_score->[$parag_high_idx];
	}

}

sub dump_rel_paragraph {
	my ($log_dir, $struct) = @_;

	my $rel_file = File::Spec->catfile($log_dir, "sec_related_study");
	open my $fh_rel, '>', $rel_file or die "Can't open $rel_file : $!";
	my $rel_idx;
	for my $n (1..$#$struct) {
		if ($struct->[$n]{type} eq 'related_study') {
			$rel_idx = $n;
		} else {
			next;
		}
	}
	print $fh_rel "$struct->[0][$_]{sent}\n" for ($struct->[$rel_idx]{start}..$struct->[$rel_idx]{end});

	close $fh_rel;
}


sub add_rel_score {
	my ($struct, $rel_idx, $parag_score, $parag_high_idx) = @_;
	for my $n ($struct->[$rel_idx]{start}..$struct->[$rel_idx]{end}) {
		$struct->[0][$n]{rel_score} = $struct->[0][$n]{tf_idf_score} + $parag_score->[$parag_high_idx];
	}
}


sub debug_bind_sec_to_parag { 
	my ($struct, $parag_chunk, $both_end_idx) = @_;
	for my $par (0..$#$parag_chunk){
		print "$parag_chunk->[$par]\n";
		print "$struct->[0][$_]{sent}\n" for $both_end_idx->[$par]{start}..$both_end_idx->[$par]{end};
		print "\n";

	}
}


sub debug_add_rel_score {
	my ($struct, $parag_score, $rel_flag, $parag_high_idx) = @_;
	print $struct->[0][$struct->[$rel_flag]{start}]{rel_score}."\n";
	print $struct->[0][$struct->[$rel_flag]{start}]{tf_idf_score}."\n";
	print "$parag_score->[$parag_high_idx]\n";
}


sub debug_bind_sent_to_parag {
	my ($parag_chunk, $both_end_idx, $struct) = @_;
	for my $par (0..$#$parag_chunk){
		print "$parag_chunk->[$par]\n";
		print "$struct->[0][$_]{sent}\n" for $both_end_idx->[$par]{start}..$both_end_idx->[$par]{end};
		print "\n";

	}
}


sub debug_get_score_by_pattern_matching_paragraph {
	my ($parag_chunk, $parag_score) = @_;
	for my $i (0..$#$parag_chunk) {
		print "$parag_chunk->[$i]\nPARAGRAPH SCORE: $parag_score->[$i]\n\n";
	}

}


sub debug_get_highest_scored_paragraph {
	my ($parag_chunk, $parag_score, $parag_high_idx) = @_;
	print "$parag_chunk->[$parag_high_idx]\nPARAGRAPH SCORE: $parag_score->[$parag_high_idx]\n";
}


sub debug_make_imitate_struct {
	my ($struct, $parag_score, $parag_high_idx) = @_;
	print "number of sections : $#$struct\n";
	for my $n (1..$#$struct) {
		print "$struct->[$n]{title}, $struct->[$n]{start}, $struct->[$n]{end}\n";
	}
	for my $i ($struct->[$#{$struct}]{start}..$struct->[$#{$struct}]{end}) {
		print "parag_score : $parag_score->[$parag_high_idx]\n";
		print "tf_idf_score: $struct->[0][$i]{tf_idf_score}\n";
		print "sum         : $struct->[0][$i]{rel_score}\n";
		print "sent        : $struct->[0][$i]{sent}\n";
		print "\n";
	}
}


1;
