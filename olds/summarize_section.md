# summarize each section

## description
- various algos can attached as subroutine.

## usage
- usage : ./[program\_name]

## process
- input :	written in src file 
- output : 'sum\_[section\_name]\_[algo\_name]'.

***
****
DECLARE 
****
DECLARE void tf\_idf
****
main 
> DECLARE array @dirs_ar and assign  GLOB './logs/*/'    
> DECLARE array @sections_ar containing section file names    
> FOR @dirs_ar 
> > DECLARE array @fn_out_ar containing output file names    
> 	FOR @sections_ar 
>	> >	READ section   
> 	INVOKE subroutines   

> >	END FOR  
> > WRITE summarization result  

> END FOR  
***

tf\_idf  
> get argument by hash ref.
> get section file name 
> open section file
> read section file
> close section file
> read tfidf file
> for each sent
> do mecab
> regex \b\w+\b
> calc score of sent from each word and tfidffile
> sort sent by descending sort
> output to output file
***

- only the last subroutine of summarization algorithm take output filename parameters.
