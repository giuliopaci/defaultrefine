ACLOCAL_AMFLAGS = -I m4

EXTRA_DIST = autogen.sh defaultrefine.spec m4/*.m4 version version.libg2p

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libg2p.pc

TESTS = test.sh
EXTRA_DIST += $(TESTS)

noinst_LTLIBRARIES  = libutil.la
libutil_la_CFLAGS   = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
libutil_la_CXXFLAGS = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
libutil_la_CPPFLAGS = -Wno-variadic-macros
libutil_la_SOURCES = libutil/log.c libutil/log.h libutil/CmndArgs.cpp libutil/CmndArgs.h libutil/StringHelper.cpp libutil/StringHelper.h

lib_LTLIBRARIES  = libg2p.la
libg2p_la_CFLAGS   = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
libg2p_la_CXXFLAGS = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
libg2p_la_CPPFLAGS = -Wno-variadic-macros
libg2p_la_SOURCES = libg2p/g2popt.cpp libg2p/g2p_pattern.cpp libg2p/GGroups.cpp libg2p/GNode.cpp libg2p/GRule.cpp libg2p/GTree.cpp libg2p/RNode.cpp libg2p/RTree.cpp libg2p/libg2p.cpp
libg2p_la_LDFLAGS = -version-info @LIBG2P_VERSION_LIBG2P@
libg2p_la_LIBADD   = libutil.la

libg2p_includedir = $(includedir)/libg2p
libg2p_include_HEADERS = libg2p/g2popt.h libg2p/g2p_pattern.h libg2p/GGroups.h libg2p/GNode.h libg2p/GRule.h libg2p/GTree.h libg2p/RNode.h libg2p/RTree.h

bin_PROGRAMS = defaultrefine
defaultrefine_CFLAGS   = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
defaultrefine_CXXFLAGS = -I$(top_srcdir) -I$(top_builddir) -I$(top_srcdir)/include -I$(top_builddir)/include -I$(top_srcdir)/libutil
defaultrefine_SOURCES  = src/defaultrefine.cpp
defaultrefine_CPPFLAGS = 
defaultrefine_LDFLAGS  = -L$(top_builddir)/libutil
defaultrefine_LDADD    = libg2p.la libutil.la

