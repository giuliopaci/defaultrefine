MAINTAINERCLEANFILES = Makefile.in stamp-h.in

LIBTOOL = @LIBTOOL@ @LIBTOOLFLAGS@

AM_CFLAGS   = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
AM_CXXFLAGS = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
AM_LDFLAGS  =

noinst_LIBRARIES  = libutil.a
libutil_a_CPPFLAGS = -Wno-variadic-macros
libutil_a_SOURCES = log.c log.h CmndArgs.cpp CmndArgs.h StringHelper.cpp StringHelper.h
