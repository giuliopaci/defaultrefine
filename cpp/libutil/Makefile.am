MAINTAINERCLEANFILES = Makefile.in stamp-h.in

LIBTOOL = @LIBTOOL@ @LIBTOOLFLAGS@

AM_CFLAGS   = -DBUILD_LIBG2P
AM_CXXFLAGS = -DBUILD_LIBG2P
AM_LDFLAGS  =

noinst_LTLIBRARIES  = libutil.la
libutil_la_CPPFLAGS = -Wno-variadic-macros
libutil_la_SOURCES = log.c log.h CmndArgs.cpp CmndArgs.h StringHelper.cpp StringHelper.h
