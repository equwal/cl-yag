# Find the first available Lisp implementation
LISPS?=ecl sbcl clisp abcl gcl cmu corman lucid lispworks allegro
LISP := $(shell for lisp in $(LISPS); do \
	if command -v $$lisp >/dev/null 2>&1; then \
		echo $$lisp; \
		break; \
	fi; \
done)

all: html gopher gemini

html: $(HTML) css
	mkdir -p "output/html/static"
	$(LISP) --load generator.lisp

gemini:
	mkdir -p "output/gemini/articles/"

css:
	mkdir -p "output/html/static"
	cp -fr static/* "output/html/static/"

gopher:
	mkdir -p "output/gopher"

clean: temp cleanhtml cleangopher cleangemini

temp:
	rm -fr "temp"

cleanhtml:
	rm -fr output/html/*

cleangopher:
	rm -fr output/gopher/*

cleangemini:
	rm -fr output/gemini/* 
