MAINTAINERCLEANFILES = Makefile.in

LIBTOOL = @LIBTOOL@ @LIBTOOLFLAGS@

AM_CFLAGS   = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include
AM_CXXFLAGS = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include
AM_LDFLAGS  =

bin_PROGRAMS = defaultrefine

defaultrefine_SOURCES  = defaultrefine.cpp
defaultrefine_CPPFLAGS = 
defaultrefine_LDFLAGS  =
defaultrefine_LDADD    = ../libg2p/libg2p.la 
