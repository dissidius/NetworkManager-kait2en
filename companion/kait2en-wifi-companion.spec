Name: kait2en-wifi-companion
Version: 0.1.0
Release: 1%{?dist}
Summary: Experimental Apple T2 BCM4364 same-channel AP companion
License: MIT
URL: https://github.com/dissidius/NetworkManager-kait2en
Source0: %{name}-%{version}.tar.gz
BuildArch: noarch
BuildRequires: python3
BuildRequires: systemd-rpm-macros
Requires: python3
Requires: NetworkManager
Requires: iw
Requires: iproute
Requires: systemd

%description
Opt-in companion that creates a virtual wireless interface and synchronizes
a dedicated NetworkManager hotspot profile with a compatible uplink.

%prep
%setup -q

%build

%check
python3 test_policy.py

%install
install -Dm755 kait2en-wifi %{buildroot}%{_libexecdir}/kait2en-wifi
install -Dm644 kait2en-wifi.conf %{buildroot}%{_sysconfdir}/kait2en-wifi.conf
install -Dm644 kait2en-wifi.service %{buildroot}%{_unitdir}/kait2en-wifi.service
install -Dm644 kait2en-wifi.timer %{buildroot}%{_unitdir}/kait2en-wifi.timer

# Do not preset or start this experimental service on installation.
%post
%systemd_postun kait2en-wifi.timer kait2en-wifi.service

%preun
%systemd_preun kait2en-wifi.timer kait2en-wifi.service

%postun
%systemd_postun kait2en-wifi.timer kait2en-wifi.service

%files
%license LICENSE
%doc README.md
%{_libexecdir}/kait2en-wifi
%config(noreplace) %{_sysconfdir}/kait2en-wifi.conf
%{_unitdir}/kait2en-wifi.service
%{_unitdir}/kait2en-wifi.timer
