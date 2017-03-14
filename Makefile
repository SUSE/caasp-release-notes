#
# Copyright (c) 2014 Rick Salevsky <rsalevsky@suse.de>
# Copyright (c) 2014, 2015, 2016 Karl Eichwalder <ke@suse.de>
# Copyright (c) 2015, 2016 Stefan Knorr <sknorr@suse.de>
#

.PHONY: clean merge pdf text single-html yast-html validate-template validate \
make-update offline-merge

# here we set FATEPROD and PROFOS
include make.vars

DAPS_COMMAND=daps
FATERN_COMMAND=fate_rn

XSLTPROC_COMMAND = xsltproc \
--stringparam generate.toc "/article toc" \
--stringparam generate.section.toc.level 0 \
--stringparam section.autolabel 1 \
--stringparam section.label.includes.component.label 2 \
--stringparam variablelist.as.blocks 1 \
--stringparam toc.section.depth 2 \
--stringparam toc.max.depth 3 \
--stringparam show.comments 0 \
--stringparam profile.os "$(PROFOS)" \
--xinclude --nonet

template_prereqs = xml/template.xml xml/release-notes.ent
merged_prereqs = xml/release-notes.xml xml/release-notes.ent
daps_xslt_rn_dir = /usr/share/daps/daps-xslt/relnotes

# Check DAPS version = "daps x.y.z"; then shorten to "x.y.z"
daps_version = $(shell $(DAPS_COMMAND) --version | sed 's/daps //i')
# sort -V sorts version numbers, highest number last
# (but it is imperfect -- words like "beta" or "rc" confuse it)
daps_version_check = $(shell echo -e "$(daps_version)\n2.1.4.99" | sort -V | tail -1)

fatern_version = $(shell $(FATERN_COMMAND) | sed -n -r 's/^fate_rn v?([.0-9]+).*/\1/i p')
fatern_version_check = $(shell echo -e "$(fatern_version)\n1.39.99" | sort -V | tail -1)

# If we're running with DAPS 2.1.5 or higher, no text params are necessary
text_params =
ifeq ($(strip $(daps_version_check)),2.1.4.99)
  text_params = --stringparam="generate.permalinks=0" \
    --stringparam="section.autolabel=1" \
    --stringparam="section.label.includes.component.label=2" \
    --stringparam="optimize.plain.text=1"
endif

merge_params =
ifneq ($(strip $(fatern_version_check)),1.39.99)
  merge_params = --em
endif

webaccessparams = --stringparam="homepage=http://www.suse.com" \
    --stringparam="overview-page=http://www.suse.com/releasenotes" \
    --stringparam="overview-page-title=Back\ to\ Release\ Notes\ for\ SUSE\ products"
ifdef NOWEBACCESS
  webaccessparams = --stringparam="build.for.web=0"
endif

ifdef NOBUGLINK
  buglink = --stringparam="use.tracker.meta=0"
endif

# URLCHECK is ignored for offline-merge, as it cannot work offline
ifdef URLCHECK
  urlcheck = --check-urls
endif

# DocBook profiling (hide/show some text, such as "to be released" information).
LIFECYCLE_VALID := beta pre maintained unmaintained
ifndef LIFECYCLE
  LIFECYCLE := maintained
endif
ifneq "$(LIFECYCLE)" "$(filter $(LIFECYCLE),$(LIFECYCLE_VALID))"
  override LIFECYCLE := maintained
endif

ifndef STYLEROOT
  STYLEROOT := /usr/share/xml/docbook/stylesheet/suse2013
endif

YAST_PROFILED_FILE := build/.profiled/general_$(LIFECYCLE)/release-notes.xml

all: single-html yast-html pdf text

merge: validate-template
	$(FATERN_COMMAND) \
	  $(merge_params) \
	  --fallback-miscellaneous \
	  --fate-url "https://fate.novell.com" \
	  --template xml/template.xml $(FATEPROD) \
	  --output xml/release-notes.xml \
	  $(urlcheck)

offline-merge: validate-template
	$(FATERN_COMMAND) \
	  $(merge_params) \
	  --offline\
	  --fallback-miscellaneous \
	  --fate-url "https://fate.novell.com" \
	  --template xml/template.xml $(FATEPROD) \
	  --output xml/release-notes.xml

validate-template: $(template_prereqs)
	$(DAPS_COMMAND) -m $< validate

validate: $(merged_prereqs)
	$(DAPS_COMMAND) -m $< validate

pdf: build/release-notes/release-notes_color_en.pdf
build/release-notes/release-notes_color_en.pdf: $(merged_prereqs)
	$(DAPS_COMMAND) -vv -m $< --styleroot $(STYLEROOT) pdf \
	  PROFOS="$(PROFOS)" \
	  PROFCONDITION="general\;$(LIFECYCLE)"

single-html: build/release-notes/single-html/release-notes/index.html
build/release-notes/single-html/release-notes/index.html: $(merged_prereqs)
	$(DAPS_COMMAND) -m $< --styleroot "$(STYLEROOT)" html --single \
	  --param="toc.section.depth=2" \
	  $(webaccessparams) \
	  $(buglink) \
	  PROFOS="$(PROFOS)" \
	  PROFCONDITION="general\;$(LIFECYCLE)"


yast-html: build/release-notes/yast-html/release-notes.html
build/release-notes/yast-html/release-notes.html: $(YAST_PROFILED_FILE)
	mkdir -p build/release-notes/yast-html/; \
	$(XSLTPROC_COMMAND) $(daps_xslt_rn_dir)/yast.xsl $< > $@

# xsltproc by itself does not support profiling, so we need to do this
# beforehand for YaST HTML
profile: build/.profiled/general_$(LIFECYCLE)/release-notes.xml)
$(YAST_PROFILED_FILE): $(merged_prereqs)
	$(DAPS_COMMAND) -vv -m $< --styleroot $(STYLEROOT) profile \
	PROFCONDITION="general\;$(LIFECYCLE)"

text: build/release-notes/release-notes.txt
# We need the text in ASCII to avoid issues when this is shown in text-only
# YaST.
# The sed expression apparently removes question marks from the beginning of
# lines, not entirely sure why we need it, though.
build/release-notes/release-notes.txt: $(merged_prereqs)
	$(DAPS_COMMAND) -m $< --styleroot $(STYLEROOT) text $(text_params) PROFOS="$(PROFOS)" \
	  PROFCONDITION="general\;$(LIFECYCLE)"
	iconv -f UTF-8 -t ASCII//TRANSLIT -o /dev/stdout $@ \
	  | sed 's/^??\+//' >$@.tmp
	mv $@.tmp $@

make-update:
	wget --no-check-certificate -O Makefile \
	https://gitlab.suse.de/documentation/makefile-release-notes/raw/master/Makefile

clean:
	rm -rf prd.xml rns_i.xml rns_v.xml rns.xml build/
