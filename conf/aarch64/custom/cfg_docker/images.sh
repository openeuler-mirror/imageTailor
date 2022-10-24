:<<!
 * Copyright (c) Huawei Technologies Co., Ltd. 2018-2022. All rights reserved.
 * imageTailor licensed under the Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *     http://license.coscl.org.cn/MulanPSL2
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR
 * PURPOSE.
 * See the Mulan PSL v2 for more details.
 * Author:
 * Create: 2022-10-18
 * Description: provide making docker image function, used as setting
!

#!/bin/bash

set -e

echo "Configure image: [${kiwi_iname}]..."
euler_version=${kiwi_iname%%-*}
compile_time=${kiwi_iname#*-}
echo "eulerversion=${euler_version}" > /etc/EulerLinux.conf
echo "compiletime=${compile_time}"  >> /etc/EulerLinux.conf

set +e
# Security enforce
export EULEROS_SECURITY=0
/usr/sbin/security-tool.sh -d / -c /etc/euleros_security/security.conf -u /etc/euleros_security/usr-security.conf -l /var/log/euleros-security.log -s
echo "export TMOUT=300" >> /etc/bashrc

# uninstall security-tool and its related dependency
# uninstall security-tool package will cause /etc/pam.d rollback, so backup the dir and the restore it after the uninstalling
cp -af /etc/pam.d /etc/pam.d.bak

rm -f /etc/yum/protected.d/sudo.conf /etc/yum/protected.d/systemd.conf
yum remove -y security-tool cronie systemd
rpm -e --nodeps logrotate crontabs
rm -rf /etc/pam.d
mv /etc/pam.d.bak /etc/pam.d

#security-tools will change some config file, so rpm erase will leave them as rpmsave.
sh -c 'shopt -s globstar; for f in $(ls /**/*.rpmsave); do rm -f $f; done'

# after uninstall security-tool
[ -d /var/lib/dnf ] && rm -rf /var/lib/dnf/*
set -e
[ -d /var/lib/rpm ] && rm -rf /var/lib/rpm/__db.*

# remove boot
rm -rf /boot

# only keep en_US locale
cd /usr/lib/locale;rm -rf $(ls | grep -v en_US | grep -vw C.utf8 )
rm -rf /usr/share/locale/*

# remove man pages and documentation
rm -rf /usr/share/{man,doc,info,mime}

# remove ldconfig/dnf cache and log
rm -rf /etc/ld.so.cache
[ -d /var/cache/ldconfig ] && rm -rf /var/cache/ldconfig/*
[ -d /var/cache/dnf ] && rm -rf /var/cache/dnf/*
[ -d /var/log ] && rm -rf /var/log/*.log

# keep machine-id/ca-certificates bep
rm -rf /etc/pki/ca-trust/extracted/java/cacerts /etc/pki/java/cacerts
rm -rf /etc/machine-id

# remove empty link of file mtab
rm -rf /etc/mtab

# DTS2022060914319 remove empty link, we do not provide systemd in base image, so rm all
rm -rf /etc/systemd