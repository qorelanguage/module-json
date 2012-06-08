modverdir = $(libdir)/$(mymodverdir)

AUTOMAKE_OPTIONS = foreign

SUBDIRS = src

noinst_HEADERS = src/QC_JsonRpcClient.h \
	src/ql_json.h \
	src/qore-json-module.h

USER_MODULES = qlib/JsonRpcHandler.qm

EXTRA_DIST = COPYING ChangeLog AUTHORS README \
	RELEASE-NOTES \
	src/QC_JsonRpcClient.qpp \
	src/ql_json.qpp \
	test/json-test.q \
	examples/HttpServer.qc \
	examples/json-rpc-client.q \
	examples/JsonRpcHandler.qc \
	examples/JsonRpcServerValidation.q \
	qore-json-module.spec

ACLOCAL_AMFLAGS=-I m4

dist_modver_DATA = $(USER_MODULES)

if COND_DOXYGEN
DOX = json JsonRpcHandler
DOXYGEN_OUTPUT=docs/json/html docs/JsonRpcHandler/html
DOXYFILES = docs/doxyfile docs/mainpage.doxygen
DOXYFILES_SRC = docs/doxyfile.tmpl docs/qlib/Doxyfile.tmpl docs/footer_template.html
QLIB_TMP_DOXYFILES = docs/qlib/JsonRpcHandler.qm.dox.h docs/qlib/Doxyfile.JsonRpcHandler
QDX = qdx
DX_CLEANFILES = ${DOXYFILES} $(QLIB_TMP_DOXYFILES)

docs/qlib/Doxyfile.JsonRpcHandler: docs/qlib/Doxyfile.tmpl
	$(QDX) -M=qlib/JsonRpcHandler.qm:docs/qlib/JsonRpcHandler.qm.dox.h $< $@

docs/qlib/JsonRpcHandler.qm.dox.h: qlib/JsonRpcHandler.qm
	$(QDX) $< $@

docs/JsonRpcHandler/html: docs/qlib/JsonRpcHandler.qm.dox.h docs/qlib/Doxyfile.JsonRpcHandler
	$(DOXYGEN_CMD) docs/qlib/Doxyfile.JsonRpcHandler
	$(QDX) --post docs/JsonRpcHandler/html/*html
	$(QDX) --post docs/JsonRpcHandler/html/search/*html

docs/json/html: $(DOXYFILES)
	cd docs; $(DOXYGEN_CMD) doxyfile;
	$(QDX) --post docs/json/html/*html
	$(QDX) --post docs/json/html/search/*html

docs/mainpage.doxygen: docs/mainpage.doxygen.tmpl
	$(QDX) -d $< $@

docs/doxyfile: docs/doxyfile.tmpl
	sed s/__VERSION__/${VERSION}/ $< > $@

doxygen-doc: $(DOXYGEN_OUTPUT)

EXTRA_DIST += $(DOXYGEN_OUTPUT)

html-local: $(DOXYGEN_OUTPUT)

install-html-local:
	for dox in $(DOX); do $(MKDIR_P) $(DESTDIR)$(datadir)/$(PACKAGE)/docs/$$dox/html/search; done
	for dir in $(DOXYGEN_OUTPUT); do \
	   for f in $$dir/*; do if [ -f $$f ]; then $(INSTALL_DATA) $$f $(DESTDIR)$(datadir)/$(PACKAGE)/$$dir; fi; done; \
	   for f in $$dir/search/*; do $(INSTALL_DATA) $$f $(DESTDIR)$(datadir)/$(PACKAGE)/$$dir/search; done; \
	done

clean-local:
	$(RM) -rf $(DOXYGEN_OUTPUT)

uninstall-local:
	$(RM) -rf $(DESTDIR)$(datadir)/$(PACKAGE)/docs

mostlyclean-local:
	rm -rf ${DOXYGEN_OUTPUT} ${DX_CLEANFILES}

else
doxygen-doc:
	echo no doxygen support
endif

libtool: $(LIBTOOL_DEPS)
	$(SHELL) ./config.status --recheck
