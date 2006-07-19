# /.../
# Copyright (c) 2003 SuSE Linux AG Nuernberg, Germany.  All rights reserved.
# Author: Marcus Schäfer <ms@suse.de>, 2003
#
# Texing documentation stuff for
# IBM Retail project
#
TEX=kiwi.tex           \
	intro.tex          \
	image.tex  		   \
    activate.tex

all: ps

dvi: kiwi.dvi

kiwi.dvi: $(TEX)
	rm -f *.dvi *.idx *.ind *.ilg *.toc *.log
	latex kiwi.tex
	latex kiwi.tex
	latex kiwi.tex
	makeindex kiwi
	latex kiwi.tex
	latex kiwi.tex

ps: kiwi.dvi
	rm -f *.idx *.toc *.log *.bmt *.aux *.mtc*
	dvips kiwi.dvi
	dvips kiwi.dvi
	dvips kiwi.dvi
	dvipdf kiwi.dvi

revision:
	svn info kiwi.tex | grep Revision > Revision.txt

pdfimages:
	cd pictures; for i in *.ps; do i=$${i%.ps} ; \
	convert $$i.ps $$i.eps; \
	convert $$i.eps epdf:$$i.pdf; done; cd ..

pdf: pdfimages $(TEX)
	pdflatex kiwi
	pdflatex kiwi

clean:
	rm -f *.dvi *.idx *.toc *.log *.ps *.mtc[0-9]*
	rm -f *.aux *.mtc* *.out *.bmt  *.ind *.ilg
