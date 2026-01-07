Name:           mtree-netbsd
%global         buildtag        1.0.0
Version:        %{buildtag}
Release:        2%{?dist}
Summary:        NetBSD mtree utility for file hierarchy verification

License:        BSD
URL:            https://github.com/jashank/mtree-netbsd/
Source0:        mtree-netbsd-%{buildtag}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libtool
BuildRequires:  libnbcompat-devel

Requires:       libnbcompat

# This package contains mtree.5, we do not want to conflict with
# Maybe we could use this library in the future?
Requires:       libarchive


%description
This project is a port of NetBSD's mtree utility to Linux.

%prep
%autosetup -n %{name}-%{version}
bash ./autogen.sh

%build
# Disable treating format-security as an error to avoid build failures
# caused by non-literal format strings in some upstream code.
export CFLAGS="$CFLAGS -Wno-error=format-security"
%configure --prefix=/usr
%make_build

%install
%make_install

# Remove unwanted files
rm -rf %{buildroot}%{_docdir}/mtree-netbsd
ls -l %{buildroot}%{_mandir}/man5/mtree.5
ls -l %{buildroot}%{_mandir}

rm -f %{buildroot}%{_mandir}/man5/mtree.5
gzip -9 %{buildroot}%{_mandir}/man8/mtree.8

%files
%doc README
%{_bindir}/mtree
%{_mandir}/man8/mtree.8*
# mtree.5 intentionally disabled due to conflicts with existing mtree packages (man page conflicts).
# Keeping the packaging line commented out to avoid file conflicts on install.
%{_docdir}/packages/mtree/*

%changelog

* Tue Jan 06 2026 Package Maintainer <jonny@jonny.eng.br> - 1.0.0-2
- Disable packaging of mtree.5 (man5) to avoid conflicts with other mtree
packages.
* Fri Jan 02 2026 Package Maintainer <jonny@jonny.eng.br> - 1.0.0-1
- Initial COPR package for mtree-netbsd
- Based on upstream release tag 1.0.0
