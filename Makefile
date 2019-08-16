#
# Copyright (c) 2014 Rick Salevsky <rsalevsky@suse.de>
# Copyright (c) 2014, 2015, 2016 Karl Eichwalder <ke@suse.de>
# Copyright (c) 2015, 2016, 2017, 2018, 2019 Stefan Knorr <sknorr@suse.de>
#


# AsciiDoc conditional text (e.g. for "to be released" information during beta).
LIFECYCLE_VALID := beta maintained unmaintained
ifndef LIFECYCLE
  LIFECYCLE := maintained
endif
ifneq "$(LIFECYCLE)" "$(filter $(LIFECYCLE),$(LIFECYCLE_VALID))"
  override LIFECYCLE := maintained
endif

yast_profiled_file := build/.profiled/noprofile/release-notes.xml

daps_command = daps

xsltproc_command = xsltproc \
--stringparam generate.toc "/article toc" \
--stringparam generate.section.toc.level 0 \
--stringparam section.autolabel 1 \
--stringparam section.label.includes.component.label 2 \
--stringparam variablelist.as.blocks 1 \
--stringparam toc.section.depth 2 \
--stringparam toc.max.depth 3 \
--stringparam show.comments 0 \
--xinclude \
--nonet

mainfile = adoc/MAIN.release-notes.adoc
prereqs = DC-release-notes ${mainfile} adoc/*
daps_xslt_rn_dir = /usr/share/daps/daps-xslt/relnotes

profile_params = --adocattr lifecycle=$(LIFECYCLE) \
  --adocattr release_type=public
text_params =

.PHONY: clean pdf text single-html yast-html profile validate

all: validate single-html yast-html pdf text

validate: $(prereqs)
	$(daps_command) -d $< \
	  $(profile_params) \
	  validate

pdf: build/release-notes/release-notes_color_en.pdf
build/release-notes/release-notes_color_en.pdf: $(prereqs)
	$(daps_command) -vv -d $< \
	  $(profile_params) \
	  pdf

single-html: build/release-notes/single-html/release-notes/index.html
build/release-notes/single-html/release-notes/index.html: $(prereqs)
	$(daps_command) -d $< \
	  $(profile_params) \
	  html --single \
	  --param="toc.section.depth=2"

yast-html: build/release-notes/yast-html/release-notes.html
build/release-notes/yast-html/release-notes.html: $(yast_profiled_file)
	mkdir -p build/release-notes/yast-html/; \
	  $(xsltproc_command) $(daps_xslt_rn_dir)/yast.xsl $< > $@;
	  @echo "Created $@ for YaST HTML target."

# xsltproc by itself does not support profiling, so we need to do this
# beforehand for YaST HTML
profile: $(yast_profiled_file)
$(yast_profiled_file): $(prereqs)
	$(daps_command) -vv -d $< \
	  $(profile_params) \
	  profile

text: build/release-notes/release-notes.txt
# We need the text in ASCII to avoid issues when this is shown in text-only
# YaST.
build/release-notes/release-notes.txt: $(prereqs)
	$(daps_command) -d $< \
	  $(profile_params) \
	  text $(text_params)
	iconv -f UTF-8 -t ASCII//TRANSLIT -o /dev/stdout $@ > $@.tmp
	mv $@.tmp $@

clean:
	rm -rf build/
