# /.../
# Copyright (c) 2006 SUSE LINUX Products GmbH. All rights reserved.
# Author: Marcus Schaefer <ms@suse.de>, 2006
#
# Makefile to create schema documentation
# ---
.SUFFIXES:
.SUFFIXES: rnc

RELAXNG=../../modules/KIWISchema.rnc

.PHONY: all
all:  kiwi.xsd

kiwi.xsd: $(RELAXNG)
	@echo "*** Converting KIWI RNC -> XSD..."
	trang $< $@

clean:
	rm -f kiwi.xsd xsi.xsd
