
if COND_SINGLE_COMPILATION_UNIT
JSON_SOURCES = single-compilation-unit.cpp
else
JSON_SOURCES = json-module.cpp \
	QC_JsonRpcClient.cpp \
	ql_json.cpp

endif

lib_LTLIBRARIES = json.la
json_la_SOURCES = $(JSON_SOURCES)
json_la_LDFLAGS = -module -avoid-version

INCLUDES = -I$(top_srcdir)/include

AM_CPPFLAGS=$(QORE_CPPFLAGS)

if COND_PROFILE
AM_CXXFLAGS=-g -pg
else
if COND_DEBUG
AM_CXXFLAGS=-g
endif
endif

install-exec-hook:
	mv $(DESTDIR)$(libdir)/json.$(MODULE_SUFFIX) $(DESTDIR)$(libdir)/json-api-$(MODULE_API).qmod
	rm -f $(DESTDIR)$(libdir)/json.la
