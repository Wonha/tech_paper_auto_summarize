# random extracted 29 documents
document name | 2nd pattern matching | paragraphs about related study 
--- | --- | ---
V01N01-01 | 1 | 1  
V02N04-03 | 1 | 1  
V03N03-03 | 1 | 1  
V04N01-04 | 1 | 0 
V04N04-01 | 1 | 0 
V06N02-06 | 1 | 1  
V06N05-03 | 1 | 0 
V07N02-07 | 1 | 1 
V07N04-07 | 1 | 1  
V08N04-02 | 1 | 0 
V09N04-04 | 0 | - 
V10N01-04 | 1 | 0 
V10N05-02 | 1 | 1  
V11N06-07 | 0 | - 
V12N05-05 | 1 | 1  
V13N03-06 | 1 | 0 
V14N02-01 | 0 | - 
V14N03-11 | 1 | 0 
V14N05-05 | 0 | - 
V15N03-03 | 0 | - 
V16N01-01 | 1 | 1 
V16N04-04 | 1 | 0
V17N01-11 | 1 | 0 
V17N05-02 | 0 | - 
V18N04-02 | 1 | 1  
V19N05-02 | 0 | - 
V20N03-03 | 0 | - 
V21N01-03 | 0 | - 
V21N03-03 | 1 | 0 
V22N02-02 | 0 | - 

// 관련연구에 관련된 내용은 추출했지만, 이 추출로는 요약을 만들수 없으므로 "2nd 패턴매칭으로 추출된것이 '관련연구와 관련된 내용'인가?" 는 0 임

# title X 2nd O

## all | 1 | 1 | ones from upper 30
document name | title not matched | 'related study' related contents exsist in extracted paragraph | right answer exsist in the document | extracted paragraphs includes the right answer
--- | --- | --- | --- | ---
V01N01-01 | 1 | 1 | 1 | 1
V02N04-03 | 1 | 1 | 1 | 1
V03N03-03 | 1 | 1 | 1 | 0
V06N02-06 | 1 | 1 | 1 | 1
V07N02-07 | 1 | 1 | 1 | 0
V07N04-07 | 1 | 1 | 1 | 0
V10N05-02 | 1 | 1 | 1 | 1
V12N05-05 | 1 | 1 | 1 | 1
V16N01-01 | 1 | 1 | 1 | 1

V18N04-02 | 1 | 1 | 0 | - // ignore this documents since doesn't have right answer in the document

## from [](eval_dev_data/rel_2nd_eval_dev_tex/no_rel_sec)
- random extracted, all documents not matched section title matching
document name | title not matched | 'related study' related contents exsist in extracted paragraph | right answer exsist in the document | extracted paragraphs includes the right answer
V09N03-01 | 1 | 1 | 1 | 1
V11N04-04 | 1 | 1 | 1 | 1
V16N04-02 | 1 | 1 | 1 | 0
V21N05-04 | 1 | 1 | 1 | 1
V22N04-01 | 1 | 0 | 1 | 0

## from [](eval_dev_data/rel_2nd_eval_dev_tex/old_no_rel_sec)
- random extracted, all documents not matched section title matching
document name | title not matched | 'related study' related contents exsist in extracted paragraph | right answer exsist in the document | extracted paragraphs includes the right answer
V11N05-03 | 1 | 1 | 1 | 1
V09N02-02 | 1 | 1 | 1 | 1

# title O 2nd O

