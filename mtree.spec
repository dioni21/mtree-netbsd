Name:           mtree-netbsd
%global         buildtag        1.0.0
Version:        %{buildtag}
Release:        1%{?dist}
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

# Remove libtool archives
find %{buildroot} -name '*.la' -delete
rm -rf %{buildroot}%{_docdir}/mtree-netbsd

%files
%doc README
%{_bindir}/mtree
%{_mandir}/man8/mtree.8*
%{_mandir}/man5/mtree.5*
%{_docdir}/packages/mtree/*

%changelog
* Fri Jan 02 2026 Package Maintainer <maintainer@example.com> - 1.0.0-1
- Initial COPR package for mtree-netbsd
- Based on upstream release tag 1.0.0
