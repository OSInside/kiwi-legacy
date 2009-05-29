# /.../
# Copyright (c) 2006 SUSE LINUX Products GmbH. All rights reserved.
# Author: Marcus Schaefer <ms@suse.de>, 2006
#
# Makefile to create scheme documentation
# ---
.SUFFIXES:
.SUFFIXES: rnc

RELAXNG=../../modules/KIWIScheme.rnc
RELAXNG_TEST=../../modules/KIWISchemeTest.rnc

.PHONY: all
all:  kiwi.xsd test.xsd

kiwi.xsd: $(RELAXNG)
	@echo "*** Converting KIWI RNC -> XSD..."
	trang $< $@

test.xsd: $(RELAXNG_TEST)
	@echo "*** Converting KIWI TEST RNC -> XSD..."
	trang $< $@

clean:
	rm -f kiwi.xsd test.xsd xsi.xsd
