Summary:	%{distribution} bug helper
Name:		omdv-bug-report
Version:	0.0.4
Release:	1
License:	GPLv3+
Group:		System/Base
Url:		%{disturl}
Source0:	%{name}.sh
BuildArch:	noarch
%rename omv-bug-report
Requires:	basesystem
Suggests:	zstd

%description
A simple tool to gather system information to ease bug resolve.

%prep

%build

%install
mkdir -p %{buildroot}%{_bindir}
install -m755 %{SOURCE0} %{buildroot}%{_bindir}/%{name}
ln -sf %{_bindir}/%{name} %{buildroot}%{_bindir}/%{name}.sh
# old names
ln -sf %{_bindir}/omv-bug-report %{buildroot}%{_bindir}/%{name}.sh

%files
%{_bindir}/*
