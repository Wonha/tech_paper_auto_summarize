package CabCommon;
use strict;
#use warnings;
use v5.10; # using state
use utf8;

use open IO=> ':encoding(utf8)';
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

use lib qw(lib);
use MeCab;
use Encode qw(decode);
use File::Basename qw( fileparse basename );
use File::Spec;
use Text::Balanced qw( extract_bracketed );
use Storable qw(nstore retrieve);

use Latex2Text ':all';

use Exporter 'import';
our @EXPORT_OK = qw(
	make_log_dir
	latex_to_section_structure
	dump_sec_file
	analysis_morpheme
	dump_struct
	check_classified_rate
	get_log_dir
	read_all_line
	create_markdown
	sigmoid

	get_rel_summary

	debug_paragraphs
	debug_sections
	debug_struct
	debug_title

	glue_entire_chunk
);
our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
);


use constant { # make keyword list
	TI_INTR       => "はじめに|まえがき|序論|はしがき|背景|緒論",
	TI_RLTDSTDY   => "関連研究",
#	TI_RLTDSTDY => "関連研究|本課題",
	TI_PRPSDMTHD  => "",
	TI_EXPRMNT    => "実験|評価|評価実験|評定実験",
	TI_CNCLSN     => "考察|結論|おわりに|終わりに|結び|むすび|まとめ|あとがき|む　す　び",
};


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


### input : reference for sentence array
### output: reference for all sent in one scalar
sub glue_entire_chunk {
	my $sent_struct = shift;
	my $all_sent;
	$all_sent .= $$sent_struct[$_]{sent} for (0..$#{$sent_struct});
	return \$all_sent;
}


sub sigmoid {
	my $x = shift;
#	my $e = 10**0.43429;
	my $e = 1.003;
	my $res = ((2/(1+$e**(-1*$x)))-1);
	print "sigmoid value has been 1, input value was $x\n" if ($res >= 1);
	return $res;
}


### input 1  : sent_struct
### output 1 : a hash which takes 
###           each morpheme in sentence i as a key,
###           and it's appearence count in sentence i
sub analysis_morpheme {
	my ($sent_struct) = @_;
	my $term;
	my $feature;

	my $model = new MeCab::Model( '' );
	my $c = $model->createTagger();
	for my $i (0..$#$sent_struct) {
		my $score = 0;
		my $compound_noun = '';

		for (my $m = $c->parseToNode($sent_struct->[$i]{sent}); $m; $m = $m->{next}) {
			$term = $m->{surface};
			$term = decode('utf8',$term);
			$feature = $m->{feature};
			$feature = decode('utf8',$feature);
			my $pos = (split ',', $feature)[0];

			if ( ($term =~ /^\w+$/u) && ($term ne '') ) { # filetering special characters
				if ($pos eq '名詞') { # for chaining the compound noun
					$compound_noun .= $term;
				} else {
					if ($compound_noun ne '') {
						$sent_struct->[$i]{morpheme}{$compound_noun}++;
						$compound_noun = '';
					}
					$sent_struct->[$i]{morpheme}{$term}++;
				}
			}

		}

	}
}


### input1  : reference of hash
### input2  : path for output file
### input3  : table name 
### input4  : array reference of first row
### output1 : markdown file
sub create_markdown {
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
	my @sec_name = ('abstract', 'intro', 'related_study', 'proposed_method', 'experiment_result', 'conclusion');

	for (@sec_name) {
		my $out_path = File::Spec->catfile($log_dir, $_);
		unlink $out_path if (-e $out_path);
	}

	for my $name (@sec_name) {
		my $file_name = 'sec_'.$name;
		my $out_path = File::Spec->catfile($log_dir, $file_name);
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
	local $SIG{__WARN__} = sub { warn $_[0]."[[$pth_file]]" }; # turn warning into the fetal error.
	local @ARGV = ( $pth_file );
	return wantarray ? return <> : do { local $/= undef ; return <> };
}


### input   : path to latex file
### output1 : section/paragraph structure
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
	open my $fh_origin, '>', $out_path or die "Can't open $out_path: $!";
	print $fh_origin @all_lines;
	close $fh_origin;

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
			my @paragraphs = split /(?:\n)(?:\h)*(?:\n){1,}/, $result[0];
			my $par_idx = 0;
			for my $par (@paragraphs) {
				my @sent = &LatexToSentencelist($par);
				$struct->[$tail_chunk]{'parag'}[$par_idx++] = $tail_sent;
#print "======================================================$tail_sent\n";
#print "$par\n";
				$struct->[0][$tail_sent++]{'sent'} = $_ for (@sent);
			}

			$struct->[$tail_chunk]{'end'} = --$tail_sent;
			$struct->[$tail_chunk]{'sec_end'} = $struct->[$tail_chunk]{end};

		} elsif ( $sec =~ /\\section(?:\s|\*)*?\{([\d\D]+?)\}/o ) {
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

			my @paragraphs = split /(?:\n)(?:\h)*(?:\n){1,}/, $sec;
			my $par_idx = 0;
			for my $par (@paragraphs) {
				my @sent = &LatexToSentencelist($par);
				$struct->[$tail_chunk]{'parag'}[$par_idx++] = $tail_sent;
#print "======================================================$tail_sent\n";
#print "$par\n";
				next if (!@sent);
#$struct->[0][$tail_sent++]{'sent'} = "" if (!@sent);
				$struct->[0][$tail_sent++]{'sent'} = $_ for (@sent);
			}
			
			$struct->[$tail_chunk]{'end'} = --$tail_sent;
			$struct->[$tail_chunk]{'sec_end'} = $struct->[$tail_chunk]{end};

		} elsif ( $sec =~ /\\subsection(?:\s|\*)*?\{([\d\D]+?)\}/o ) {
			$tail_subsec++;
			$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'title'} = $1;
			$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'start'} = ++$tail_sent;

			my @paragraphs = split /(?:\n)(?:\h)*(?:\n){1,}/, $sec;
			my $par_idx = 0;
			for my $par (@paragraphs) {
				my @sent = &LatexToSentencelist($par);
				$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'parag'}[$par_idx++] = $tail_sent;
				next if (!@sent);
#print "------------------------------------------------------$tail_sent\n";
#print "$par\n";
				$struct->[0][$tail_sent++]{'sent'} = $_ for (@sent);
			}

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


sub debug_struct {
	my $struct = shift;
	for my $n (1..$#$struct) {
		print "\n##################################################################\n";
		print "section in $n's index\n";
		print "type    : $struct->[$n]{type}\n";
		print "title   : $struct->[$n]{title}\n";
		print "start   : $struct->[$n]{start}\n";
		print "end     : $struct->[$n]{end}\n";
		print "sec_end : $struct->[$n]{sec_end}\n";
		print "parag   : @{$struct->[$n]{parag}}\n";

		if ( defined $struct->[$n]{subsec} ) {
			for my $i (0..$#{$struct->[$n]{subsec}}) {
				print "-------------------------------------------------------\n";
				print "subsection in $i's index\n";
				print "title : $struct->[$n]{subsec}[$i]{title}\n";
				print "start   : $struct->[$n]{subsec}[$i]{start}\n";
				print "end     : $struct->[$n]{subsec}[$i]{end}\n";
				print "parag   : @{$struct->[$n]{subsec}[$i]{parag}}\n";
			}
		}
	}
}

sub debug_title {
	my $struct = shift;
	print "\n##################################################################\n";
	for my $n (1..$#$struct) {
		print "type    : $struct->[$n]{type}\n";
		print "title   : $struct->[$n]{title}\n";
		print "\n##################################################################\n";
	}
}


sub debug_sections {
	my $struct = shift;
	use Data::Dumper;
#	print Dumper($struct);
	for my $n (1..$#$struct) {
		print "####################################################################\n";
		print "  type: $struct->[$n]{type}\n";
		print "  section title: $struct->[$n]{title}\n";
		print "####################################################################\n";
		print $struct->[0][$_]{sent}."\n" for ($struct->[$n]{start}..$struct->[$n]{end});
		if ( defined $struct->[$n]{subsec} ) {
			for my $i (0..$#{$struct->[$n]{subsec}}) {
				print "-------------------------------------------------------\n";
				print "  subsection title : $struct->[$n]{subsec}[$i]{title}\n";
				print "-------------------------------------------------------\n";
				for my $j ($struct->[$n]{subsec}[$i]{start}..$struct->[$n]{subsec}[$i]{end}) {
					print $struct->[0][$j]{sent}."\n";
				}
			}
		}
	}


}


### input 1  : struct data structure
### output 1 : print_paragraphs
sub debug_paragraphs {
	my $struct = shift;
### print by paragraphs
	{
		for my $n (1..$#$struct) {
### get start and end position of paragraph in section
print "=============================================\n";
print "  [$struct->[$n]{title}] section\n";
print "  start: $struct->[$n]{start}\n";
print "  end: $struct->[$n]{end}\n";
print "  parag: $struct->[$n]{parag}[$_]\n" for (0..$#{$struct->[$n]{parag}});
print "=============================================\n";

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
print "[start: $par_start, end: $par_end]\n";
### print from start to end position
				for my $m ($par_start..$par_end) {
					print "$struct->[0][$m]{sent}\n";
				}
				print "\n\n";
			}
### get start and end position of paragraph in subsection
			if ( defined $struct->[$n]{subsec} ) {
				for my $sub (0..$#{$struct->[$n]{subsec}}) {
print "---------------------------------------------\n";
print "  title: [$struct->[$n]{subsec}[$sub]{title}]\n";
print "---------------------------------------------\n";
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
print "[start: $par_start, end: $par_end]\n";
### print from start to end position
						for my $m ($par_start..$par_end) {
							print "$struct->[0][$m]{sent}\n";
						}
						print "\n\n";

					}
				}
			}
		}
	}

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


### input 1  : struct
### input 2  : log directory
### input 3  : number of sentence which includes to the Cab
### output 1 : aref which contains elements of highest 'rel_score'ed '$sent_num' sentences index, which is ordered by precedent order for indexing
sub get_rel_summary {
	my ($struct, $log_dir, $sent_num) = @_;
	my $rel_idx = 0;

	for my $i (2..$#$struct) {
		$rel_idx = $i if $struct->[$i]{type} eq 'related_study';
	}

#	print $log_dir."\n";
#	print "$struct->[$rel_idx]{type} from $struct->[$rel_idx]{start} to $struct->[$rel_idx]{sec_end}\n";

### get top ($sent_num) highest rel_score
	my @ordered_high_rel_score_sent_idx = sort {
		$struct->[0][$b]{rel_score} <=> $struct->[0][$a]{rel_score}
	} $struct->[$rel_idx]{start}..$struct->[$rel_idx]{sec_end};

### order ($sent_num) by sentence index
	my $sent_sum_idx = $sent_num - 1;
	my @ordered_precedent_sent_idx = do {
		if (@ordered_high_rel_score_sent_idx <= $sent_num) {
			sort { $a <=> $b } @ordered_high_rel_score_sent_idx;
		}else {
			sort { $a <=> $b } @ordered_high_rel_score_sent_idx[0..$sent_sum_idx];
		}
	};

#	print "@ordered_high_rel_score_sent_idx\n";
#	print "@ordered_precedent_sent_idx\n";
#	print "$struct->[0][$_]{sent}\n" for ($struct->[$rel_idx]{start}..$struct->[$rel_idx]{sec_end});

	return \@ordered_precedent_sent_idx;
}


1;
