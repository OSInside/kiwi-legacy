#/bin/bash

DB=/usr/share/xml/docbook/stylesheet/nwalsh/current/

all:
	xsltproc ${DB}/manpages/docbook.xsl  kiwi-man.xml
	xsltproc ${DB}/manpages/docbook.xsl  kiwi-man-config.sh.xml
	xsltproc ${DB}/manpages/docbook.xsl  kiwi-man-images.sh.xml
	#xsltproc --output kiwi.html $DB/html/docbook.xsl xml/kiwi-man.xml

clean:
	rm -f *.1

