# Get related study section score for each paragraph

# kaizen
- change regex \n{2,} to \r ( return character ) will probably fine.

## description
get score for evaluta which paragraph is refering related study.

input :
	rel_study files unmatched keyword list(__zero sized rel_study files__)
output :
	get the __highest scored paragraph__, and print it to input file.	

## Usage
In the base directory
```shell
$ ./monitors/get_rel_score_paragraph
```

## Cautions

