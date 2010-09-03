# /.../
# Makefile for building kiwi Cook Book (HTML and PDF) plus
# manual pages. Required packages are:
# ----
# libxslt
# docbook_4
# docbook-xsl-stylesheets
# fop
# fop-offo
# excalibur-avalon-framework
# xmlgraphics-commons
# batik
# docbook-dsssl-stylesheets 
# ----
#
KV=`cat Revision.txt`
DB=/usr/share/xml/docbook/stylesheet/nwalsh/current/
MAIN=kiwi-doc.xml
MAN=KIWI*config.sh.1 KIWI*images.sh.1 KIWI*kiwirc.1 kiwi.1
SOURCE=kiwi-doc.xml kiwi-doc-*.xml kiwi-man-*.xml
FIG=images/*.fig

html:kiwi.html

pdf:kiwi.pdf

man:${MAN}

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
	xsltproc --output ./kiwi.html xslt/html/docbook.xsl .tmp.xml

kiwi.pdf:.tmp.xml kiwi.fo
	@echo "Transforming PDF..."
	fop kiwi.fo kiwi.pdf

KIWI*config.sh.1:kiwi-man-config.sh.xml
	cat kiwi-man-config.sh.xml | sed -e "s@_KV_@${KV}@" > .tmp.man
	xsltproc ${DB}/manpages/docbook.xsl .tmp.man

KIWI*images.sh.1:kiwi-man-images.sh.xml
	cat kiwi-man-images.sh.xml | sed -e "s@_KV_@${KV}@" > .tmp.man
	xsltproc ${DB}/manpages/docbook.xsl .tmp.man

KIWI*kiwirc.1:kiwi-man-kiwirc.xml
	cat kiwi-man-kiwirc.xml | sed -e "s@_KV_@${KV}@" > .tmp.man
	xsltproc ${DB}/manpages/docbook.xsl .tmp.man

kiwi.1:kiwi-man.xml
	cat kiwi-man.xml | sed -e "s@_KV_@${KV}@" > .tmp.man
	xsltproc ${DB}/manpages/docbook.xsl .tmp.man

clean:
	rm -f .tmp.xml .tmp.man
	rm -f ${MAN}
	rm -f kiwi.html
	rm -f kiwi.pdf
	rm -f kiwi.fo
	make -C images clean
