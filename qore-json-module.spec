%define mod_ver 1.8

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

%if %suse_version > 1010
%define dist .opensuse%{os_maj}_%{os_min}
%else
%define dist .suse%{os_maj}_%{os_min}
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
License: LGPL
Group: Development/Languages
URL: http://qore.org
Source: http://prdownloads.sourceforge.net/qore/%{name}-%{version}.tar.bz2
#Source0: %{name}-%{version}.tar.bz2
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Requires: /usr/bin/env
Requires: qore-module(abi)%{?_isa} = %{module_api}
BuildRequires: gcc-c++
BuildRequires: qore-devel >= 0.9
BuildRequires: openssl-devel
BuildRequires: qore

%description
This package contains the json module for the Qore Programming Language.

JSON is a concise human-readable data serialization format.

%if 0%{?suse_version}
%debug_package
%endif

%prep
%setup -q
./configure RPM_OPT_FLAGS="$RPM_OPT_FLAGS" --prefix=/usr --disable-debug

%build
%{__make}

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{module_dir}
mkdir -p $RPM_BUILD_ROOT/%{user_module_dir}
mkdir -p $RPM_BUILD_ROOT/usr/share/doc/qore-json-module
make install DESTDIR=$RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%{module_dir}
%{user_module_dir}
%doc COPYING.LGPL COPYING.MIT README RELEASE-NOTES AUTHORS

%package doc
Summary: JSON module for Qore
Group: Development/Languages

%description doc
This package contains the HTML documentation and example programs for the Qore
json module.

%files doc
%defattr(-,root,root,-)
%doc docs/json/html docs/JsonRpcHandler/html examples/ test/

%changelog
* Sun Jan 26 2018 David Nichols <david@qore.org> - 1.8
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

* Fri Jun 13 2013 David Nichols <david@qore.org> - 1.2
- updated to version 1.2

* Fri Jun 1 2012 David Nichols <david@qore.org> - 1.1
- updated to qpp build and new docs

* Tue Dec 28 2010 David Nichols <david@qore.org> - 1.1
- updated to version 1.1

* Wed Dec 22 2010 David Nichols <david@qore.org>
- initial spec file for json module
