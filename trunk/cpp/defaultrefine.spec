Summary: An implementation of the Default&Refine algorithm
Name: defaultrefine
Version: 0.1.0
Release: 1%{?dist}
URL: http://code.google.com/p/defaultrefine/
Source0: %{name}-%{version}.tar.gz
License: GPL
Group: System Environment/Libraries
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Prefix: /usr
Requires: boost

%description
An implementation of the Default&Refine algorithm.

%package devel
Requires: %{name} = %{version}-%{release},pkgconfig
Group: Development/Libraries
Summary: Header files for libg2p - an implementation of the Default&Refine algorithm.

%description devel
Header files and documentation you can use to develop with libg2p.

%prep
%setup -q -n %{name}-%{version}

%build
sed -i.libdir_syssearch -e '/sys_lib_dlsearch_path_spec/s|/usr/lib |/usr/lib /usr/lib64 /lib /lib64 |' configure
%configure
%{__make} -k %{?_smp_mflags} DESTDIR=$RPM_BUILD_ROOT

%install
%{__rm} -rf $RPM_BUILD_ROOT
%{__make} DESTDIR=$RPM_BUILD_ROOT TARGET=$RPM_BUILD_ROOT INSTALL="install -p" install

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%ifnos solaris2.8 solaris2.9 solaris2.10
%post -p /sbin/ldconfig
%endif

%ifnos solaris2.8 solaris2.9 solaris2.10
%postun -p /sbin/ldconfig
%endif

%files
%defattr(755,root,root)
%{_bindir}/defaultrefine
%{_libdir}/libg2p.so.0.0.0
%{_libdir}/libg2p.so.0

%files devel
%defattr(-,root,root)
%exclude %{_libdir}/*.la
%exclude %{_libdir}/*.a
%{_includedir}/libg2p
%{_libdir}/libg2p.so
%{_libdir}/pkgconfig/libg2p.pc

%changelog
* Thu Sep 29 2011 J.W.F. Thirion <thirionjwf@gmail.com> - 0.1.0-1
- Initial package.
