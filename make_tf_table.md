# Make TF table of input data. 

## process
name for program : make\_tf\_table.md  
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
1. 自立語だけを取り出すことに失敗。    
	-	ord()を使い, MeCabが作成してくれるたfeaturegが ’名詞　動詞　…’と  
	一致するか確認することで自立語を取り出そうとしたが、print()で見た時は同じ漢字に見えても、  
	ord()のreturn値とは一致しないため、自立語であるかの判定ができなかった。  
	以下の手法でも失敗。  
		- set locale environment of Unicode::Collate::Locale to ja\_JP and ja but didn't work.
		- Changend Ubuntu locale environment (/etc/default/locale) to ja\_JP, in order to use 'use locale' pragma.
1. 上記の問題がmarkdown syntax errorをもたらし、tableが綺麗に表示できない.
	-	m->{surface}に特殊文字が含まれているのが原因だと思い、regex	でフィルターリングしようとしたが、できない。
	ordでは異なる値が出るのと関係があるかもしれない.
1. ./logs/\*/ では、killedされる
	- 入力ファイル数を減らすと解決。
