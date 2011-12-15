MAINTAINERCLEANFILES = Makefile.in

LIBTOOL = @LIBTOOL@ @LIBTOOLFLAGS@

AM_CFLAGS   = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
AM_CXXFLAGS = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
AM_LDFLAGS  =

bin_PROGRAMS = defaultrefine

defaultrefine_SOURCES  = defaultrefine.cpp
defaultrefine_CPPFLAGS = 
defaultrefine_LDFLAGS  = -L../libutil
defaultrefine_LDADD    = ../libg2p/libg2p.la -lutil
