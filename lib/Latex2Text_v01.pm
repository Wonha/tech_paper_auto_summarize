package Latex2Text;
use strict;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw(
	LatexToSentencelist
);
our %EXPORT_TAGS = (
	all => \@EXPORT_OK,
);

our(%LatexCommand,%LatexEnv);
our($CITE,$MATH,$SB,$EOS_REGEXP);

our $verbose_flag = 0;

sub LatexToSentencelist {
  my($text)=@_;
  my($i,$tmp);

  ### 前処理
  $text =~ s/[\s\n\r]+/ /go;
  $text =~ s/\$\[\$/[/go;  # $[$ => [
  $text =~ s/\$\]\$/]/go;  # $]$ => ]
  
  ### トークンに分割
  my @token = ();
  foreach $tmp (split(/([\r\n]+|\\\\|\\[\{\}\[\]\(\)\%\#\$\.\,\'\"\^~_& ]|\{|\}|\[|\]|\(|\)|\\[a-zA-Z\*]+|\$\$|\$|~|\\)/,$text)){
    next if $tmp eq '';
    # latexコマンド直後の空白を削除
    next if $tmp =~ /^[ \n]+$/o && $token[$#token] =~ /^\\/o;  
    push(@token,$tmp);
  }

  ### LaTeXコマンドの処理
  &handling_latex_command(\@token,0,$#token);
  
  ### 文の分割
  my $s = '';
  my @block_list = ();
  for($i=0 ; $i <= $#token ; $i++){
    if($token[$i] eq $SB){
      push(@block_list,$s) if $s ne '';
      $s = '';
    }elsif($token[$i] =~ /[\r\n]+/o){
      if($token[$i] =~ /^(\r\n|\n|\r)$/o){	# 改行1つ
	;
      }else{
	push(@block_list,$s) if $s ne '';
	$s = '';
      }
    }else{
      $s .= $token[$i];
    }
  }
  push(@block_list,$s) if $s ne '';

  my @sentence_list = ();
  for($i=0 ; $i <= $#block_list ; $i++){
    $s = '';
    foreach my $c (split(/$EOS_REGEXP/o,$block_list[$i])){
      if($c eq ''){
	next;
      }elsif($c =~ /^$EOS_REGEXP$/o){
	$s .= $c;
	$tmp = &remove_space($s);
	push(@sentence_list,$tmp) if $tmp ne '';
	$s = '';
      }else{
	$s .= $c;
      }
    }
    if($s ne ''){
      $tmp = &remove_space($s);
      push(@sentence_list,$tmp) if $tmp ne '';
    }
  }

  return(@sentence_list);
}

# LaTeX command の処理
#   \underline{\underline{...}} など、一般的には入れ子構造になるので、
#   再帰的に呼び出しで処理する
sub handling_latex_command {
  # $t: token の配列へのポインタ
  # $b_posit, $e_posit: 処理の開始位置と終了位置
  my($t,$b_posit,$e_posit)=@_;
  my($i,$end,$param,$tmp);

  for($i=$b_posit ; $i <= $e_posit ; ){
    if($t->[$i] eq '$'){
      # 数式は特殊なシンボルに置き換え
      $end = &find_symbol($t,$i+1,'$');
      if($end == -1){
	&warning('unbalanced math mode '.$t->[$i+1]);
	$i++;
      }else{
	$t->[$i] = $MATH;
	&remove_token($t,$i+1,$end);
	$i = $end + 1;
      }

    }elsif($t->[$i] eq '\('){
      # 数式は特殊なシンボルに置き換え
      $end = &find_symbol($t,$i+1,'\)');
      if($end == -1){
	&warning('unbalanced math mode '.$t->[$i+1]);
	$i++;
      }else{
	$t->[$i] = $MATH;
	&remove_token($t,$i+1,$end);
	$i = $end + 1;
      }

    }elsif($t->[$i] eq '\[' || $t->[$i] eq '$$'){
      # 独立した数式は文境界に置換
      $tmp = ($t->[$i] eq '\[') ? '\]' : '$$';
      $end = &find_symbol($t,$i+1,$tmp);
      if($end == -1){
	&warning('unbalanced math environment '.$t->[$i+1]);
	$i++;
      }else{
	$t->[$i] = $SB;
	&remove_token($t,$i+1,$end);
	$i = $end + 1;
      }

    }elsif($t->[$i] eq '\item'){
      # \item → 文境界とみなす
      if($t->[$i+1] eq '['){
	$end = &find_close_parenthesis($t,$i+1,'[',']');
	if($end == -1){
	  &warning('no close parenthesis of '.$t->[$i].' is found');
	  $i++;
	}else{
	  $t->[$i] = $SB;
	  &remove_token($t,$i+1,$end);
	  $i = $end + 1;
	}
      }else{
	$t->[$i] = $SB;
	$i++;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'cite'){
      # \cite{...} を特殊なシンボルに置換
      $end = &find_close_optbracket_brace($t,$i+1);
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].' is found');
	$i++;
      }else{
	$t->[$i] = $CITE;
	&remove_token($t,$i+1,$end);
	$i = $end + 1;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'def_macro'){
      # \newcommand などのユーザ定義マクロを削除
      $end = &find_new_macro($t,$i);
      if($end == -1){
	&warning('fail to parse '.$t->[$i]);
	$i++;
      }else{
	&remove_token($t,$i,$end);
	$i = $end + 1;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'accent'){
      # \'e などアクセント記号を削除
      if($t->[$i+1] eq '{'){
	$end = &find_close_brace($t,$i+1);
	if($end == -1){
	  &warning('no close parenthesis of '.$t->[$i].' is found');
	  $i++;
	}else{
	  $t->[$i] = '';  $t->[$i+1] = '';  $t->[$end] = ''; 
	  &handling_latex_command($t,$i+2,$end-1);
	  $i = $end + 1;
	}
      }else{
	$t->[$i] = '';
	$i++;
      }
      
    }elsif($LatexCommand{$t->[$i]} eq 'fonttype'){
      # \tt などのフォントを指定するコマンドの処理
      #   (1){\tt ...}, (2)\tt{...}, (3)\tt の3つパターンがある
      #   (1)は後で処理することにし、(2)と(3)のみ処理する
      if($t->[$i+1] eq '{'){
	$end = &find_close_brace($t,$i+1);
	if($end == -1){
	  &warning('no close parenthesis of '.$t->[$i].' is found');
	  $i++;
	}else{
	  $t->[$i] = '';  $t->[$i+1] = '';  $t->[$end] = ''; 
	  &handling_latex_command($t,$i+2,$end-1);
	  $i = $end + 1;
	}
      }elsif($t->[$i-1] eq '{' ||
	     ($t->[$i-1] eq ' ' && $t->[$i-2] eq '{')){
	# {\tt ...} というタイプは後で処理する
	$i++;
      }else{
	$t->[$i] = '';
	$i++;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'verb'){
      $tmp = $t->[$i+1];	# backup
      if($t->[$i+1] =~ s/^([\|\+\!\@\#\"\/])//o){
	my($j,$s) = &find_end_of_verb_command($t,$i+1,$1);
	if($j == -1){
	  &warning('no end of \verb command is found');
	  $t->[$i+1] = $tmp;
	  $i++;
	}else{
	  $t->[$i] = '';
	  $t->[$j] = $s;
	  $i = $j + 1;
	}
      }else{
	&warning('no separator of \verb command is found');
	$i++;
      }

    }elsif($t->[$i] eq '\def' && $t->[$i+1] =~ /^\\/o && $t->[$i+2] eq '{'){
      # \def{...} を削除
      $end = &find_close_brace($t,$i+2);
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].'is found');
	$i++;
      }else{
	&remove_token($t,$i,$end);
	$i = $end + 1;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'remove_brace' && $t->[$i+1] eq '{'){
      # \command{...} を削除
      $end = &find_close_brace($t,$i+1);
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].' is found');
	$i++;
      }else{
	&remove_token($t,$i,$end);
	$i = $end + 1;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'remove_brace2' && $t->[$i+1] eq '{'){
      # \command{...}{...} を削除
      $end = &find_close_brace($t,$i+1);
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].' is found');
	$i++;
      }else{
	if($t->[$end+1] eq '{'){
	  $end = &find_close_brace($t,$end+1);
	  if($end == -1){
	    &warning('no close parenthesis of '.$t->[$i].' is found');
	    $i++;
	  }else{
	    &remove_token($t,$i,$end);
	    $i = $end + 1;
	  }
	}else{
	  &warning('no 2nd argument of '.$t->[$i].' is found');
	  $i++;
	}
      }

    }elsif($LatexCommand{$t->[$i]} eq 'remove_bracket_brace'){
      $end = &find_close_optbracket_brace($t,$i+1);
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].' is found');
	$i++;
      }else{
	&remove_token($t,$i,$end);
	$i = $end + 1;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'remove_parenthesis' && $t->[$i+1] eq '('){
      $end = &find_close_parenthesis($t,$i+1,'(',')');
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].' is found');
	$i++;
      }else{
	&remove_token($t,$i,$end);
	$i = $end + 1;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'remove_parenthesis_brace' && $t->[$i+1] eq '('){
      $end = &find_close_parenthesis($t,$i+1,'(',')');
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].' is found');
	$i++;
      }else{
	if($t->[$end+1] eq '{'){
	  $end = &find_close_brace($t,$end+1);
	  if($end == -1){
	    &warning('no close parenthesis of '.$t->[$i].' is found');
	    $i++;
	  }else{
	    &remove_token($t,$i,$end);
	    $i = $end + 1;
	  }
	}else{
	  &warning('no brace of '.$t->[$i].' is found');
	  $i++;
	}
      }

    }elsif($LatexCommand{$t->[$i]} eq 'keep_brace' && $t->[$i+1] eq '{'){
      # \command{...} から中身(...)を取り出す
      $end = &find_close_brace($t,$i+1);
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].' is found');
	$i++;
      }else{
	$t->[$i] = '';  $t->[$i+1] = '';  $t->[$end] = ''; 
	&handling_latex_command($t,$i+2,$end-1);
	$i = $end + 1;
      }

    }elsif($LatexCommand{$t->[$i]} eq 'remove'){
      # \command を削除
      $t->[$i] = '';
      $i++;

    }elsif($LatexCommand{$t->[$i]} eq 'remove_self_and_param'){
      # \command とそれに続くパラメタを削除 (ex. \baselineskip0.2em)
      $t->[$i] = '';
      $t->[$i+1] = s/^[0-9\.a-zA-Z=]+//o;
      $i++;

    }elsif($LatexCommand{$t->[$i]} =~ /^replace_brace:(.+)$/o &&
	   $t->[$i+1] eq '{'){
      # \command{...} → シンボルの置き換え
      $param = $1;
      $end = &find_close_brace($t,$i+1);
      if($end == -1){
	&warning('no close parenthesis of '.$t->[$i].' is found');
	$i++;
      }else{
	$t->[$i] = $param;
	&remove_token($t,$i+1,$end);
	$i = $end + 1;
      }

    }elsif($LatexCommand{$t->[$i]} =~ /^replace_self:(.+)$/o){
      # \command → シンボルの置き換え
      $t->[$i] = $1;
      $i++;

    }elsif($t->[$i] eq '\begin' && $t->[$i+1] eq '{' && $t->[$i+3] eq '}'){
      # LaTeX環境
      if($LatexEnv{$t->[$i+2]} eq 'replace_self_boundary'){
	# \begin{...} → 削除&文境界に置換
	$tmp = $t->[$i+2];
	$t->[$i] = $SB;
	&remove_token($t,$i+1,$i+3);
	$i += 4;
	# \begin{list} の後に続く {...}{...} を削除(もしあれば)
	if($tmp eq 'list'){
	  if($t->[$i] eq '{'){
	    $end = &find_close_brace($t,$i+1);
	    if($end != -1 && $t->[$end+1] eq '{'){
	      $end = &find_close_brace($t,$end+1);
	      if($end  != -1){
		&remove_token($t,$i,$end);
		$i = $end + 1;
	      }
	    }
	  }
	}

      }elsif($LatexEnv{$t->[$i+2]} eq 'replace_all_boundary'){
	# \begin{...} → 環境全体を削除&文境界に置換
	$end = &find_end_of_environment($t,$i+4,$t->[$i+2]);
	if($end == -1){
	  &warning('no \end{'.$t->[$i+2].'} is found');
	  $t->[$i] = $SB;
	  &remove_token($t,$i+1,$i+3);
	  $i += 4;
	}else{
	  $t->[$i] = $SB;
	  &remove_token($t,$i+1,$end);
	  $i = $end + 1;
	}
      }else{
	# 未定義の環境の \begin{...} は文境界に置換
	&warning('unknown latex environment: \begin{'.$t->[$i+2].'}');
	$t->[$i] = $SB;
	&remove_token($t,$i+1,$i+3);
	$i += 4;
      }

    }elsif($t->[$i] eq '\end' && $t->[$i+1] eq '{' && $t->[$i+3] eq '}'){
      if($LatexEnv{$t->[$i+2]} eq 'replace_self_boundary'){
	# \end{...} → 削除&文境界に置換
	$t->[$i] = $SB;
	&remove_token($t,$i+1,$i+3);
	$i += 4;
      }else{
	# 未定義の環境の \end{...} は文境界に置換
#	&warning('unknown latex environment: \end{'.$t->[$i+2].'}');
	$t->[$i] = $SB;
	&remove_token($t,$i+1,$i+3);
	$i += 4;
      }
    }elsif($t->[$i] eq '\\\\'){
      $t->[$i] = $SB;
      $i++;

    }else{
      $i++;
    }
  }

  ### {\command ...} => ... というパターンの処理
  for($i=$b_posit ; $i <= $e_posit ; $i++){
    if($t->[$i] =~ /^\\/o){
      $tmp = -1;
      if($t->[$i-1] eq '{'){
	$tmp = $i-1;
      }elsif($t->[$i-1] eq ' ' && $t->[$i-2] eq '{'){
	$tmp = $i-2;
      }
      if($tmp != -1){
	$end = &find_close_brace($t,$tmp);
	if($end != -1){
	  if($i+1 < $end){
	    $t->[$i+1] =~ s/^[0-9\.a-zA-Z=]+//o;
	    $t->[$i+1] = &remove_space($t->[$i+1]);
	  }
	  &remove_token($t,$tmp,$i);
	  $t->[$end] = '';
	  &handling_latex_command($t,$i+1,$end-1);
	  $i = $end;
	  next;
	}
      }
      if($t->[$i] eq '\\' && $t->[$i+1] =~ /^(\p{Latin}+)/o){
	&warning('unknown latex command: '.$t->[$i].$1);
      }else{
	&warning('unknown latex command: '.$t->[$i]);
      }
    }
  }
}

# [...]{...} というパターンを見つける。[...] はオプショナル
sub find_close_optbracket_brace {
  my($ref,$start)=@_;
  my($end);

  if($ref->[$start] eq '['){
    $end = &find_close_parenthesis($ref,$start,'[',']');
    return(-1) if $end == -1;
    $start = $end + 1;
  }
  return( &find_close_parenthesis($ref,$start,'{','}') );
}

sub find_close_brace {
  my($ref,$start)=@_;
  return( &find_close_parenthesis($ref,$start,'{','}') );
}

sub find_close_parenthesis {
  my($ref,$start,$open_p,$close_p)=@_;

  my $balance = 0;
  for(my $i=$start ; $i <= $#$ref; $i++){
    if($ref->[$i] eq $open_p){
      $balance++;
    }elsif($ref->[$i] eq $close_p){
      $balance--;
      return($i) if $balance <= 0;
    }
  }
  return(-1);
}

sub find_symbol {
  my($ref,$start,$sym)=@_;

  for(my $i=$start ; $i <= $#$ref; $i++){
    return($i) if $ref->[$i] eq $sym;
  }
  return(-1);
}

sub find_end_of_verb_command {
  my($ref,$start,$sep)=@_;
  my($i,$j,$s,$prev);

  for($i=$start ; $i <= $#$ref ; $i++){
    $prev = '';
    for($j=0 ; $j < length($ref->[$i]) ; $j++){
      $s = substr($ref->[$i],$j,1);
      if($s eq $sep){
	return($i, $prev.substr($ref->[$i],$j+1) );
      }
      $prev .= $s;
    }
  }
  return(-1);
}
  
sub find_end_of_environment {
  my($ref,$start,$name)=@_;

  for(my $i=$start ; $i <= $#$ref; $i++){
    if($ref->[$i] eq '\end' &&
       $ref->[$i+1] eq '{' &&
       $ref->[$i+2] eq $name &&
       $ref->[$i+3] eq '}'){
      return($i+3);
    }
  }
  return(-1);
}

sub find_new_macro {
  my($ref,$start)=@_;
  my($end);

  my $i=$start;
  my $command = $ref->[$start];

  # 定義名 {...} の認識
  if($ref->[$i+1] eq '{'){
    $end = &find_close_parenthesis($ref,$i+1,'{','}');
    return(-1) if $end == -1;
  }else{
    return(-1);
  }
  $i = $end;
  if($command eq '\newlength'){
    return($i);
  }
  
  # 引数の数 [...] の認識 (オプショナル)
  if($ref->[$i+1] eq '['){
    $end = &find_close_parenthesis($ref,$i+1,'[',']');
    return(-1) if $end == -1;
    $i = $end;
  }

  # 定義部分 {...} の認識
  if($ref->[$i+1] eq '{'){
    $end = &find_close_parenthesis($ref,$i+1,'{','}');
    return(-1) if $end == -1;
  }else{
    return(-1);
  }
  $i = $end;
  
  # 定義部分(2) {...} の認識 (環境の定義のときのみ)
  if($command =~ /environment$/o){
    if($ref->[$i+1] eq '{'){
      $end = &find_close_parenthesis($ref,$i+1,'{','}');
      return(-1) if $end == -1;
    }else{
      return(-1);
    }
    $i = $end;
  }
  return($i);
}

sub remove_space {
  my($s)=@_;

  $s =~ s/^[ 　]+//o;
  $s =~ s/[ 　]+$//o;
  $s =~ s/([^\x00-\x7F]) /$1/go;
  $s =~ s/ ([^\x00-\x7F])/$1/go;
  return($s);
}

sub remove_token {
  my($token_ref,$b,$e)=@_;
  for(my $i=$b ; $i <= $e ; $i++){
    $token_ref->[$i] = '';
  }
}
sub warning {
  my($msg)=@_;

  warn(sprintf "[ERROR] %s\n", $msg) if $verbose_flag;
}
  
BEGIN {

# 未対応の LaTeX コマンド
# \verb, \unitlength

$LatexCommand{'\chapter'}           = 'remove_brace';
$LatexCommand{'\section'}           = 'remove_brace';
$LatexCommand{'\section*'}          = 'remove_brace';
$LatexCommand{'\subsection'}        = 'remove_brace';
$LatexCommand{'\subsection*'}       = 'remove_brace';
$LatexCommand{'\subsubsection'}     = 'remove_brace';
$LatexCommand{'\subsubsection*'}    = 'remove_brace';
$LatexCommand{'\paragraph'}         = 'remove_brace';
$LatexCommand{'\footnote'}          = 'remove_brace';
$LatexCommand{'\caption'}           = 'remove_brace';
$LatexCommand{'\label'}             = 'remove_brace';
$LatexCommand{'\hspace'}            = 'remove_brace';
$LatexCommand{'\hspace*'}           = 'remove_brace';
$LatexCommand{'\vspace'}            = 'remove_brace';
$LatexCommand{'\vspace*'}           = 'remove_brace';
$LatexCommand{'\newsavebox'}        = 'remove_brace';
$LatexCommand{'\epsfile'}           = 'remove_brace';
$LatexCommand{'\frame'}             = 'remove_brace';
$LatexCommand{'\input'}             = 'remove_brace';
$LatexCommand{'\bibliography'}      = 'remove_brace';
$LatexCommand{'\bibliographystyle'} = 'remove_brace';
$LatexCommand{'\pagestyle'}         = 'remove_brace';
$LatexCommand{'\thispagestyle'}     = 'remove_brace';
$LatexCommand{'\textbf'}            = 'remove_brace';

$LatexCommand{'\setcounter'}        = 'remove_brace2';
$LatexCommand{'\addtocounter'}      = 'remove_brace2';
$LatexCommand{'\addtolength'}       = 'remove_brace2';
$LatexCommand{'\setlength'}         = 'remove_brace2';
$LatexCommand{'\settowidth'}        = 'remove_brace2';
$LatexCommand{'\parbox'}            = 'remove_brace2';

$LatexCommand{'\footnotetext'}      = 'remove_bracket_brace';
$LatexCommand{'\framebox'}          = 'remove_bracket_brace';

$LatexCommand{'\atari'}             = 'remove_parenthesis';

$LatexCommand{'\put'}               = 'remove_parenthesis_brace';

$LatexCommand{'\underline'}         = 'keep_brace';
$LatexCommand{'\fbox'}              = 'keep_brace';
$LatexCommand{'\mbox'}              = 'keep_brace';

$LatexCommand{'\maketitle'}         = 'remove';
$LatexCommand{'\noindent'}          = 'remove';
$LatexCommand{'\indent'}            = 'remove';
$LatexCommand{'\acknowledgment'}    = 'remove';
$LatexCommand{'\bigskip'}           = 'remove';
$LatexCommand{'\medskip'}           = 'remove';
$LatexCommand{'\smallskip'}         = 'remove';
$LatexCommand{'\hfill'}             = 'remove';
$LatexCommand{'\vfill'}             = 'remove';
$LatexCommand{'\newpage'}           = 'remove';
$LatexCommand{'\newline'}           = 'remove';
$LatexCommand{'\clearpage'}         = 'remove';
$LatexCommand{'\pagebreak'}         = 'remove';
$LatexCommand{'\linebreak'}         = 'remove';
$LatexCommand{'\par'}               = 'remove';
$LatexCommand{'\footnotemark'}      = 'remove';
$LatexCommand{'\relax'}             = 'remove';
$LatexCommand{'\strut'}             = 'remove';
# font size
$LatexCommand{'\Huge'}              = 'remove';
$LatexCommand{'\huge'}              = 'remove';
$LatexCommand{'\large'}             = 'remove';
$LatexCommand{'\Large'}             = 'remove';
$LatexCommand{'\LARGE'}             = 'remove';
$LatexCommand{'\normalsize'}        = 'remove';
$LatexCommand{'\small'}             = 'remove';
$LatexCommand{'\scriptsize'}        = 'remove';
$LatexCommand{'\footnotesize'}      = 'remove';

$LatexCommand{'\ref'}               = 'replace_brace:[REF]';

$LatexCommand{'\baselineskip'}      = 'remove_self_and_param';

$LatexCommand{'\%'} = 'replace_self:%';
$LatexCommand{'\#'} = 'replace_self:#';
$LatexCommand{'\$'} = 'replace_self:$';
$LatexCommand{'\&'} = 'replace_self:&';
$LatexCommand{'\{'} = 'replace_self:{';
$LatexCommand{'\}'} = 'replace_self:}';
$LatexCommand{'~'}  = 'replace_self: ';
$LatexCommand{'\ '} = 'replace_self: '; # 'remove';
$LatexCommand{'\,'} = 'replace_self: ';
$LatexCommand{'\_'} = 'replace_self:_';
$LatexCommand{'\.'} = 'remove';	# 傍点をつけるコマンド
$LatexCommand{'\LaTeX'} = 'replace_self:LaTeX';
$LatexCommand{'\TeX'}   = 'replace_self:TeX';
$LatexCommand{'\ldots'} = 'replace_self:…';
$LatexCommand{'\quad'}  = 'replace_self:　';
$LatexCommand{'\qquad'} = 'replace_self:　　';
$LatexCommand{'\break'} = 'replace_self: ';

# アクセント記号
$LatexCommand{"\\'"}                = 'accent'; # \'{e} => e
$LatexCommand{'\"'}                 = 'accent'; # \"{e} => e
$LatexCommand{'\~'}                 = 'accent'; # \~{a} => a
$LatexCommand{'\^'}                 = 'accent'; # \^{e} => e

# font type
$LatexCommand{'\rm'}                = 'fonttype';
$LatexCommand{'\bf'}                = 'fonttype';
$LatexCommand{'\it'}                = 'fonttype';
$LatexCommand{'\tt'}                = 'fonttype';
$LatexCommand{'\sc'}                = 'fonttype';
$LatexCommand{'\textrm'}            = 'fonttype';
$LatexCommand{'\textbf'}            = 'fonttype';
$LatexCommand{'\textit'}            = 'fonttype';
$LatexCommand{'\texttt'}            = 'fonttype';
$LatexCommand{'\textsc'}            = 'fonttype';
$LatexCommand{'\emph'}              = 'fonttype';

$LatexEnv{'itemize'}         = 'replace_self_boundary';
$LatexEnv{'enumerate'}       = 'replace_self_boundary';
$LatexEnv{'description'}     = 'replace_self_boundary';
$LatexEnv{'list'}            = 'replace_self_boundary';
$LatexEnv{'quote'}           = 'replace_self_boundary';
$LatexEnv{'quotation'}       = 'replace_self_boundary';
$LatexEnv{'sloppypar'}       = 'replace_self_boundary';
$LatexEnv{'center'}          = 'replace_self_boundary';
$LatexEnv{'flushleft'}       = 'replace_self_boundary';
$LatexEnv{'flushright'}      = 'replace_self_boundary';
$LatexEnv{'verbatim'}        = 'replace_self_boundary';
$LatexEnv{'small'}           = 'replace_self_boundary';
$LatexEnv{'footnotesize'}    = 'replace_self_boundary';

$LatexEnv{'figure'}          = 'replace_all_boundary';
$LatexEnv{'figure*'}         = 'replace_all_boundary';
$LatexEnv{'table'}           = 'replace_all_boundary';
$LatexEnv{'table*'}          = 'replace_all_boundary';
$LatexEnv{'tabular'}         = 'replace_all_boundary';
$LatexEnv{'tabbing'}         = 'replace_all_boundary';
$LatexEnv{'picture'}         = 'replace_all_boundary';
$LatexEnv{'displaymath'}     = 'replace_all_boundary';
$LatexEnv{'equation'}        = 'replace_all_boundary';
$LatexEnv{'eqnarray'}        = 'replace_all_boundary';
$LatexEnv{'eqnarray*'}       = 'replace_all_boundary';
$LatexEnv{'minipage'}        = 'replace_all_boundary';
$LatexEnv{'thebibliography'} = 'replace_all_boundary';

$LatexCommand{'\newcommand'}       = 'def_macro';
$LatexCommand{'\renewcommand'}     = 'def_macro';
$LatexCommand{'\newtheorem'}       = 'def_macro';
$LatexCommand{'\newenvironment'}   = 'def_macro';
$LatexCommand{'\renewenvironment'} = 'def_macro';
$LatexCommand{'\newlength'}        = 'def_macro';
$LatexCommand{'\cite'}   = 'cite';
$LatexCommand{'\nocite'} = 'cite';
$LatexCommand{'\verb'}   = 'verb';
$LatexCommand{'\verb*'}  = 'verb';
#$LatexCommand{'\item'}  = 'item';

# local command in journal of natural language processing
$LatexCommand{'\title'}             = 'remove_brace';
$LatexCommand{'\etitle'}            = 'remove_brace';
$LatexCommand{'\author'}            = 'remove_brace';
$LatexCommand{'\eauthor'}           = 'remove_brace';
$LatexCommand{'\headauthor'}        = 'remove_brace';
$LatexCommand{'\headtitle'}         = 'remove_brace';
$LatexCommand{'\jabstract'}         = 'remove_brace';
$LatexCommand{'\eabstract'}         = 'remove_brace';
$LatexCommand{'\jkeywords'}         = 'remove_brace';
$LatexCommand{'\ekeywords'}         = 'remove_brace';
$LatexCommand{'\citeA'}      = 'cite';
$LatexCommand{'\citeB'}      = 'cite';
$LatexCommand{'\citeC'}      = 'cite';
$LatexCommand{'\shortcite'}  = 'cite';
$LatexCommand{'\shortciteA'} = 'cite';
$LatexCommand{'\shortciteB'} = 'cite';
$LatexCommand{'\citet'}      = 'cite';
$LatexCommand{'\citep'}      = 'cite';
$LatexCommand{'\citeauthor'} = 'cite';
$LatexCommand{'\citeyear'}   = 'cite';
$LatexCommand{'\newcite'}    = 'cite';
$LatexCommand{'\fullcite'}   = 'cite';
$LatexCommand{'\fullciteA'}  = 'cite';

$CITE = '[CITE]';
$MATH = '[MATH]';
$SB = '!!!SB!!!';			# 文の境界
$EOS_REGEXP = '(。|．|[^0-9a-zA-Z]\.)';	# 文末表現

}
  
1;
