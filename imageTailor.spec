Name:         imageTailor
Summary:      Cut out the ISO
License:      Mulan PSL v2
Group:        System/Management
Version:      1.0.1
Release:      1
BuildRoot:    %{_tmppath}/%{name}-%{version}
Source:       https://gitee.com/openeuler/imageTailor/repository/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
Requires:     dnf-utils tar python3 drpm genisoimage python3-kiwi kiwi-tools kiwi-systemdeps
%description
Dopralinux custom tool

%prep
%setup -c

%install
iso_arch=$(uname -m)
mkdir -p %{buildroot}/opt/imageTailor
cd %{name}
cp -a conf/${iso_arch}/* %{buildroot}/opt/imageTailor
cp -a conf/common/* %{buildroot}/opt/imageTailor
cp -a mkdliso %{buildroot}/opt/imageTailor

for file in `find %{buildroot}/opt/imageTailor -name "security_s.conf"`;do chmod 600 $file;done
for file in `find %{buildroot}/opt/imageTailor -name "S00setcap"`;do chmod 600 $file;done
for file in `find %{buildroot}/opt/imageTailor -name "S00reboot"`;do chmod 600 $file;done
for file in `find %{buildroot}/opt/imageTailor -name "isopackage.sdf"`;do chmod 600 $file;done

chmod 600 %{buildroot}/opt/imageTailor/custom/cfg_*/cmd.conf
chmod 600 %{buildroot}/opt/imageTailor/custom/cfg_*/rpm.conf
chmod 600 %{buildroot}/opt/imageTailor/custom/cfg_*/security_s.conf
chmod 600 %{buildroot}/opt/imageTailor/custom/cfg_*/sys.conf

chmod -R 500 %{buildroot}/opt/imageTailor/kiwi/hook/config.sh
chmod -R 500 %{buildroot}/opt/imageTailor/kiwi/hook/images.sh
chmod -R 500 %{buildroot}/opt/imageTailor/mkdliso

cd -

%pre

%post

%preun

%postun


%files
%defattr(-,root,root)
%dir /opt/imageTailor
/opt/imageTailor/*

%clean
rm -rf $RPM_BUILD_ROOT/*
rm -rf %{_tmppath}/%{name}-%{version}
rm -rf $RPM_BUILD_DIR/%{name}-%{version}

%changelog
* Thu Mar 03 2022 xinsheng<xinsheng3@huawei.com> - 1.0.1-1
- ID:NA
- SUG:NA
- DESC:append arm ko for pxe

* Mon Feb 28 2022 xinsheng<xinsheng3@huawei.com> - 1.0.0-1
- ID:NA
- SUG:NA
- DESC:package init
