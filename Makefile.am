ACLOCAL_AMFLAGS = -I m4

cython_ins = capi/capi.c_capi.pyx
cython_outs = \
	capi/capi.c_capi.c \
	capi/capi.c_capi.h
CYTHONFLAGS = @CYTHONFLAGS@

# python-capi still does not export any public cpython/cython interfaces
# pyinccapidir = $(includedir)/@PACKAGE@/capi
# pyinccapi_DATA = ... capi/capi.c_capi.h ...
c_capi_includes = \
	include/capi/c_capi.pxd \
	include/capi/__init__.py

MAINTAINERCLEANFILES = \
	m4/libtool.m4 \
	m4/lt~obsolete.m4 \
	m4/ltoptions.m4 \
	m4/ltsugar.m4 \
	m4/ltversion.m4 \
	m4/libtool.m4 \
	ltmain.sh \
	depcomp \
	aclocal.m4 \
	config.guess \
	config.sub \
	configure \
	install-sh \
	Makefile.in \
	missing \
	py-compile \
        config.h.in \
	$(cython_outs)

EXTRA_DIST = \
	AUTHORS \
	COPYING \
	README \
	autogen.sh \
	python-capi.pc.in \
	$(cython_ins) $(cython_outs) \
	$(c_capi_includes) \
	$(c_capi_deps)

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = python-capi.pc

if HAVE_CYTHON
BUILT_SOURCES = $(cython_outs)
$(top_builddir)/capi/capi.c_capi.c $(top_builddir)/capi/capi.c_capi.h: $(top_srcdir)/capi/capi.c_capi.pyx $(c_capi_deps) $(c_capi_includes) Makefile
	@$(MKDIR_P) $(top_builddir)/capi
	$(AM_V_GEN)cd $(top_builddir) && $(PYTHON) -m cython -I$(top_srcdir)/include $(CYTHONFLAGS) -o $@ $<
else
$(top_builddir)/capi/capi.c_capi.c $(top_builddir)/capi/capi.c_capi.h: Makefile
	@echo "NOTE: No cython, using pre-generated capi.c_capi.[ch]"
	@$(MKDIR_P) $(top_builddir)/capi
	$(AM_V_GEN)for f in capi/capi.c_capi.c capi/capi.c_capi.h; do if ! cmp $(top_srcdir)/$$f $(top_srcdir)/$$f > /dev/null; then cp $(top_srcdir)/$$f $(top_builddir)/$$f; fi; done
endif

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/capi \
	-I$(top_srcdir)/include \
	@PYTHON_INCLUDES@ \
	@CAPI_CFLAGS@

pyexeccapidir =  $(pyexecdir)/capi
pyexeccapi_LTLIBRARIES = c_capi.la
c_capi_la_LDFLAGS = -module -avoid-version
c_capi_la_LIBTOOLFLAGS = --tag=disable-static
c_capi_la_LIBADD = @CAPI_LIBS@
c_capi_la_SOURCES = \
	$(top_builddir)/capi/capi.c_capi.c \
	$(top_builddir)/capi/capi.c_capi.h

pycapidir = $(pythondir)/capi
pycapi_PYTHON = capi/__init__.py
#
#
#.PHONY: doc doc-clean
#if HAVE_EPYDOC
#clean-local: doc-clean
#doc-clean:
#	rm -fr doc/api/html
#doc: $(pyexeccapi_LTLIBRARIES) $(pycapidir_PYTHON)
#	mkdir -p doc/api/html
#	$(AM_V_GEN)PYTHONPATH="$$PWD:$$PWD/.libs:$$PYTHONPATH" \
#		$(EPYDOC) --html -o doc/api/html \
#			-n "@PACKAGE@ @VERSION@ API" \
#			c_capi
#else
#doc-clean:
#	@echo "Install epydoc then run ./configure again"
#doc:
#	@echo "Install epydoc then run ./configure again"
#endif
