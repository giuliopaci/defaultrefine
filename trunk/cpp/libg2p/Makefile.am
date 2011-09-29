MAINTAINERCLEANFILES = Makefile.in stamp-h.in

LIBTOOL = @LIBTOOL@ @LIBTOOLFLAGS@

AM_CFLAGS   =
AM_CXXFLAGS =
AM_LDFLAGS  =

library_includedir = $(includedir)/libg2p
library_include_HEADERS = g2popt.h g2p_pattern.h GGroups.h GNode.h GRule.h GTree.h RNode.h RTree.h

lib_LTLIBRARIES    = libg2p.la
libg2p_la_SOURCES  = g2popt.cpp g2p_pattern.cpp GGroups.cpp GNode.cpp GRule.cpp GTree.cpp RNode.cpp RTree.cpp
libg2p_la_CPPFLAGS = 
libg2p_la_LDFLAGS  = -L../libutil -no-undefined -version-info @LIBG2P_VERSION_LIBG2P@
libg2p_la_LIBADD   = -lutil
