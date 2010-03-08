#
# Plot - plot time-based data on screen and to file with interactive controls
# Copyright (C) 2006  Jonas Berlin <xkr47@outerspace.dyndns.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
####
# Makefile - used to compile everything

MODULES := gtk+-2.0 libglade-2.0

TEST_WARNINGS = -Wimport \
-Wchar-subscripts \
-Wcomment \
-Wformat \
-Wformat-extra-args \
-Wformat-zero-length \
-Wformat-security \
-Wnonnull \
-Winit-self \
-Wimplicit-int \
-Werror-implicit-function-declaration \
-Wmain \
-Wmissing-braces \
-Wparentheses \
-Wsequence-point \
-Wreturn-type \
-Wswitch \
-Wtrigraphs \
-Wunused-label \
-Wunused-value \
-Wunused-variable \
-Wuninitialized \
-Wunknown-pragmas \
-fstrict-aliasing \
-Wstrict-aliasing \
-Wextra \
-Wundef \
-Wendif-labels \
-Wpointer-arith \
-Wcast-align \
-Wwrite-strings \
-Wsign-compare \
-Wstrict-prototypes \
-Wold-style-definition \
-Wmissing-prototypes \
-Wmissing-declarations \
-Wmissing-noreturn \
-Wmissing-format-attribute \
-Wmultichar \
-Wdeprecated-declarations \
-Wpacked \
-Wredundant-decls \
-Wnested-externs \
-Winline \
-Wno-long-long \
-Wfloat-equal \
 \
-Wconversion \
 \
-funsigned-char \
-fmessage-length=0 \
-fvisibility=hidden \

TEST_CFLAGS = $(TEST_WARNINGS)

DETECTED_CFLAGS = `cat .check-cflags .check-fam-cflags`
DETECTED_LDFLAGS = `cat .check-fam-ldflags`

UNUSED = \
-Wunused-function \
-Wunreachable-code \
-Wbad-function-cast \
-Wformat-nonliteral \
-Wcast-qual \

# Uncomment these (and correct the location if necessary) when installing the program
#PREFIX := /usr/local
#GLADEFILE := $(PREFIX)/share/plot.glade
#PACKAGE_LOCALE_DIR := $(PREFIX)/share/locale

# defaults for running from build env
PACKAGE_LOCALE_DIR ?= $(shell pwd)/locale


CFLAGS := \
	-MMD \
	-g \
	-fomit-frame-pointer \
	-std=c99 \
	-fPIC \
	$(DETECTED_CFLAGS) \
	$(shell pkg-config --cflags $(MODULES)) \
	-DUSE_GTK \
	-DENABLE_NLS \
	-D_GNU_SOURCE \
	$(CFLAGS) \
	\
	$(if $(CFLAGS_GLADEFILE),-DGLADEFILE='"$(CFLAGS_GLADEFILE)"') \
	-DPACKAGE_LOCALE_DIR='"$(PACKAGE_LOCALE_DIR)"'

LDFLAGS := $(shell pkg-config --libs $(MODULES)) -lm $(DETECTED_LDFLAGS)
CC := gcc

CFLAGS += -O2
CFLAGS += -funit-at-a-time
# CFLAGS += -ffast-math ##TODO## test if this can be used

.PHONY: all binaries po_to_mo gladefixes update-po clean distclean checks

all: checks binaries po/plot.pot po_to_mo gladefixes 

binaries: plot2 plot-test paintapi-test-gtk test-dataset-read

po_to_mo: $(patsubst po/%.po,locale/%/LC_MESSAGES/plot.mo,$(wildcard po/*.po))

gladefixes: .stamp.neutralize-image-ids

plot2: \
		src/gtk/compat.o \
		src/gtk/data_scrollbar_controller.o \
		src/gtk/eventhandlers.o \
		src/gtk/eventhandlers-plot-draw.o \
		src/gtk/eventhandlers-plot-keyboard.o \
		src/gtk/eventhandlers-plot-mouse.o \
		src/gtk/eventhandlers-prefs.o \
		src/gtk/export.o \
		src/gtk/file_open_dialog.o \
		src/gtk/font_dialog.o \
		src/gtk/gtkutil.o \
		src/gtk/main.o \
		src/gtk/paintapi-gtk.o \
		src/gtk/plot2-datafiles.o \
		src/gtk/plot2-markers.o \
		src/gtk/plot2-zoom-history.o \
		src/gtk/plot2.o \
		src/gtk/remove_data_file_dialog.o \
		src/gtk/sample_density_dialog.o \
		src/gtk/tail_fam.o \
		\
		src/dataset.o \
		src/grid.o \
		src/plot_draw.o \
		src/plot_draw_bookmarks.o \
		src/plot_draw_grids.o \
		src/plot_draw_legend.o \
		src/plot_draw_lines.o \
		src/stringutil.o \
		src/misc-util.o \
		src/whls.o \

	@$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $(TARGET_ARCH) $(LOADLIBES) $(LDLIBS) -o $@ $^

plot-test: \
		src/gtk/compat.o \
		src/gtk/data_scrollbar_controller.o \
		src/gtk/gtkutil.o \
		src/gtk/paintapi-gtk.o \
		\
		src/gtktest/eventhandlers.o \
		src/gtktest/eventhandlers-plot-draw.o \
		src/gtktest/eventhandlers-plot-keyboard.o \
		src/gtktest/eventhandlers-plot-mouse.o \
		src/gtktest/main.o \
		src/gtktest/plot2-datafiles.o \
		src/gtktest/plot2.o \
		\
		src/dataset.o \
		src/grid.o \
		src/plot_draw.o \
		src/plot_draw_bookmarks.o \
		src/plot_draw_grids.o \
		src/plot_draw_legend.o \
		src/plot_draw_lines.o \
		src/stringutil.o \
		src/misc-util.o \
		src/whls.o \

	@$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $(TARGET_ARCH) $(LOADLIBES) $(LDLIBS) -o $@ $^

paintapi-test-gtk: \
		src/gtk/gtkutil.o \
		src/gtk/paintapi-gtk.o \
		src/gtk/paintapi-test-gtk.o \
		\
		src/paintapi-test.o \
		src/whls.o \

	@$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $(TARGET_ARCH) $(LOADLIBES) $(LDLIBS) -o $@ $^

test-dataset-read: \
		src/test-dataset-read.o \
		src/dataset.o \
		src/stringutil.o \
		src/misc-util.o \

	@$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) $(TARGET_ARCH) $(LOADLIBES) $(LDLIBS) -o $@ $^

.stamp.neutralize-image-ids: $(wildcard *.glade) fix-glade.pl
	@./fix-glade.pl *.glade
	@touch $@

%.o: %.xc
	@if ! ./xcpp.pl $< $@ < $< > $(patsubst %.xc, %.c, $<) ; then rm $<.d ; exit 1 ; fi
#	@echo cc $<
	@$(CC) $(CFLAGS) -c -o $@ $(patsubst %.xc, %.c, $<) ; a=$$? ; bsed 's!$(patsubst %.xc,%.c,$<)!$<!' $(patsubst %.xc, %.d, $<) ; rm $(patsubst %.xc, %.c, $<) ; exit $$a
#	@$(CC) $(CFLAGS) -c -o $@ $(patsubst %.xc, %.c, $<) ; a=$$? ; if [ "$$a" = 0 ]; then bsed 's!$(patsubst %.xc,%.c,$<)!$<!' $(patsubst %.xc, %.d, $<) ; else rm $(patsubst %.xc, %.d, $<) ; fi ; rm $(patsubst %.xc, %.c, $<) ; exit $$a

clean:
	rm -f plot2 plot-test paintapi-test-gtk test-dataset-read src/*.o src/*.d src/gtk/*.o src/gtk/*.d src/gtktest/*.o src/gtktest/*.d ||:
	rm -r locale ||:

# use this if some external component changes and you need a full rebuild
distclean: clean
	find \( -name '*~' -o -name '*~' -o -name '*.bak' -o -name '.*.bak' \) -print0 | xargs -0 -r rm -f ||:
	rm -f .check* .tmp* .stamp* *.glade.h ||:

checks: .check-gtk-version .check-cflags .check-fam-cflags .check-fam-ldflags

sources:
	@echo 'Preprocessing *.xc and *.xh to *.c and *.h..'
	for xcfile in src/*.xc ; do ./xcpp.pl --export $$xcfile < $$xcfile > $${xcfile%.xc}.c.tmp || exit 1 && mv -i $${xcfile%.xc}.c.tmp $${xcfile%.xc}.c ; done
	for xhfile in src/*.xh ; do ./xcpp.pl --export $$xhfile < $$xhfile > $${xhfile%.xh}.h.tmp || exit 1 && mv -i $${xhfile%.xh}.h.tmp $${xhfile%.xh}.h ; done

%.glade.h: %.glade
	@intltool-extract --type "gettext/glade" $<

po/plot.pot: $(patsubst %.glade,%.glade.h,$(wildcard *.glade)) $(wildcard src/*.x[ch]) $(wildcard src/gtk/*.x[ch])
	@echo Updating $@..
	@xgettext -c -k_ -kN_ -kQ_ -k_c -k_n -F -L C -o $@ --from-code utf-8 $^ 

update-po: po/plot.pot
	@for i in po/*.po ; do echo Updating $$i.. ; msgmerge -U --backup=numbered $$i po/plot.pot ; done # used to touch $$i also

locale/%/LC_MESSAGES/plot.mo: po/%.po
	@echo Compiling $@..
	@[ -d $(dir $@) ] || mkdir -p $(dir $@)
	@msgfmt -o $@ -c $<

.check-gtk-version:
	@echo 'Checking for >=gtk+-2.4..'
	@pkg-config --exists 'gtk+-2.0 >= 2.4' --print-errors
	@touch $@

# check generic cflags
.check-cflags: Makefile
	@echo 'Checking for supported CFLAGS options..'
	@touch .tmp.cflags.c && ( gcc $(TEST_CFLAGS) -o .tmp.cflags.out .tmp.cflags.c > .tmp.cflags.1 2>&1 ; perl -pe 's/.*(-W[-a-zA-Z]+).*/$$1/' < .tmp.cflags.1 > .tmp.cflags.2 ) && ( echo $(TEST_CFLAGS) | tr ' ' '\n' | fgrep -v -f .tmp.cflags.2 > $@ ) && rm .tmp.cflags*

# check for libfam
.check-fam-cflags .check-fam-ldflags:
	@echo 'Checking for FAM support..'
	@if [ -e /lib/libfam.so -o -e /usr/lib/libfam.so ]; then echo '-DUSE_FAM' > $@ ; echo '-lfam' > $(patsubst %-cflags,%-ldflags,$@) ; else :> $@ ; :> $(patsubst %-cflags,%-ldflags,$@) ; fi

-include /dev/null $(wildcard src/*.d) $(wildcard src/gtk/*.d) $(wildcard src/gtktest/*.d)
