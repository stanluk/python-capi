AC_INIT([python-capi], [0.1.0], [l.stanislaws@samsung.com])
AC_PREREQ([2.65])
AC_CONFIG_SRCDIR([configure.ac])

AM_INIT_AUTOMAKE([1.6 dist-bzip2])
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

AC_PROG_LIBTOOL

AC_PROG_CC

cython_required_version=0.15.1
AM_CHECK_CYTHON([$cython_required_version], [:], [:])

AM_PATH_PYTHON(2.7)
AM_CHECK_PYTHON_HEADERS(,[AC_MSG_ERROR(could not find Python headers)])

PKG_CHECK_MODULES([CAPI], [capi-appfw-application])

AM_CONDITIONAL(HAVE_CYTHON, [test "x$CYTHON_FOUND" = "xyes"])

if test "x$CYTHON_FOUND" = "xyes"; then
   cython_info="$CYTHON_VERSION (CYTHONFLAGS=$CYTHONFLAGS)"
else
   cython_info="no"
fi

AC_SUBST(CYTHONFLAGS)
AC_OUTPUT([
Makefile
python-capi.pc
])
