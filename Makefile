#
# Copyright (c) 2014 Rick Salevsky <rsalevsky@suse.de>
# Copyright (c) 2014, 2015, 2016 Karl Eichwalder <ke@suse.de>
# Copyright (c) 2015, 2016, 2017, 2018 Stefan Knorr <sknorr@suse.de>
#

DAPS_COMMAND=daps

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

mainfile = adoc/MAIN.release-notes.adoc
prereqs = DC-release-notes ${mainfile} adoc/*
daps_xslt_rn_dir = /usr/share/daps/daps-xslt/relnotes

text_params =

webaccessparams = --stringparam="homepage=https://www.suse.com" \
  --stringparam="overview-page=https://www.suse.com/releasenotes" \
  --stringparam="overview-page-title=Back\ to\ Release\ Notes\ for\ SUSE\ products"


.PHONY: clean pdf text single-html yast-html validate update-entries

all: validate single-html yast-html pdf text

validate: $(prereqs)
	$(DAPS_COMMAND) -d $< validate

pdf: build/release-notes/release-notes_color_en.pdf
build/release-notes/release-notes_color_en.pdf: $(prereqs)
	$(DAPS_COMMAND) -vv -d $< pdf

single-html: build/release-notes/single-html/release-notes/index.html
build/release-notes/single-html/release-notes/index.html: $(prereqs)
	$(DAPS_COMMAND) -d $< html --single \
	  --param="toc.section.depth=2"

yast-html: build/release-notes/yast-html/release-notes.html
build/release-notes/yast-html/release-notes.html: $(YAST_PROFILED_FILE)
	mkdir -p build/release-notes/yast-html/; \
	$(XSLTPROC_COMMAND) $(daps_xslt_rn_dir)/yast.xsl $< > $@

# xsltproc by itself does not support profiling, so we need to do this
# beforehand for YaST HTML
profile: build/.profiled/general/release-notes.xml)
$(YAST_PROFILED_FILE): $(merged_prereqs)
	$(DAPS_COMMAND) -vv -m $< --styleroot $(STYLEROOT) profile \
	PROFCONDITION="general"

text: build/release-notes/release-notes.txt
# We need the text in ASCII to avoid issues when this is shown in text-only
# YaST.
build/release-notes/release-notes.txt: $(prereqs)
	$(DAPS_COMMAND) -d $< text $(text_params)
	iconv -f UTF-8 -t ASCII//TRANSLIT -o /dev/stdout $@ > $@.tmp
	mv $@.tmp $@

# We write "attribute entries" (in XML parlance, ~ entities) into each file
# for proper GitHub preview, as GitHub preview currently does not follow
# include:: directives
# (https://github.com/github/markup/issues/1095#issuecomment-383348182).
update-entries: adoc/entities.adoc
	for file in adoc/*.adoc; do \
	  if [[ "$$file" != "$<" ]] && [[ "$$file" != "${mainfile}" ]]; then \
	    sed -i -n '/^\/\/ Start attribute entry list.*/,/^\/\/ End attribute entry list/ !p' $$file; \
	    echo -e '// Start attribute entry list (Do not edit here! Edit in entities.adoc)\nifdef::env-github[]' > $$file.0; \
	    cat $< >> $$file.0; \
	    echo -e 'endif::[]\n// End attribute entry list' >> $$file.0; \
	    cat $$file >> $$file.0; \
	    mv $$file.0 $$file; \
	  fi; \
	done

clean:
	rm -rf build/

