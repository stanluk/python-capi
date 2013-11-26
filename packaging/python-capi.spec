Name:           python-capi
Version:        0.1.0
Release:        0
License:        LGPL2.1
Summary:        CAPI Application python bindings
Url:            http://www.tizen.org
Group:          EFL
Source:         %{name}-%{version}.tar.bz2
Source1001: 	python-capi.manifest
BuildRequires:  python-devel
BuildRequires:  pkgconfig(capi-appfw-application)
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
Capi Application python bindings.

%package devel
Summary:        Development files for %{name}
Group:          Development/Python

%description devel
Development files for %{name}.

%prep
%setup -q
cp %{SOURCE1001} .

%build
./autogen.sh
%configure
make %{?_smp_mflags}

%install
%make_install

%files
%manifest %{name}.manifest
%defattr(-,root,root)
%{_libdir}/python2.7/site-packages/capi


%files devel
%manifest %{name}.manifest
%{_libdir}/pkgconfig/*.pc


%changelog
