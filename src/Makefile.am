MNAME=json

.qpp.cpp:
	qpp -V $<

GENERATED_SOURCES = QC_JsonRpcClient.cpp ql_json.cpp
CLEANFILES = $(GENERATED_SOURCES)

if COND_SINGLE_COMPILATION_UNIT
single-compilation-unit.cpp: $(GENERATED_SOURCES)
JSON_SOURCES = single-compilation-unit.cpp
else
JSON_SOURCES = json-module.cpp
nodist_json_la_SOURCES = $(GENERATED_SOURCES)
endif

lib_LTLIBRARIES = json.la
json_la_SOURCES = $(JSON_SOURCES)
json_la_LDFLAGS = -module -avoid-version ${MODULE_LDFLAGS}

INCLUDES = -I$(top_srcdir)/include

AM_CPPFLAGS=$(QORE_CPPFLAGS) $(OPENSSL_CPPFLAGS)

if COND_PROFILE
AM_CXXFLAGS=-g -pg
else
if COND_DEBUG
AM_CXXFLAGS=-g
endif
endif

if COND_MINGW
RM_OTHER=$(DESTDIR)$(libdir)/$(MNAME).dll.a
endif

install-exec-hook:
	mv $(DESTDIR)$(libdir)/$(MNAME).$(MODULE_SUFFIX) $(DESTDIR)$(libdir)/$(MNAME)-api-$(MODULE_API).qmod
	$(RM) $(DESTDIR)$(libdir)/$(MNAME).la $(DESTDIR)$(libdir)/$(MNAME).a $(RM_OTHER)
