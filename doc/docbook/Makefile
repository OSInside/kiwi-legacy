# /.../
# Makefile for building kiwi Cook Book (HTML and PDF) plus
# manual pages.
# ----
#
KV=`cat Revision.txt`
DB=/usr/share/xml/docbook/stylesheet/nwalsh/current/
MAIN=kiwi-doc.xml
MAN=KIWI*config.sh.1 KIWI*images.sh.1 KIWI*kiwirc.1 kiwi.1
SOURCE=kiwi-doc.xml kiwi-doc-*.xml kiwi-man-*.xml
FIG=images/*.fig
FOPCONFIG=etc/fop.xml
NONET=--nonet

all: revision html pdf man

html:kiwi.html
	mv kiwi.html ../

pdf:kiwi.pdf
	mv kiwi.pdf ../

man:${MAN}
	mv KIWI::config.sh.1 ../
	mv KIWI::images.sh.1 ../
	mv KIWI::kiwirc.1 ../
	mv kiwi.1 ../

images/*.png:${FIG}
	make -C images all

.tmp.xml:${SOURCE} images/*.png
	@echo "Validating..."
	xmllint ${NONET} --xinclude --postvalid --output .tmp.xml ${MAIN}
	@echo "Resolving XIncludes..."
	xsltproc ${NONET} --xinclude --output .tmp.xml \
		xslt/profiling/db4index-profile.xsl ${MAIN}

kiwi.fo:.tmp.xml
	xsltproc ${NONET} --output kiwi.fo xslt/fo/docbook.xsl .tmp.xml

kiwi.html:.tmp.xml
	@echo "Transforming HTML..."
	xsltproc ${NONET} --output ./kiwi.html xslt/html/docbook.xsl .tmp.xml

kiwi.pdf:.tmp.xml kiwi.fo
	@echo "Transforming PDF..."
	fop -c ${FOPCONFIG} kiwi.fo kiwi.pdf

KIWI*config.sh.1:kiwi-man-config.sh.xml
	cat kiwi-man-config.sh.xml | sed -e "s@_KV_@${KV}@" > .tmp.man
	xsltproc ${NONET} ${DB}/manpages/docbook.xsl .tmp.man

KIWI*images.sh.1:kiwi-man-images.sh.xml
	cat kiwi-man-images.sh.xml | sed -e "s@_KV_@${KV}@" > .tmp.man
	xsltproc ${NONET} ${DB}/manpages/docbook.xsl .tmp.man

KIWI*kiwirc.1:kiwi-man-kiwirc.xml
	cat kiwi-man-kiwirc.xml | sed -e "s@_KV_@${KV}@" > .tmp.man
	xsltproc ${NONET} ${DB}/manpages/docbook.xsl .tmp.man

kiwi.1:kiwi-man.xml
	cat kiwi-man.xml | sed -e "s@_KV_@${KV}@" > .tmp.man
	xsltproc ${NONET} ${DB}/manpages/docbook.xsl .tmp.man

clean:
	rm -f .tmp.xml .tmp.man
	rm -f ${MAN}
	rm -f kiwi.html
	rm -f kiwi.pdf
	rm -f kiwi.fo

check:
	@echo "Checking for packages..."
	rpm -q libxml2-2 libxslt-devel \
		docbook_4 docbook-xsl-stylesheets \
		xmlgraphics-fop xmlgraphics-batik dejavu-fonts sil-charis-fonts \
		xmlgraphics-commons excalibur-avalon-framework

revision:
	cat ../../rpm/kiwi.spec | grep Version: | cut -f2 -d: | cut -f1-2 -d. |\
		tr -d " " | tr -d "\n" > Revision.txt
