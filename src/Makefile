CSV_FILES=$(wildcard data/*.csv data_part4/*.csv)
CSV_FILES_TMP=$(patsubst %.csv, /tmp/%.csv, $(notdir $(CSV_FILES)))
TMP_FOLDER=/tmp/

.phony: copy clean

copy:
	cp $(CSV_FILES) /tmp/
clean:
	rm $(CSV_FILES_TMP)