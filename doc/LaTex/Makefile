# /.../
# Copyright (c) 2003 SuSE Linux AG Nuernberg, Germany.  All rights reserved.
# Author: Marcus Schäfer <ms@suse.de>, 2003
#
# Texing documentation stuff for
# IBM Retail project
#
TEX=kiwi.tex           \
	intro.tex          \
	description.tex    \
	ec2.tex            \
	iso.tex            \
	maintenance.tex    \
	oem.tex            \
	pxe.tex            \
	testing.tex        \
	usb.tex            \
	vmx.tex            \
	workflow.tex       \
	appliance.tex      \
	xen.tex            \
	instsource.tex     \
	migrate.tex        \
    source.tex         \
    appendix.tex

all: revision ps

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
	mv kiwi.pdf ../kiwi-man/kiwi-base.pdf
	${MAKE} -C ../kiwi-man all

revision:
	cat ../../rpm/kiwi.spec | grep Version: | cut -f2 -d: |\
		 tr -d " " | tr -d "\n" > Revision.txt
	#echo -n " \small{( SVN r" >> Revision.txt
	#../../.version >> Revision.txt
	#echo -n " )}" >> Revision.txt

pdfimages:
	cd pictures; for i in *.ps; do i=$${i%.ps} ; \
	convert $$i.ps $$i.eps; \
	convert $$i.eps epdf:$$i.pdf; done; cd ..

pdf: pdfimages $(TEX)
	pdflatex kiwi
	pdflatex kiwi

clean:
	rm -f *.dvi *.idx *.toc *.log *.ps *.mtc[0-9]*
	rm -f *.aux *.mtc* *.out *.bmt  *.ind *.ilg *.maf
	(cd ../kiwi-man && rm -f kiwi-base.pdf)
	(cd ../kiwi-man && rm -f *.html kiwi-man*.pdf)
