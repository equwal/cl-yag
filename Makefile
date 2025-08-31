LISP=ecl

all: html gopher

html: $(HTML) css
	mkdir -p "output/html/static"
	$(LISP) --load generator.lisp

css:
	mkdir -p "output/html/static"
	cp -fr static/* "output/html/static/"

gopher:
	mkdir -p "output/gopher"

clean: cleanhtml cleangopher
	rm -fr "temp"

cleanhtml:
	rm -fr output/html/*

cleangopher:
	output/gopher/* 
