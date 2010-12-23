AUTOMAKE_OPTIONS = foreign

SUBDIRS = src

DOXYGEN_QORE_API_FILTER=docs/doxygen-api-filter.q
DOXYGEN_OUTPUT=docs/json

DOXYFILES = docs/doxyfile \
	docs/mainpage.doxygen \
	docs/json.q \
	docs/JsonRpcClient.qc

noinst_HEADERS = src/QC_JsonRpcClient.h \
	src/ql_json.h \
	src/qore-json-module.h

EXTRA_DIST = COPYING ChangeLog AUTHORS README \
	RELEASE-NOTES \
	test/json-test.q \
	examples \
	qore-json-module.spec

ACLOCAL_AMFLAGS=-I m4

if COND_DOXYGEN
DX_CLEANFILES = ${DOXYFILES}
docs/json/html: $(DOXYFILES)
	cd docs; $(DOXYGEN_CMD) doxyfile;
	$(DOXYGEN_QORE_API_FILTER) --post $(DOXYGEN_OUTPUT)/html/*html
	$(DOXYGEN_QORE_API_FILTER) --post $(DOXYGEN_OUTPUT)/html/search/*html

doxygen-doc: docs/json/html

EXTRA_DIST += docs/json/html

else
doxygen-doc:
	echo no doxygen support
endif

mostlyclean-local:
	rm -rf ${DOXYGEN_OUTPUT} ${DX_CLEANFILES}

docs/mainpage.doxygen: docs/mainpage.doxygen.tmpl
	$(DOXYGEN_QORE_API_FILTER) -l $<

docs/doxyfile: docs/doxyfile.tmpl
	sed s/__VERSION__/${VERSION}/ $< > $@

docs/json.q: src/ql_json.cpp
	$(DOXYGEN_QORE_API_FILTER) $< $@

docs/JsonRpcClient.qc: src/QC_JsonRpcClient.cpp
	$(DOXYGEN_QORE_API_FILTER) $< $@

libtool: $(LIBTOOL_DEPS)
	$(SHELL) ./config.status --recheck
