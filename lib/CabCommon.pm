package CabCommon;
use strict;
use warnings;
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

use lib qw(lib);
use Latex2Text ':all';

use Exporter 'import';
our @EXPORT_OK = qw(
	read_all_line
	make_log_dir
	latex_to_section
	dump_sec_file
	check_classified_rate
	glue_entire_chunk
	analysis_morpheme
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


### input1   : doc structure
### input2   : path to log directory for this file
### output1  : create 5 classified file, and dump the contents of it
sub dump_sec_file {
	my ($struct, $log_dir) = @_;
	my @file_name = ('abstract', 'intro', 'related_study', 'proposed_method', 'experiment_result', 'conclusion');

	for (@file_name) {
		print $_."\n";
		my $out_path = File::Spec->catfile($log_dir, $_);
		print $out_path."\n";
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
	my ($log_dir) = @_;
	
	state $total = 0;
	state $found_ab = 0;
	state $found_intro = 0;
	state $found_rel = 0;
	state $found_prop = 0;
	state $found_exp = 0;
	state $found_con = 0;

	$total++;
	$found_ab++    if ( -e File::Spec->catfile($log_dir, 'abstract'));
	$found_intro++ if ( -e File::Spec->catfile($log_dir, 'intro'));
	$found_rel++   if ( -e File::Spec->catfile($log_dir, 'related_study'));
	$found_prop++  if ( -e File::Spec->catfile($log_dir, 'proposed_method'));
#	print "$log_dir\n" if (! (-e File::Spec->catfile($log_dir, 'proposed_method')));
	$found_exp++   if ( -e File::Spec->catfile($log_dir, 'experiment_result'));
	$found_con++   if ( -e File::Spec->catfile($log_dir, 'conclusion'));

	open my $fh, '>', 'classified_rate.md' or die "Can't open 'classified_rate.md' : $!";
	print $fh "\n構成要素 | 検出率\n";
	print $fh " --- | ---\n";
	printf $fh "%s%4s", "概要 | ", int ($found_ab/$total*100)."%\n";
	printf $fh "%s%4s", "序論 | ", int ($found_intro/$total*100)."%\n";
	printf $fh "%s%5s", "関連研究 | ", int ($found_rel/$total*100)."%\n";
	printf $fh "%s%4s", "提案手法 | ", int ($found_prop/$total*100)."%\n";
	printf $fh "%s%4s", "実験結果 | ", int ($found_exp/$total*100)."%\n";
	printf $fh "%s%4s", "結論 | ", int ($found_con/$total*100)."%\n";
	close $fh;
}



### sent_struct      : reference to all sent array
### log_dir          : path to log directory of this file
### local_tf_score   : calculate local tf score for each sent of this file or not
### local_tf_dump    : dump tf table (markdown, dump) or not
### tf_idf_score     : calculate tf_idf score for each sent of this file or not
### tf_idf_dump      : dump tf idf table file or not
sub analysis_morpheme {
	my $arg_for = shift;
	my $sent_struct = $arg_for->{sent_struct};
	my $log_dir 		= $arg_for->{log_dir};

	my $term;
	my %local_tf;

	my $model = new MeCab::Model( '' );
	my $c = $model->createTagger();

	for my $i (0..$#$sent_struct) { # for each sent i
		my $local_tf_score = 0;
		for (my $m = $c->parseToNode($sent_struct->[$i]{sent}); $m; $m = $m->{next}) {
			$term = $m->{surface};
			$term = decode('utf8',$term);
			if ( ($term =~ /^\w+$/u) && ($term ne '') ) { # filtering special characters
					$local_tf{$term}++;
					$local_tf_score += $local_tf{$term} if (defined $local_tf{term});
			}
		}
		$sent_struct->[$i]{local_tf_score} = $local_tf_score;
	}

### dump to markdown file
	if ( $arg_for->{local_tf_dump} ) {
		my $out_path = File::Spec->catfile($log_dir, "local_tf.md");
		push my @first_row, &basename($log_dir);
		_create_markdown(\%local_tf, $out_path, "local term", \@first_row);
	}

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


### input : reference for sentence array
### output: reference for all sent in one scalar
sub glue_entire_chunk {
	my $sent_struct = shift;
	my $all_sent;
	$all_sent .= $$sent_struct[$_]{sent} for (0..$#{$sent_struct});
	return \$all_sent;
}


### input: path of file
### output: contents of file on list or one scalar value
sub read_all_line {
	my $pth_file = shift;
	local $SIG{__WARN__} = sub { die $_[0]."[[$pth_file]]" }; # turn warning into the fetal error.
	local @ARGV = ( $pth_file );
	return wantarray ? return <> : do { local $/; return <> };
}


### input: path to latex file
### output: section structure
sub latex_to_section {
### cut head and tail
	my $path_file = shift;
	my @lines = ();
	my $flag = 0;
	for (read_all_line($path_file)) {
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

	return $struct;
}


### input: current file path
### output: none
sub make_log_dir {
	my $cur_file = shift;

	my $logs = './logs';
	mkdir $logs, 0775 || die "Cannot make $logs: $!"	if ( ! -e $logs || (-e _ && (!-d _)));

#print ( fileparse($cur_file, ('.tex')) )[0];

	$logs = File::Spec->catfile($logs, (fileparse($cur_file, ('.tex')))[0]);
	if ( -e -d $logs ) {
		unlink glob "${logs}* ${logs}.*";
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



1;
