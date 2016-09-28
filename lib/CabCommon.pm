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
	glue_entire_chunk
	make_local_tf_markdown
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

sub glue_entire_chunk {
	my $sent_struct = shift;
	my $all_sent;
	$all_sent .= $$sent_struct[$_]{sent} for (0..$#{$sent_struct});
	return \$all_sent;
}

### output1 : term frequency's hash reference
### output2 : local_tf_table with markdown format
sub make_local_tf_markdown {
	my ($all_sent_ref, $log_dir) = @_;
	
	my $local_tf = _analysis_morpheme($all_sent_ref);
##### debug
#	my ($key, $value);
#	print "$key : $value\n" while( ($key, $value) = each %$local_tf );
#####

	my $out_path = File::Spec->catfile($log_dir, "local_tf.md");
	push my @first_row, &basename($log_dir);
	_create_markdown($local_tf, $out_path, "local term", \@first_row);

	return $local_tf;
}

### input1  : 
### output1 : term frequency's hash reference
### output2 : local_tf_table with markdown format
sub add_to_global_tf {
	state $global_tf;
	
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


### input1  : scalar reference referring sentence
### output1 : morpheme frequency's hash reference
sub _analysis_morpheme {
	my ($all_sent_ref) = shift;

	my $term;
	my %tf;
	my $model = new MeCab::Model( '' );
	my $c = $model->createTagger();
	for (my $m = $c->parseToNode($$all_sent_ref); $m; $m = $m->{next}) {
		$term = $m->{surface};
		$term = decode('utf8',$term);

### filtering special character
		if ( $term =~ /^\w+$/u ) {
			unless ( $term eq '') {
				$tf{$term}++;
			}
		}
	}
	return \%tf;
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

		} elsif ( $sec =~ /\\section\{([\d\D]+?)\}/o ) {
			$tail_chunk++;
			$tail_subsec = -1;
			$struct->[$tail_chunk]{'title'} = $title = $1;
			$struct->[$tail_chunk]{'type'} = do {
				if ( $title =~ /.*?(@{[TI_INTR]}).*?/ou ) {
					'intro';
				} elsif ($title =~ /.*?(@{[TI_RLTDSTDY]}).*?/ou) {
					'related study';
				} elsif ($title =~ /.*?(@{[TI_EXPRMNT]}).*?/ou ) {
					'experiment result';
				} elsif ($title =~ /.*?(@{[TI_CNCLSN]}).*?/ou ) {
					'result';
				} else {
					'proposed method';
				}
			};
			$struct->[$tail_chunk]{'start'} = ++$tail_sent;

			my @sent = &LatexToSentencelist($sec);
			$struct->[0][$tail_sent++]{'sent'} = "" if (!@sent);
			$struct->[0][$tail_sent++]{'sent'} = $_ for (@sent);
			$struct->[$tail_chunk]{'end'} = --$tail_sent;

		} elsif ( $sec =~ /\\subsection\{([\d\D]+?)\}/o ) {
			$tail_subsec++;
			$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'title'} = $1;
			$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'start'} = ++$tail_sent;

			my @sent = &LatexToSentencelist($sec);
			$struct->[0][$tail_sent++]{'sent'} = $_ for (@sent);

			$struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'end'} = --$tail_sent;

##### update section's {end}
#			$struct->[$tail_chunk]{'end'} = $struct->[$tail_chunk]{'subsec'}[$tail_subsec]{'end'};
#####
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


### input: path of file
### output: contents of file on list or one scalar value
sub read_all_line {
	my $pth_file = shift;
	local $SIG{__WARN__} = sub { die $_[0]."[[$pth_file]]" }; # turn warning into the fetal error.
	local @ARGV = ( $pth_file );
	return wantarray ? return <> : do { local $/; return <> };
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
