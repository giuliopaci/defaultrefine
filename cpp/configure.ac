dnl Main setup.
AC_INIT(defaultrefine, m4_esyscmd([tr -d '\n' < version]))
AC_CONFIG_AUX_DIR(config)
AC_CONFIG_MACRO_DIR(m4)
AC_CONFIG_SRCDIR([src/defaultrefine.cpp])
AC_CONFIG_SRCDIR(src/defaultrefine.cpp)
AC_CONFIG_HEADER(config.h:config-h.in)
AM_PROG_CC_C_O

AC_CANONICAL_HOST
AC_CANONICAL_TARGET
AM_INIT_AUTOMAKE([-Wall -Werror foreign subdir-objects])

dnl Version information.
LIBG2P_VERSION=$PACKAGE_VERSION
AC_SUBST(LIBG2P_VERSION)


dnl Check for programs.
AC_USE_SYSTEM_EXTENSIONS
AC_PROG_CXX
AC_PROG_INSTALL
AC_PROG_LN_S
AM_PROG_AR

LT_INIT
AC_SUBST(LIBTOOL_DEPS)

AC_LANG([C++])

dnl Packaging.
m4_ifdef([PKG_PROG_PKG_CONFIG], [PKG_PROG_PKG_CONFIG])

dnl Profiling.
AC_MSG_CHECKING([whether to make a profiling build])
AC_ARG_ENABLE(profile, AS_HELP_STRING([--enable-profile],[make a profile build]))
AC_MSG_RESULT($enable_profile)
if test "$enable_profile" = "yes"; then
	CPPFLAGS="-pg"
	if test "$GXX" = "yes"; then
		CPPFLAGS="$CPPFLAGS -ggdb"
	fi
else
	enable_profile=no
fi

dnl Debugging.
if test "$enable_profile" = "no"; then
	AC_MSG_CHECKING([whether to make a debug build])
	AC_ARG_ENABLE(debug, AS_HELP_STRING([--enable-debug],[make a debug build]))
	AC_MSG_RESULT($enable_debug)
	if test "$enable_debug" = "yes"; then
		CPPFLAGS="-g"
		if test "$GXX" = "yes"; then
			CPPFLAGS="$CPPFLAGS -ggdb"
		fi
	else
		enable_debug=no
	fi
else
	enable_debug=yes
fi

dnl Set proper compiler flags and such for some platforms.
case $host in
	arm-wince-pe*)
		CPPFLAGS=${CPPFLAGS:--march=armv4 -mapcs-32 -malignment-traps}
		LIBS="-lc -lgcc -lwinsock -lcoredll"
		CPPFLAGS="$CPPFLAGS -DNEWLIB -DSARM -DWIN32 -DGNUWINCE"
		;;
	*uclinux*)
		# uClinux needs special "flat" binaries
		LDFLAGS="$LDFLAGS -Wl,-elf2flt"
		;;
	*solaris*)
		# OpenSolaris/Solaris seems not to link socket code, so we must do it.
		LDFLAGS="$LDFLAGS -lnsl -lsocket"
		;;
	*)
		;;
esac

dnl Extra CPPFLAGS if we have gcc.
if test "$GXX" = yes; then
	CPPFLAGS="$CPPFLAGS -Wall -W -pedantic -Wno-write-strings"
	dnl Define stricter policy on GNU/Linux, all symbols must be resolved.
	case $target in
		*linux*)
		LDFLAGS="$LDFLAGS -Wl,-z,defs"
		;;
	esac
fi

dnl Check for headers.
AC_CHECK_HEADERS(cstddef, break)
AC_CHECK_HEADERS(string.h strings.h, break)

dnl Allow libtool to be silenced.
AC_MSG_CHECKING([whether libtool should be silenced])
AC_ARG_ENABLE(silent-libtool, AS_HELP_STRING([--disable-silent-libtool],[Verbose libtool]),, enable_silent_libtool=yes)
AC_MSG_RESULT($enable_silent_libtool)
if test "$enable_silent_libtool" = "yes"; then
	LIBTOOLFLAGS=--silent
fi
AC_SUBST(LIBTOOLFLAGS)

dnl Check for system dependent features.
AC_C_CONST
AC_C_VOLATILE
AC_C_INLINE
AC_TYPE_SIZE_T
AC_C_BIGENDIAN
AC_C_BIGENDIAN
AC_FUNC_MALLOC

dnl C++ compiler/environment checks.
AX_CXX_HAVE_STD
AX_CXX_HAVE_STL
AX_CXX_NAMESPACE_STD
AX_CXX_NAMESPACES

dnl Check for the bool type.
AC_HEADER_STDBOOL
AX_CXX_BOOL

dnl Check for functions.
AC_CHECK_FUNCS(strcpy bcopy memcpy, break)
AC_CHECK_FUNCS(strcasecmp strchr strstr, break)

dnl Version information.
LIBG2P_VERSION_LIBG2P=`cat "$srcdir/""version.libg2p"`
AC_SUBST(LIBG2P_VERSION_LIBG2P)

dnl Create Makefiles.
AC_CONFIG_FILES([Makefile libg2p.pc])
AC_CONFIG_COMMANDS([default],[test -z "$CONFIG_HEADERS" || echo timestamp > libg2p/stamp-h.in],[])
AC_OUTPUT

dnl Report configuration.
echo
echo "Version........................... ${LIBG2P_VERSION}, Library: ${LIBG2P_VERSION_LIBG2P}"
echo "Source code location.............. ${srcdir}"
echo "Install path...................... ${prefix}"
echo "Debugging build................... $enable_debug"
echo "Profiling build................... $enable_profile"
echo "CFLAGS............................ ${CFLAGS}"
echo "CXXFLAGS.......................... ${CXXFLAGS}"
echo "LDFLAGS........................... ${LDFLAGS}"
echo "LIBS.............................. ${LIBS}"
echo
echo "Configure finished.  Do 'make && make install' to compile and install."
echo
