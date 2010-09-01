DB=/usr/share/xml/docbook/stylesheet/nwalsh/current/
MAIN=kiwi-doc.xml
SOURCE=kiwi-doc-*.xml kiwi-man-*.xml

all:kiwi.html kiwi.pdf

.tmp.xml:
	@echo "Validating ..."
	xmllint --xinclude --postvalid --output .tmp.xml ${MAIN}

images/*.png:images/*.fig
	make -C images all

kiwi.html:.tmp.xml images/*.png ${SOURCE}
	@echo "Transforming HTML..."
	xsltproc --xinclude \
		--stringparam html.stylesheet susebooks.css \
		--output ./kiwi.html \
		${DB}/html/docbook.xsl ${MAIN}

kiwi.pdf:.tmp.xml images/*.png ${SOURCE}
	java -jar /usr/share/java/saxon.jar -o kiwi.fo .tmp.xml ${DB}/fo/docbook.xsl
	fop -fo kiwi.fo -pdf kiwi.pdf

clean:
	rm -f .tmp.xml
	rm -f kiwi.html
	rm -f kiwi.pdf
	rm -f kiwi.fo
	make -C images clean
