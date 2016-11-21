package CabCommon;
use strict;
#use warnings;
use v5.10; # using state
use utf8;
use open IO=> ':encoding(utf8)';
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use MeCab;
use Encode qw(decode);
use File::Basename qw( fileparse basename );
use File::Spec;
use Text::Balanced qw( extract_bracketed );
use Storable qw(nstore retrieve);

use lib qw(lib);
use Latex2Text ':all';
use Exporter 'import';
our @EXPORT_OK = qw(
	glue_entire_chunk
	read_all_line
	make_log_dir
	latex_to_section_structure
	dump_sec_file
	check_classified_rate
	analysis_morpheme

	seperate_paragraph
	count_sent
	get_surface_term_freq
	get_parag_score_by_rel_keyword_matching

	make_local_tf_table
	dump_local_tf_table
	calc_local_tf_score
	dump_high_local_tf_sent

	dump_struct
	get_log_dir

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

use constant { # make keyword list
	TI_INTR       => "はじめに|まえがき|序論|はしがき|背景",
	TI_RLTDSTDY   => "関連研究",
#	TI_RLTDSTDY => "関連研究|本課題",
	TI_PRPSDMTHD  => "",
	TI_EXPRMNT    => "実験|評価|評価実験|評定実験",
	TI_CNCLSN     => "考察|結論|おわりに|終わりに|結び|むすび|まとめ|あとがき|む　す　び",
};


### output 1 : dumping high scored sent by local tf scoring into 'sum_local_tf'
sub dump_high_local_tf_sent {
	my ($struct, $log_dir) = @_;

	my $out_path = File::Spec->catfile($log_dir, "sum_local_tf");
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


### output 1 : dump struct into 'struct'
sub dump_struct {
	my ($struct, $log_dir) = @_;
	my $out_path_marshall = File::Spec->catfile($log_dir, "struct");
	nstore $struct, $out_path_marshall;
}


### input: current file path
### output: path to log directory for this file
sub get_log_dir {
	my $cur_file = shift;
	return File::Spec->catfile('./logs', (fileparse($cur_file, ('.tex')))[0]);
}


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
		$struct->[0][$i]{tf_idf_score} = _sigmoid($struct->[0][$i]{tf_idf_score});
	}

	nstore $struct, $struct_path;
}

sub _sigmoid {
	my $x = shift;
#	my $e = 10**0.43429;
	my $e = 1.003;
	my $res = ((2/(1+$e**(-1*$x)))-1);
	print "sigmoid value has been 1, input value was $x\n" if ($res >= 1);
	return $res;
}


### input : reference for sentence array
### output: reference for all sent in one scalar
sub glue_entire_chunk {
	my $sent_struct = shift;
	my $all_sent;
	$all_sent .= $$sent_struct[$_]{sent} for (0..$#{$sent_struct});
	return \$all_sent;
}


### input 1  : sent_struct
### output 1 : a hash which takes 
###           each morpheme in sentence i as a key,
###           and it's appearence count in sentence i
sub analysis_morpheme {
	my ($sent_struct) = @_;
	my $term;

	my $model = new MeCab::Model( '' );
	my $c = $model->createTagger();

	for my $i (0..$#$sent_struct) {
		my $score = 0;
		for (my $m = $c->parseToNode($sent_struct->[$i]{sent}); $m; $m = $m->{next}) {
			$term = $m->{surface};
			$term = decode('utf8',$term);
			if ( ($term =~ /^\w+$/u) && ($term ne '') ) { # filetering special characters
				$sent_struct->[$i]{morpheme}{$term}++;
			}
		}
	}
}


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
### output 1 : local_tf_score in sent struct
sub calc_local_tf_score {
	my ($sent_struct, $local_tf) = @_;

	for my $i (0..$#$sent_struct) {
		$sent_struct->[$i]{local_tf_score} += $local_tf->{$_} for (keys %{$sent_struct->[$i]{morpheme}});
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
	_create_markdown($local_tf, $out_path_md, "local term", \@first_row);

### dump to file local_tf 
	my $out_path_marshall = File::Spec->catfile($log_dir, "local_tf");
	nstore $local_tf, $out_path_marshall;

}


### input1  : reference of hash
### input2  : path for output file
### input3  : table name 
### input4  : array reference of first row
### output1 : markdown file
sub _create_markdown {
	my ($ref, $out_path, $table_name, $first_row) = @_;

	open my $fh_out, '>', $out_path or die "Can't open $out_path: $!";
### write first two line
	{
		local	$" = ' | ';
		print $fh_out "$table_name | @$first_row\n";
		print $fh_out '--- ', ' | ---' x scalar @$first_row, "\n";
	}
### write contents
	my ($key, $value);
	while ( ($key, $value) = each %$ref ) {
		print $fh_out "$key | $value\n";
	}

	close $fh_out;
}


### input1   : doc structure
### input2   : path to log directory for this file
### output1  : create 5 classified file, and dump the contents of it
sub dump_sec_file {
	my ($struct, $log_dir) = @_;
	my @file_name = ('abstract', 'intro', 'related_study', 'proposed_method', 'experiment_result', 'conclusion');

	for (@file_name) {
		my $out_path = File::Spec->catfile($log_dir, $_);
		unlink $out_path if (-e $out_path);
	}

	for my $name (@file_name) {
		my $out_path = File::Spec->catfile($log_dir, $name);
		for my $i (1..$#$struct) {
			if ($struct->[$i]{type} eq $name) {
				open my $fh, '>>', $out_path or die "Can't open $out_path : $!";
				for ($struct->[$i]{start}..$struct->[$i]{sec_end}) {
					print $fh "$struct->[0][$_]{sent}\n";
				}
				close $fh;
			}
		}
	}
}


### input1   : doc structure
### input2   : output path
sub check_classified_rate {
	my ($log_dir, $fh, $dump_flag) = @_;
	
	state $total = 0;
	state $found_ab = 0;
	state $found_intro = 0;
	state $found_rel = 0;
	state $found_prop = 0;
	state $found_exp = 0;
	state $found_con = 0;

	unless ($dump_flag) {
		$total++;
		$found_ab++    if ( -e File::Spec->catfile($log_dir, 'abstract'));
		$found_intro++ if ( -e File::Spec->catfile($log_dir, 'intro'));
		if ( -e File::Spec->catfile($log_dir, 'related_study')) {
			$found_rel++;   
			{ ### inspect rel study
#				my $base = &basename($log_dir);
#				print $fh "$base matched first rel study\n";
			}
		} else {
			my $base = &basename($log_dir);
			print $fh "$base unmatched first rel study\n";
		}

		$found_prop++  if ( -e File::Spec->catfile($log_dir, 'proposed_method'));
		$found_exp++   if ( -e File::Spec->catfile($log_dir, 'experiment_result'));
		$found_con++   if ( -e File::Spec->catfile($log_dir, 'conclusion'));
	} else {
		print $fh "total: $total\n";
		print $fh "\n構成要素 | 検出率\n";
		print $fh " --- | ---\n";
		printf $fh "%s%4s", "概要 | ", int ($found_ab/$total*100)."%\n";
		printf $fh "%s%4s", "序論 | ", int ($found_intro/$total*100)."%\n";
		printf $fh "%s%5s", "関連研究 | ", int ($found_rel/$total*100)."%\n";
		printf $fh "%s%4s", "提案手法 | ", int ($found_prop/$total*100)."%\n";
		printf $fh "%s%4s", "実験結果 | ", int ($found_exp/$total*100)."%\n";
		printf $fh "%s%4s", "結論 | ", int ($found_con/$total*100)."%\n";
	}
}


### input: path of file
### output: contents of file on list or one scalar value
sub read_all_line {
	my $pth_file = shift;
	local $SIG{__WARN__} = sub { die $_[0]."[[$pth_file]]" }; # turn warning into the fetal error.
	local @ARGV = ( $pth_file );
	return wantarray ? return <> : do { local $/= undef ; return <> };
}


### input   : path to latex file
### output1 : section structure
### output2 : 'origin' file in log directory
sub latex_to_section_structure {
### cut head and tail
	my $path_file = shift;
	my @lines = ();
	my $flag = 0;
	my @all_lines = read_all_line($path_file);
#	print @all_lines;

	my $log_dir = get_log_dir($path_file);
	my $out_path = File::Spec->catfile($log_dir, "origin");
	open my $fh, '>', $out_path or die "Can't open $out_path: $!";
	print $fh @all_lines;
	close $fh;

	for (@all_lines) {
		if (/\\begin\{document\}/o || /\\jabstract\{/o) {
			$flag = 1;
			push(@lines, $_);
			next;
		}
		if (/\\end\{document\}/o || /\\begin\{biography\}/o ||
				/\\bibliographystyle/o || /\\acknowledgment/o) {
			$flag = 0;
			next;
		}
		push(@lines, $_) if $flag;
	}

### make chunk
	my $section = '';
	my @section_list = ();
	my $structure;
	for my $l (@lines) {
		if ($l =~ /\\section\{/o || $l =~ /\\jabstract\{/o || $l =~ /\\subsection\{/o ) {
			push(@section_list, $section) if $section;
			$section = $l;
			next;
		}
		$section .= $l;
	}
	push(@section_list, $section) if $section;
### for debug
#	local $" = "\n################################################################\n";
#	print "@section_list";

### make structure
  my $struct;
	my $tail_sent = -1;
	my $tail_chunk = 0;
	my $tail_subsec = -1;
	my $title;
	for my $sec (@section_list) {
		my @result;
		if ( (not defined $struct->[1]{'type'}) && ($sec =~ s/\\jabstract\{/\{/o) ) {
			$tail_chunk++;
			$struct->[$tail_chunk]{'title'} = "abstract";
			$struct->[$tail_chunk]{'type'} = "abstract";
			$struct->[$tail_chunk]{'start'} = ++$tail_sent;

			@result = extract_bracketed($sec, '{}'); # [0]: matched, [1]: remains
			substr($result[0], 0, 1) = '';	 # omit { 
			substr($result[0], -1, 1) = '';  # omit }
			my @sent = &LatexToSentencelist($result[0]);
			$struct->[0][$tail_sent++]{'sent'} = $_ for (@sent);

			$struct->[$tail_chunk]{'end'} = --$tail_sent;
			$struct->[$tail_chunk]{'sec_end'} = $struct->[$tail_chunk]{end};

		} elsif ( $sec =~ /\\section\{([\d\D]+?)\}/o ) {
			$tail_chunk++;
			$tail_subsec = -1;
			$struct->[$tail_chunk]{'title'} = $title = $1;
			$struct->[$tail_chunk]{'type'} = do {
				if ( $title =~ /.*?(@{[TI_INTR]}).*?/ou ) {
					'intro';
				} elsif ($title =~ /.*?(@{[TI_RLTDSTDY]}).*?/ou) {
					'related_study';
				} elsif ($title =~ /.*?(@{[TI_EXPRMNT]}).*?/ou ) {
					'experiment_result';
				} elsif ($title =~ /.*?(@{[TI_CNCLSN]}).*?/ou ) {
					'conclusion';
				} else {
					'proposed_method';
				}
			};
			$struct->[$tail_chunk]{'start'} = ++$tail_sent;

			my @sent = &LatexToSentencelist($sec);
			$struct->[0][$tail_sent++]{'sent'} = "" if (!@sent);
			$struct->[0][$tail_sent++]{'sent'} = $_ for (@sent);
			$struct->[$tail_chunk]{'end'} = --$tail_sent;
			$struct->[$tail_chunk]{'sec_end'} = $struct->[$tail_chunk]{end};

		} elsif ( $sec =~ /\\subsection\{([\d\D]+?)\}/o ) {
			$tail_subsec++;
			$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'title'} = $1;
			$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'start'} = ++$tail_sent;

			my @sent = &LatexToSentencelist($sec);
			$struct->[0][$tail_sent++]{'sent'} = $_ for (@sent);

			$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'end'} = --$tail_sent;
			$struct->[$tail_chunk]{'sec_end'} = $struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'end'};
		} else {}

	}
	warn "$path_file: abstract not found" if ( not defined $struct->[1]{'type'} );

### process for get related_study paragraph
	$struct->[1]{'rel_parag_start'};
	$struct->[1]{'rel_parag_end'};

	return $struct;
}


### input: current file path
### output: path to log directory for this file
sub make_log_dir {
	my $cur_file = shift;

	my $logs = './logs';
	mkdir $logs, 0775 || die "Cannot make $logs: $!"	if ( ! -e $logs || (-e _ && (!-d _)));

#print ( fileparse($cur_file, ('.tex')) )[0];

	$logs = File::Spec->catfile($logs, (fileparse($cur_file, ('.tex')))[0]);
	if ( -e -d $logs ) {
		unlink glob "${logs}/* ${logs}/.*";
		rmdir $logs;
	} 
	mkdir $logs, 0755 || warn "Cannot make $logs: $!";

	return $logs;
}


### input: 
### output: keyword list in regex form
sub get_keyword_list {
	my $arg = shift;
	if    ($arg eq 'title_intro')             { return TI_INTR;	}
	elsif ($arg eq 'title_related_study')     { return TI_RLTDSTDY; }
	elsif ($arg eq 'title_proposed_method')   { return TI_PRPSDMTHD; }
	elsif ($arg eq 'title_experiment_result') { return TI_EXPRMNT; }
	elsif ($arg eq 'title_conclusion')        { return TI_CNCLSN; }
	else                                      { return; }
}

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
	my $rel_regex2 = qr/
		これ(?:まで|ら)の(?:研究|手法|方法)|
		cite|提案|比較|
		研究|方法|手法
		/uxpm;
	my $rel_regex3 = qr/
		しかし|一方|ただ|
		違い|異なる|異なり|
		(?:で|て)(?:は)?ない|いない|できない
		/uxpm;

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
		$score_parag_a[$idx] = _sigmoid($score_parag_a[$idx])+1;
	}
	return \@score_parag_a;
}


1;
