ACLOCAL_AMFLAGS = -I m4

MAINTAINERCLEANFILES = Makefile.in aclocal.m4 configure config-h.in

EXTRA_DIST = autogen.sh aclocal.m4 defaultrefine.spec m4/*.m4 version version.libg2p

SUBDIRS = libutil libg2p src

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libg2p.pc

TESTS = test.sh

# Automatically update libtool script if it gets out-of-date.
libtool: $(LIBTOOL_DEPS)
	$(SHELL) ./config.status --recheck
