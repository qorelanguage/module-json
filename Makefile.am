moddir = $(userlibdir)

AUTOMAKE_OPTIONS = foreign

SUBDIRS = src

noinst_HEADERS = src/QC_JsonRpcClient.h \
	src/ql_json.h \
	src/qore-json-module.h

USER_MODULES = qlib/JsonRpcHandler.qm qlib/JsonRpcConnection.qm

EXTRA_DIST = COPYING.LGPL COPYING.MIT AUTHORS README \
	RELEASE-NOTES \
	src/QC_JsonRpcClient.qpp \
	src/ql_json.qpp \
	test/json.qtest \
	examples/json-rpc-client.q \
	examples/JsonRpcServerValidation.q \
	qore-json-module.spec \
    CMakeLists.txt \
    cmake/cmake_uninstall.cmake.in

ACLOCAL_AMFLAGS=-I m4

dist_mod_DATA = $(USER_MODULES)

if COND_DOXYGEN
DOX = json JsonRpcHandler JsonRpcConnection
DOXYGEN_OUTPUT=docs/json/html docs/JsonRpcHandler/html docs/JsonRpcConnection/html
DOXYFILES = docs/doxyfile docs/mainpage.doxygen
DOXYFILES_SRC = docs/doxyfile.tmpl docs/qlib/Doxyfile.tmpl docs/footer_template.html
QLIB_TMP_DOXYFILES = docs/qlib/JsonRpcHandler.qm.dox.h docs/qlib/Doxyfile.JsonRpcHandler docs/qlib/JsonRpcConnection.qm.dox.h docs/qlib/Doxyfile.JsonRpcConnection
QDX = qdx
DX_CLEANFILES = ${DOXYFILES} $(QLIB_TMP_DOXYFILES)

docs/qlib/Doxyfile.tmp: docs/qlib/Doxyfile.tmpl
	sed s:__USERMODDIR__:${usermoddir}: $< > $@

docs/qlib/Doxyfile.JsonRpcHandler: docs/qlib/Doxyfile.tmp
	$(QDX) -M=qlib/JsonRpcHandler.qm:qlib/JsonRpcHandler.qm.dox.h -tjson.tag=../../json/html $< $@

docs/qlib/JsonRpcHandler.qm.dox.h: qlib/JsonRpcHandler.qm
	$(QDX) $< $@

docs/JsonRpcHandler/html: docs/qlib/JsonRpcHandler.qm.dox.h docs/qlib/Doxyfile.JsonRpcHandler
	cd docs; $(DOXYGEN_CMD) qlib/Doxyfile.JsonRpcHandler
	$(QDX) --post docs/JsonRpcHandler/html docs/JsonRpcHandler/html/search

docs/qlib/Doxyfile.JsonRpcConnection: docs/qlib/Doxyfile.tmp
	sed s:__USERMODDIR__:${usermoddir}: $< > $@
	$(QDX) -M=qlib/JsonRpcConnection.qm:qlib/JsonRpcConnection.qm.dox.h -tjson.tag=../../json/html $< $@

docs/qlib/JsonRpcConnection.qm.dox.h: qlib/JsonRpcConnection.qm
	$(QDX) $< $@

docs/JsonRpcConnection/html: docs/qlib/JsonRpcConnection.qm.dox.h docs/qlib/Doxyfile.JsonRpcConnection
	cd docs; $(DOXYGEN_CMD) qlib/Doxyfile.JsonRpcConnection
	$(QDX) --post docs/JsonRpcConnection/html docs/JsonRpcConnection/html/search

docs/json/html: $(DOXYFILES)
	cd docs; $(DOXYGEN_CMD) doxyfile;
	$(QDX) --post docs/json/html docs/json/html/search

docs/mainpage.doxygen: docs/mainpage.doxygen.tmpl
	$(QDX) -d $< $@

docs/doxyfile: docs/doxyfile.tmpl
	sed -e s/__VERSION__/${VERSION}/ -e s:__USERMODDIR__:${usermoddir}: $< > $@

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
