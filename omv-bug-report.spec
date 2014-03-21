Summary:	OMV bug helper
Name:		omv-bug-report
Version:	0.0.1
Release:	1
License:	GPLv3+
Group:		System/Base
Url:		%{disturl}
Source0:	%{name}.sh
BuildArch:	noarch
Requires:	basesystem
Requires:	xz

%description
A simple tool to gather system information to ease bug resolve.

%prep
%setup -q

%build

%install

mkdir -p %{buildroot}%{_bindir}
install -m755 %{SURCE0} %{buildroot}%{_bindir}/%{name}.sh

%files
%{_bindir}/%{name}.sh
