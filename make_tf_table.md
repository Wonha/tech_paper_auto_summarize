# Make TF table of input data. 

# kaizen
- change regex by applying escape sequence.

## process
usage :./make\_tf\_table ./logs/V\*/   
input file : ./log/\* (directory name)   
output file : ./log/tf\_table.md

1. except 'tf\_table.md' from ./logs's file entry.
1. OPEN output file
1. MAKE first and second line of markdown table format
1. TRAVERSE directory includes 'origin' file. 
1. READ origin file
1. DO MeCab, FILL HOA
1. WRITE into output file

## target table format
TF table | DocName1 | DocName2 | DocName3 | DocName4 | ... | DocNameN
-------- | -------- | -------- | -------- | -------- | -------- | ------- 
surface1 | CntDoc1  | CntDoc2  | CntDoc3  | CntDoc4  | ... | CntDocN
surface2 | CntDoc1  | CntDoc2  | CntDoc3  | CntDoc4  | ... | CntDocN
surface3 | CntDoc1  | CntDoc2  | CntDoc3  | CntDoc4  | ... | CntDocN
surface4 | CntDoc1  | CntDoc2  | CntDoc3  | CntDoc4  | ... | CntDocN
surface5 | CntDoc1  | CntDoc2  | CntDoc3  | CntDoc4  | ... | CntDocN
                                             
## trouble shooting
1. (solved)自立語だけを取り出すことに失敗。    
	-	ord()を使い, MeCabが作成してくれるたfeaturegが ’名詞　動詞　…’と  
	一致するか確認することで自立語を取り出そうとしたが、print()で見た時は同じ漢字に見えても、  
	ord()のreturn値とは一致しないため、自立語であるかの判定ができなかった。  
	以下の手法でも失敗。  
		- set locale environment of Unicode::Collate::Locale to ja\_JP and ja but didn't work.
		- Changend Ubuntu locale environment (/etc/default/locale) to ja\_JP, in order to use 'use locale' pragma.

	- __solution__
		- ord() operate with exactly 'one' character. So 'ord('名詞')' do not work properly.   
		- __utf8::is_utf8()__ takes variable, return 1 for utf8 character, 0 for not utf8 character.  
			- Rresult of belowing first statement was '0 名詞!!!!!'.   
			So we can assume that the code point of $pos2 was not utf8.
		- __decode() in Encode module__ takes binary value, return corresponding layer's value.  
			- If 'jis', 'utf16' etc uses the same 'code point', the function of decode() is just make perl interprete    
			 the binary(code point) as given layer(In here, utf8).   
	```perl	
	printf "%d %s!!!!!\n", utf8::is_utf8($pos2), $pos2;
	```
	```perl
	use Encode;
	my $pos2 = decode('utf8',$pos);
	```

	
1. 上記の問題がmarkdown syntax errorをもたらし、tableが綺麗に表示できない.
	-	m->{surface}に特殊文字が含まれているのが原因だと思い、regex	でフィルターリングしようとしたが、できない。
	ordでは異なる値が出るのと関係があるかもしれない.

1. (soleved)./logs/\*/ では、killedされる
	- 入力ファイル数を減らすと解決。

	- __solution__
		-	System limitation for file size could be the reason for process killed.
		- This problem solved by calling file I/O function for each line to calling it just once.
