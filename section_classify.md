Usage:
	./section_classify [LIST OF PATH TO SOURCE FILE]

Description:
	Input:
		List of path to source file.
	Output:
		1. Writing files by section unit to './logs/[FILE_NAME]/[CLASSIFIED_SECTION]'.
		2. Writing log file of 'section_classify' to './logs/[FILE_NAME]'.
	PROCESS:
		1. Read from src path from invoked vars.
		2. Get src name from src path.
		3. Initialize necessary vars.
		4. Read contents from src file.
		5. Tokenize sections.
		6. Classify sections.
		7. Get the logs.




