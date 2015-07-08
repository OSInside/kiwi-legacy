# /.../
# Makefile for building kiwi Cook Book (HTML and PDF) plus
# manual pages.
# ----
#


#----------
# "Command line parameters"
#
# if not "yes" the developer documentation will not be build
DEVDOCS := yes

#----------
# general 
DB        := /usr/share/xml/docbook/stylesheet/nwalsh/current
DEVDOCDIR := ../devdoc
BUILDDIR  := build

FIGDIR    := images/src/fig
PNGDIR    := ../images
SVGDIR    := $(BUILDDIR)
FOPCONFIG := etc/fop.xml
MAIN      := xml/kiwi-doc.xml
NONET     := --nonet


#------------------------------------------------------------
# programs
xsltproc  := /usr/bin/xsltproc $(NONET)
fop       := /usr/bin/fop -c $(FOPCONFIG)

#------------------------------------------------------------
# files
profiled  := $(BUILDDIR)/.profiled.xml
html      := ../kiwi.html
man       := $(addprefix ../,KIWI*config.sh.1 KIWI*images.sh.1 KIWI*kiwirc.1 kiwi.1)
fo        := $(BUILDDIR)/.kiwi.fo
pdf       := ../kiwi.pdf
rev_file  := xml/Revision.txt

results   := $(html) $(man) $(pdf)

#-------
# images

figs := $(wildcard $(FIGDIR)/*.fig)
pngs := $(subst  $(FIGDIR),$(PNGDIR),$(figs:.fig=.png))
svgs := $(subst $(FIGDIR),$(SVGDIR),$(figs:.fig=.svg))

#-------
# xsltproc parameters

man_stringparams := --stringparam man.output.base.dir ../ \
			--stringparam man.output.in.separate.dir 1 \
			--stringparam man.output.subdirs.enabled 0

pdf_stringparams := --stringparam img.src.path $(SVGDIR)/

html_stringparams := --stringparam img.src.path images/

#-------
# Functions

# Validation
define validate
  xmllint $(NONET) --xinclude --postvalid --noout $1
  touch $2
endef

# man page generation
define generate_man
  $(xsltproc) $(man_stringparams) $(DB)/manpages/docbook.xsl $<
endef

#------------------------------------------------------------

.PHONY: all check clean devdoc real-clean

ifeq "DEVDOCS" "yes"
  all: $(results) devdoc
else
  all: $(results)
endif

#
# --------------
# HTML and PDF builds

$(html): $(profiled) $(pngs) $(svgs) $(BUILDDIR)/.post_valid
	@echo "Transforming HTML..."
	$(xsltproc) $(html_stringparams) --output $@ xslt/html/docbook.xsl $<

$(fo): $(profiled) $(pngs) $(svgs) $(BUILDDIR)/.post_valid
	$(xsltproc) $(pdf_stringparams) --output $@ xslt/fo/docbook.xsl $<
$(pdf): $(fo)
	@echo "Transforming PDF..."
	$(fop) $< $@

#
# --------------
# Man pages

../KIWI*config.sh.1:$(BUILDDIR)/.kiwi-man-config.sh.xml.tmp.man
	$(call generate_man)

../KIWI*images.sh.1:$(BUILDDIR)/.kiwi-man-images.sh.xml.tmp.man
	$(call generate_man)

../KIWI*kiwirc.1:$(BUILDDIR)/.kiwi-man-kiwirc.xml.tmp.man
	$(call generate_man)

../kiwi.1:$(BUILDDIR)/.kiwi-man.xml.tmp.man
	$(call generate_man)

########################### HELPER targets #############################
# --------------
# pre and post validation

$(BUILDDIR)/.pre_valid: $(MAIN) $(rev_file) | $(BUILDDIR)
	@echo "Validating original sources..."
	$(call validate,$<,$@)

$(BUILDDIR)/.post_valid: $(profiled) $(rev_file) | $(BUILDDIR)
	@echo "Validating profiled sources..."
	$(call validate,$<,$@)

#
# --------------
# Profiled bigfile

$(profiled): $(MAIN) $(BUILDDIR)/.pre_valid | $(BUILDDIR)
	@echo "Resolving XIncludes..."
	xsltproc $(NONET) --xinclude --output $@ \
	  xslt/profiling/db4index-profile.xsl $(MAIN)

#
# --------------
# Revision

$(rev_file): ../../rpm/kiwi.spec
	cat $< | grep "Version:" | cut -f2 -d: | cut -f1-2 -d. | \
	  tr -d " " | tr -d "\n" > $@

#
# ---------------
# Pattern rules for
#  - creating .pngs from .fig
#  - creating temp XML files for man pages which include the version number

$(PNGDIR)/%.png: $(FIGDIR)/%.fig
	fig2dev -L png -S4 $< $@

$(SVGDIR)/%.svg: $(FIGDIR)/%.fig
	fig2dev -L svg $< $@

$(BUILDDIR)/.%.xml.tmp.man: xml/%.xml $(rev_file)  | $(BUILDDIR)
	sed -e "s@_KV_@$(shell cat $(rev_file))@" < $< > $@

#
# ---------------
#
$(BUILDDIR):
	mkdir -p $@


clean:
	rm -rf $(BUILDDIR)/* $(BUILDDIR)/.[^.]*

check:
	@echo "Checking for packages..."
	rpm -q libxml2-2 libxslt-devel graphviz-perl docbook_4 \
	  docbook-xsl-stylesheets xmlgraphics-fop xmlgraphics-batik \
	  dejavu-fonts sil-charis-fonts xmlgraphics-commons \
	  excalibur-avalon-framework

devdoc:
	$(MAKE) -C $(DEVDOCDIR) all

real-clean: clean
	rm -f $(pngs) $(results) $(rev_file)


