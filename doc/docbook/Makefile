DB=/usr/share/xml/docbook/stylesheet/nwalsh/current/
MAIN=kiwi-doc.xml
SOURCE=kiwi-doc.xml kiwi-doc-*.xml kiwi-man-*.xml
FIG=images/*.fig

html:kiwi.html

pdf:kiwi.pdf

images/*.png:${FIG}
	make -C images all

.tmp.xml:${SOURCE} images/*.png
	@echo "Validating..."
	xmllint --xinclude --postvalid --output .tmp.xml ${MAIN}
	@echo "Resolving XIncludes..."
	xsltproc --xinclude --output .tmp.xml \
		xslt/profiling/db4index-profile.xsl ${MAIN}

kiwi.fo:.tmp.xml
	xsltproc --output kiwi.fo xslt/fo/docbook.xsl .tmp.xml

kiwi.html:.tmp.xml
	@echo "Transforming HTML..."
	xsltproc --stringparam html.stylesheet susebooks.css \
		--output ./kiwi.html ${DB}/html/docbook.xsl .tmp.xml

kiwi.pdf:.tmp.xml kiwi.fo
	@echo "Transforming PDF..."
	fop kiwi.fo kiwi.pdf

clean:
	rm -f .tmp.xml
	rm -f kiwi.html
	rm -f kiwi.pdf
	rm -f kiwi.fo
	make -C images clean
