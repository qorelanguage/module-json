%define mod_ver 1.12

%{?_datarootdir: %global mydatarootdir %_datarootdir}
%{!?_datarootdir: %global mydatarootdir /usr/share}

%define module_api %(qore --latest-module-api 2>/dev/null)
%define module_dir %{_libdir}/qore-modules
%global user_module_dir %{mydatarootdir}/qore-modules/

%if 0%{?sles_version}

%define dist .sles%{?sles_version}

%else
%if 0%{?suse_version}

# get *suse release major version
%define os_maj %(echo %suse_version|rev|cut -b3-|rev)
# get *suse release minor version without trailing zeros
%define os_min %(echo %suse_version|rev|cut -b-2|rev|sed s/0*$//)

%if %suse_version
%define dist .opensuse%{os_maj}_%{os_min}
%endif

%endif
%endif

# see if we can determine the distribution type
%if 0%{!?dist:1}
%define rh_dist %(if [ -f /etc/redhat-release ];then cat /etc/redhat-release|sed "s/[^0-9.]*//"|cut -f1 -d.;fi)
%if 0%{?rh_dist}
%define dist .rhel%{rh_dist}
%else
%define dist .unknown
%endif
%endif

Summary: JSON module for Qore
Name: qore-json-module
Version: %{mod_ver}
Release: 1%{dist}
License: MIT
Group: Development/Languages/Other
URL: http://qore.org
Source: http://prdownloads.sourceforge.net/qore/%{name}-%{version}.tar.bz2
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Requires: /usr/bin/env
Requires: qore-module(abi)%{?_isa} = %{module_api}
%if 0%{?el7}
BuildRequires:  devtoolset-7-gcc-c++
%endif
BuildRequires: cmake >= 3.5
BuildRequires: gcc-c++
BuildRequires: qore-devel >= 2.0
BuildRequires: qore-stdlib >= 2.0
BuildRequires: qore >= 2.0
BuildRequires: doxygen
BuildRequires: openssl-devel

%description
This package contains the json module for the Qore Programming Language.

JSON is a concise human-readable data serialization format.

%if 0%{?suse_version}
%debug_package
%endif

%prep
%setup -q

%build
%if 0%{?el7}
# enable devtoolset7
. /opt/rh/devtoolset-7/enable
%endif
export CXXFLAGS="%{?optflags}"
cmake -DCMAKE_INSTALL_PREFIX=%{_prefix} -DCMAKE_BUILD_TYPE=RELWITHDEBINFO -DCMAKE_SKIP_RPATH=1 -DCMAKE_SKIP_INSTALL_RPATH=1 -DCMAKE_SKIP_BUILD_RPATH=1 -DCMAKE_PREFIX_PATH=${_prefix}/lib64/cmake/Qore .
make %{?_smp_mflags}
make %{?_smp_mflags} docs
sed -i 's/#!\/usr\/bin\/env qore/#!\/usr\/bin\/qore/' test/*.qtest examples/*

%install
make DESTDIR=%{buildroot} install %{?_smp_mflags}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%{module_dir}
%{user_module_dir}
%doc COPYING.LGPL COPYING.MIT README RELEASE-NOTES AUTHORS

%check
qore -l ./json-api-%{module_api}.qmod test/JsonRpcClient.qtest -v
qore -l ./json-api-%{module_api}.qmod test/JsonRpcHandler.qtest -v
qore -l ./json-api-%{module_api}.qmod test/McpServerHandler.qtest -v
qore -l ./json-api-%{module_api}.qmod test/McpClient.qtest -v
qore -l ./json-api-%{module_api}.qmod test/McpClientDataProvider.qtest -v
qore -l ./json-api-%{module_api}.qmod test/A2aClient.qtest -v
qore -l ./json-api-%{module_api}.qmod test/A2aServerHandler.qtest -v
qore -l ./json-api-%{module_api}.qmod test/A2aClientDataProvider.qtest -v
qore -l ./json-api-%{module_api}.qmod test/FhirRestClient.qtest -v
qore -l ./json-api-%{module_api}.qmod test/FhirR4ArtifactGenerator.qtest -v
qore -l ./json-api-%{module_api}.qmod test/FhirRestDataProvider.qtest -v
qore -l ./json-api-%{module_api}.qmod test/json.qtest -v
qore -l ./json-api-%{module_api}.qmod test/Jwt.qtest -v

%package doc
Summary: JSON module for Qore
Group: Development/Languages

%description doc
This package contains the HTML documentation and example programs for the Qore
json module.

%files doc
%defattr(-,root,root,-)
%doc docs/json docs/JsonRpcConnection docs/JsonRpcHandler docs/McpServerHandler docs/McpClient docs/McpClientDataProvider docs/A2aClient docs/A2aServerHandler docs/A2aClientDataProvider docs/FhirRestClient docs/FhirRestDataProvider test examples

%changelog
* Fri May 16 2026 David Nichols <david@qore.org> - 1.12
- updated to version 1.12
- added TOON serialization support (make_toon/parse_toon)
- added FhirRestClient module for FHIR R4 JSON REST servers
- added FhirRestDataProvider module for FHIR REST DataProvider actions
- added generated FHIR R4 resource type catalog and local validation
- added generated FHIR R4 HashDataType metadata for Patient, Observation, and Bundle
- added generated FHIR R4 resource-specific action metadata for typed resource actions
- added FHIR CapabilityStatement-driven resource validation, paginated search, conditional update,
  patch, and common search parameter mapping

* Sat Mar 14 2026 David Nichols <david@qore.org> - 1.11
- updated to version 1.11
- added CBOR serialization support (make_cbor/parse_cbor)
- added A2aClient module for connecting to A2A agents
- added A2aServerHandler module for A2A server support
- added A2aClientDataProvider module for DataProvider API access to A2A agents
- added A2A Agent Card discovery, message/task lifecycle, push notifications
- added ConnectionProvider integration (a2a://, a2as://)

* Sun Dec 29 2025 David Nichols <david@qore.org> - 1.10
- updated to version 1.10
- added McpClientDataProvider module for DataProvider API access to MCP servers
- added McpClient module for connecting to MCP servers as a client
- added MCP 2025-11-25 protocol version support
- added completion/complete, logging/setLevel methods
- added JSON Pointer (RFC 6901) support
- added ConnectionProvider integration (mcp://, mcps://)
- added comprehensive test coverage

* Fri May 9 2025 David Nichols <david@qore.org> - 1.9.1
- updated to version 1.9.1

* Sun Mar 30 2025 David Nichols <david@qore.org> - 1.9.0
- updated to version 1.9.0

* Mon May 9 2022 David Nichols <david@qore.org> - 1.8.2
- updated to version 1.8.2
- use cmake instead of autotools

* Tue Mar 8 2022 David Nichols <david@qore.org> - 1.8.1
- updated to version 1.8.1

* Fri Jan 26 2018 David Nichols <david@qore.org> - 1.8
- updated to version 1.8

* Sun Dec 4 2016 David Nichols <david@qore.org> - 1.7
- updated to version 1.7

* Mon Nov 14 2016 Ondrej Musil <ondrej.musil@qoretechnologies.com> - 1.6
- updated to version 1.6

* Tue Jan 14 2014 David Nichols <david@qore.org> - 1.5
- updated to version 1.5

* Thu Sep 5 2013 David Nichols <david@qore.org> - 1.4
- updated to version 1.4

* Fri Aug 2 2013 David Nichols <david@qore.org> - 1.3
- updated to version 1.3

* Thu Jun 13 2013 David Nichols <david@qore.org> - 1.2
- updated to version 1.2

* Fri Jun 1 2012 David Nichols <david@qore.org> - 1.1
- updated to qpp build and new docs

* Tue Dec 28 2010 David Nichols <david@qore.org> - 1.1
- updated to version 1.1

* Wed Dec 22 2010 David Nichols <david@qore.org>
- initial spec file for json module
