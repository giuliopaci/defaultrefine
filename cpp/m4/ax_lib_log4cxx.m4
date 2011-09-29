############################################################################
## Copyright (C) 2011 by Molo Afrika Speech Technologies (Pty) Ltd         #
##                                                                         #
## This software is  furnished under a license  agreement or nondisclosure #
## agreement. The  software may be used and copied only in accordance with #
## the  terms  of  the  agreement. You  may  not  copy,  use,  modify,  or #
## distribute the  software except as  specifically allowed in the license #
## or nondisclosure agreement.  No part of this software may be reproduced #
## or transmitted in any  form or by any  means, electronic or mechanical, #
## for any purpose, without the express written permission of Molo Afrika  #
## Speech Technologies (Pty) Ltd.                                          #
##                                                                         #
## Molo Afrika Speech Technologies (Pty) Ltd will hereafter be referred to #
## as Molo, unless otherwise stated.                                       #
##                                                                         #
## The Molo  team has made  every effort  to assure that  the  software is #
## bug free  and  correctly  functioning; however,  due  to  the  inherent #
## complexity in the design and implementation of systems, no liability is #
## accepted  for any  errors or omissions  or for consequences  of any use #
## of this  software.  Under  no  circumstances  will Molo  be  liable for #
## direct or  indirect damages or  any costs or  losses resulting from the #
## use  of  this  software.  This  software  is  distributed  WITHOUT  ANY #
## WARRANTY;  without  even the  implied  warranty  of MERCHANTABILITY  or #
## FITNESS FOR A  PARTICULAR PURPOSE. The  risk of using  this software is #
## borne solely by the user of  this software. This software may involve a #
## claim of patent rights by Molo.                                         #
##                                                                         #
## Molo is a registered trademark of Molo Afrika Speech Technologies (Pty) #
## Ltd. Any other trademarks belong to their respective owners.            #
##                                                                         #
## Inquiries should be directed to the Molo head office at:                #
##     P.O. Box 2476                                                       #
##     Brooklyn Square                                                     #
##     Pretoria                                                            #
##     South Africa                                                        #
##     0075                                                                #
############################################################################

AC_DEFUN([AX_LIB_LOG4CXX], [

AC_ARG_WITH([log4cxx], [AS_HELP_STRING([--with-log4cxx@<:@=ARG@:>@],
            [use log4cxx library from a standard location (ARG=yes),
            from the specified location (ARG=<path>),
            or disable it (ARG=no)
            @<:@ARG=yes@:>@ ])],
            [
              if test "$withval" = "no"; then
                want_log4cxx="no"
              elif test "$withval" = "yes"; then
                want_log4cxx="yes"
                log4cxx_prefix=""
              else
                want_log4cxx="yes"
                log4cxx_prefix="$withval"
              fi
            ],
            [want_log4cxx="yes"])
AC_ARG_WITH([log4cxx-incdir], AS_HELP_STRING([--with-log4cxx-incdir=INC_DIR],
            [Force given directory for log4cxx includes. Note that this will overwrite include path detection, so use this parameter only if default include detection fails and you know exactly where your log4cxx headers are located.]),
            [
              if test -d "$withval"; then
                log4cxx_inc_path="$withval"
              else
                AC_MSG_ERROR(--with-log4cxx-incdir expected directory name)
              fi
            ],
            [log4cxx_inc_path=""])
AC_ARG_WITH([log4cxx-libdir], AS_HELP_STRING([--with-log4cxx-libdir=LIB_DIR],
            [Force given directory for log4cxx libraries. Note that this will overwrite library path detection, so use this parameter only if default library detection fails and you know exactly where your log4cxx libraries are located.]),
            [
              if test -d "$withval"; then
                log4cxx_lib_path="$withval"
              else
                AC_MSG_ERROR(--with-log4cxx-libdir expected directory name)
              fi
            ],
            [log4cxx_lib_path=""])

if test "x$want_log4cxx" = "xyes"; then
  AC_SUBST(LOG4CXX_CFLAGS)
  AC_SUBST(LOG4CXX_CPPFLAGS)
  AC_SUBST(LOG4CXX_LDFLAGS)
  AC_SUBST(LOG4CXX_LIBS)

  LOG4CXX_LIBS="-llog4cxx"
  LOG4CXX_LIBDIR="lib"
  LOG4CXX_LIBDIROTHER="lib64"

  AC_MSG_CHECKING([preferred architecture library directory])
  case $target_cpu in
    *64*)
      LOG4CXX_LIBDIR="lib64"
      LOG4CXX_LIBDIROTHER="lib"
      AC_MSG_RESULT([64-bit: lib64])
      ;;
    *)
      LOG4CXX_LIBDIR="lib"
      LOG4CXX_LIBDIROTHER="lib64"
      AC_MSG_RESULT([32-bit: lib])
      ;;
  esac

  if test "$log4cxx_prefix" != ""; then
    for dir in $log4cxx_prefix $log4cxx_prefix/log4cxx; do
      AC_MSG_CHECKING([for log4cxx includes in $dir])
      pkgincdir="$dir"
      if test -f "$dir/include/log4cxx/log4cxx.h"; then
        found_inc="yes";
        LOG4CXX_CFLAGS="-I$pkgincdir/include"
        LOG4CXX_CPPFLAGS="-I$pkgincdir/include"
        AC_MSG_RESULT([found])
        break;
      fi
      AC_MSG_RESULT([not found])
    done

    for dir in $log4cxx_prefix/${LOG4CXX_LIBDIR} $log4cxx_prefix/${LOG4CXX_LIBDIROTHER}; do
      AC_MSG_CHECKING([for log4cxx libraries in $dir])
      pkglibdir="$dir"
      if test -f "$dir/liblog4cxx.so"; then
        found_lib="yes";
        LOG4CXX_LDFLAGS="-L$pkglibdir"
        AC_MSG_RESULT([found])
        break;
      fi
      AC_MSG_RESULT([not found])
    done
  else
    if test "$log4cxx_inc_path" != ""; then
      AC_MSG_CHECKING([for log4cxx includes in $log4cxx_inc_path])
      if test -f "$log4cxx_inc/log4cxx/log4cxx.h"; then
        found_inc="yes";
        LOG4CXX_CFLAGS="-I$log4cxx_inc_path"
        LOG4CXX_CPPFLAGS="-I$log4cxx_inc_path"
        AC_MSG_RESULT([found])
      else
        AC_MSG_ERROR([not found])
      fi
    else
      for dir in /usr /usr/local /usr/local/log4cxx /usr/pkg /usr/pkg/log4cxx /opt/external /opt/external/log4cxx; do
        AC_MSG_CHECKING([for log4cxx includes in $dir])
        pkgincdir="$dir"
        if test -f "$dir/include/log4cxx/log4cxx.h"; then
          found_inc="yes";
          LOG4CXX_CFLAGS="-I$pkgincdir/include"
          LOG4CXX_CPPFLAGS="-I$pkgincdir/include"
          AC_MSG_RESULT([found])
          break;
        fi
        AC_MSG_RESULT([not found])
      done
    fi

    if test "$log4cxx_lib_path" != ""; then
      AC_MSG_CHECKING([for log4cxx libraries in $log4cxx_lib_path])
      if test -f "$log4cxx_lib_path/liblog4cxx.so"; then
        found_lib="yes";
        LOG4CXX_LDFLAGS="-L$log4cxx_lib_path"
        AC_MSG_RESULT([found])
      else
        AC_MSG_ERROR([not found])
      fi
    else
      for dir in /usr/${LOG4CXX_LIBDIR} /usr/local/${LOG4CXX_LIBDIR} /usr/local/log4cxx/${LOG4CXX_LIBDIR} /usr/pkg/${LOG4CXX_LIBDIR} /usr/pkg/log4cxx/${LOG4CXX_LIBDIR} /opt/external/${LOG4CXX_LIBDIR} /opt/external/log4cxx/${LOG4CXX_LIBDIR} /usr/${LOG4CXX_LIBDIROTHER} /usr/local/${LOG4CXX_LIBDIROTHER} /usr/local/log4cxx/${LOG4CXX_LIBDIROTHER} /usr/pkg/${LOG4CXX_LIBDIROTHER} /usr/pkg/log4cxx/${LOG4CXX_LIBDIROTHER} /opt/external/${LOG4CXX_LIBDIROTHER} /opt/external/log4cxx/${LOG4CXX_LIBDIROTHER}; do
        AC_MSG_CHECKING([for log4cxx libraries in $dir])
        pkglibdir="$dir"
        if test -f "$dir/liblog4cxx.so"; then
          found_lib="yes";
          LOG4CXX_LDFLAGS="-L$pkglibdir"
          AC_MSG_RESULT([found])
          break;
        fi
        AC_MSG_RESULT([not found])
      done
    fi
  fi

  found_pkg="yes";
  if test "$found_inc" = ""; then
    found_pkg="no";
  fi
  if test "$found_lib" = ""; then
    found_pkg="no";
  fi

  if test "$found_pkg" = "yes"; then
    AC_DEFINE(HAVE_LOG4CXX_H, 1, [Define to 1 if you have the 'log4cxx' library.])
  else
    AC_MSG_ERROR([Unable to find package log4cxx])
  fi
fi

])
