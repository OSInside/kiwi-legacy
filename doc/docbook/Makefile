DB=/usr/share/xml/docbook/stylesheet/nwalsh/current/
MAIN=kiwi-doc.xml

all:kiwi.html

.tmp.xml:
	@echo "Validating ..."
	xmllint --xinclude --postvalid --output .tmp.xml ${MAIN}

kiwi.html:.tmp.xml
	@echo "Transforming HTML..."
	xsltproc --xinclude \
		--stringparam html.stylesheet susebooks.css \
		--output ./kiwi.html \
		${DB}/html/docbook.xsl ${MAIN}

clean:
	rm -f .tmp.xml
	rm -f kiwi.html
	rm -f kiwi.pdf
