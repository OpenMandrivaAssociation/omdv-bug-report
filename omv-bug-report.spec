Summary:	OMV bug helper
Name:		omv-bug-report
Version:	0.0.3
Release:	1
License:	GPLv3+
Group:		System/Base
Url:		%{disturl}
Source0:	%{name}.sh
BuildArch:	noarch
Requires:	basesystem
Requires:	zstd

%description
A simple tool to gather system information to ease bug resolve.

%prep

%build

%install

mkdir -p %{buildroot}%{_bindir}
install -m755 %{SOURCE0} %{buildroot}%{_bindir}/%{name}
ln -sf %{_bindir}/%{name} %{buildroot}%{_bindir}/%{name}.sh

%files
%{_bindir}/%{name}*
