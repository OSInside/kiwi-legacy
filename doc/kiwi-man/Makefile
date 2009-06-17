#/bin/bash

#
## Needed Packages: libxslt, fop, htmldoc, ghostscript-library, docbook-xsl-stylesheets 
#

## peters: gs need a patch in order to handle the bookmarks right
##         or we use another concat tool for the pdfs 
##         the only program doing it right was: joinPDF2.1


DB=/usr/share/xml/docbook/stylesheet/nwalsh/current/

all:
	# generate man-pages
	xsltproc ${DB}/manpages/docbook.xsl  kiwi-man.xml
	xsltproc ${DB}/manpages/docbook.xsl  kiwi-man-config.sh.xml
	xsltproc ${DB}/manpages/docbook.xsl  kiwi-man-images.sh.xml

	# generate fo-files as intermediate convertable format
	# the fo-files does not render the man-pages right. The function description is in a two column layout and therefor not readable
	#xsltproc --output kiwi-man.fo --stringparam fop1.extensions 1 --stringparam paper.type A4 ${DB}/fo/docbook.xsl kiwi-man.xml
	#xsltproc --output kiwi-man-config.fo --stringparam fop1.extensions 1 --stringparam paper.type A4 ${DB}/fo/docbook.xsl kiwi-man-config.sh.xml
	#xsltproc --output kiwi-man-images.fo --stringparam fop1.extensions 1 --stringparam paper.type A4 ${DB}/fo/docbook.xsl kiwi-man-images.sh.xml

	# generate pdfs from fo
	#fop kiwi-man.fo kiwi-man.pdf
	#fop kiwi-man-config.fo kiwi-man-config.pdf
	#fop kiwi-man-images.fo kiwi-man-images.pdf

	# generate html-files as intermediate convertable format
	xsltproc --output kiwi-man.html ${DB}/html/docbook.xsl kiwi-man.xml
	xsltproc --output kiwi-man-config.html ${DB}/html/docbook.xsl kiwi-man-config.sh.xml
	xsltproc --output kiwi-man-images.html ${DB}/html/docbook.xsl kiwi-man-images.sh.xml

	# generate a pdfs from the html-files
	htmldoc --linkstyle plain --fontspacing 1.3 --textfont times --size a4 --footer ... -f pdf13 --webpage ./kiwi-man.html -f ./kiwi-man.pdf
	htmldoc --linkstyle plain --fontspacing 1.3 --textfont times --size a4 --footer ... -f pdf13 --webpage ./kiwi-man-config.html -f ./kiwi-man-config.pdf
	htmldoc --linkstyle plain --fontspacing 1.3 --textfont times --size a4 --footer ... -f pdf13 --webpage ./kiwi-man-images.html -f ./kiwi-man-images.pdf

	# append the new kiwi-man-*.pdf to the kiwi.pdf
	# BUG: Needs a patched gs to work right
	# gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=./kiwi.pdf ../LaTex/kiwi.pdf ./kiwi-man.pdf ./kiwi-man-config.pdf ./kiwi-man-images.pdf
	#
	#joinPDF output.pdf input1.pdf input2.pdf ...
	joinPDF ./kiwi.pdf ../LaTex/kiwi.pdf ./kiwi-man.pdf ./kiwi-man-config.pdf ./kiwi-man-images.pdf

   # cleanup intermediate files
	#rm -f *.fo kiwi-man*.pdf
	rm -f *.html kiwi-man*.pdf 


clean:
	rm -f *.1 ../LaTex/kiwi.pdf

