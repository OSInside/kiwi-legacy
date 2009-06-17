#/bin/bash

#
## Needed Packages: libxslt, htmldoc, ghostscript-library, docbook-xsl-stylesheets 
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
	../joinPDF2.1/install/joinPDF ./kiwi.pdf ../LaTex/kiwi.pdf ./kiwi-man.pdf ./kiwi-man-config.pdf ./kiwi-man-images.pdf

clean:
	# cleanup intermediate files
	rm -f *.html kiwi-man*.pdf ../LaTex/kiwi.pdf

