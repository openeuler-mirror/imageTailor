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
 * Create: 2022-02-28
 * Description: provide image Tailor function, used as hook
!

#!/bin/bash
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

EL_CONFIG='/usr/Euler/conf/euler-release'
EL_CUSTOM_RPM='/usr/custom/rpm'
EL_CUSTOM_USRFILE='/usr/custom/usrfile'
EL_USRRPM_FILELST='/opt/usrrpm_filelst'

sys_man_cut=
if [ -f "${EL_CONFIG}" ]; then
  sys_man_cut=$(cat ${EL_CONFIG} | grep "^sys_man_cut=")
  sys_man_cut=$(echo ${sys_man_cut#*=} | sed "s/^'//g" | sed "s/'$//g")
fi

if [ -z "${sys_man_cut}" ]; then
  sys_man_cut="yes"
fi

function createUsrFileList {
  local usrrpm_cutflag=''

  ## 从EL_CONFIG 得到变量sys_man_cut ##
  if [ -f "${EL_CONFIG}" ]; then
    sed -i '/^#/d' ${EL_CONFIG}
    sed -i '/^$/d' ${EL_CONFIG}
    . ${EL_CONFIG}
  fi

  if [ -d "${EL_CUSTOM_USRFILE}" ] && [ -n "$(ls ${EL_CUSTOM_USRFILE})" ]; then
    find ${EL_CUSTOM_USRFILE} | sed "s#${EL_CUSTOM_USRFILE}##" >>${EL_USRRPM_FILELST}
  fi

  usrrpm_cutflag=${sys_usrrpm_cut}
  if [ "${usrrpm_cutflag}" = "yes" ]; then
    return 0
  fi

  if [ -d "${EL_CUSTOM_RPM}" ] && [ -n "$(ls ${EL_CUSTOM_RPM}/*.rpm)" ]; then
    find ${EL_CUSTOM_RPM} -name "*.rpm" | xargs rpm -qpl >${EL_USRRPM_FILELST}
  fi

  return 0
}

function installUserRpm() {
  local usrrpmlog="/var/log/installUserRpm.log"
  if [ -d "${EL_CUSTOM_RPM}" ] && [ -n "$(ls ${EL_CUSTOM_RPM}/*.rpm)" ]; then
    rpm -Uvh --force $(find ${EL_CUSTOM_RPM} -name "*.rpm") >${usrrpmlog} 2>&1
    if [ $? -ne 0 ]; then
      echo "========================================================"
      echo "ERROR: install usr rpm failed"
      cat ${usrrpmlog}
      echo "========================================================"
      return 1
    fi
  fi

  if [ -f "${usrrpmlog}" ]; then
    chmod 640 ${usrrpmlog}
  fi

  rm -rf ${EL_CUSTOM_RPM}
  return 0
}

function configTimeZone() {
  local TIMEZONE=$1
  local UTC=$2
  local ret=0

  if [ -z "${TIMEZONE}" ]; then
    echo "TIMEZONE doesn't set."
    ret=1
  fi

  zic -l ${TIMEZONE}
  if [ $? != 0 ]; then
    echo "zic -l TIMEZONE setting failed."
    ret=1
  fi
  TIMEZONE=$(echo ${TIMEZONE} | sed 's#\/#\\\/#g')

  if [ ! -f "/etc/sysconfig/clock" ]; then
    echo "/etc/sysconfig/clock doesn't exist."
    ret=1
  else
    sed -i "s/^TIMEZONE=.*$/TIMEZONE=\"${TIMEZONE}\"/" /etc/sysconfig/clock
    if [ $? != 0 ]; then
      echo "${TIMEZONE} setting failed."
      ret=1
    fi
  fi

  if [ "${UTC}" = "yes" ]; then
    sed -i "s/^HWCLOCK=.*$/HWCLOCK=\"-U\"/" /etc/sysconfig/clock
    if [ $? != 0 ]; then
      echo "${HWCLOCK} setting failed."
      ret=1
    fi

    hwclock --hctosys -u
    if [ $? != 0 ]; then
      echo "hwclock --hctosys -u setting failed."
      ret=1
    fi
  else
    sed -i "s/^HWCLOCK=.*$/HWCLOCK=\"--localtime\"/" /etc/sysconfig/clock >/dev/null 2>&1
    if [ $? != 0 ]; then
      echo "${HWCLOCK} setting failed."
      ret=1
    fi

    hwclock --hctosys --localtime >/dev/null 2>&1
    if [ $? != 0 ]; then
      echo "hwclock --hctosys --localtime setting failed."
      ret=1
    fi
  fi

  return ${ret}
}

function init_euler_release() {
  local dl_hostname="EULER"
  local dl_service_enable='syslog boot.localnet network sshd'
  local dl_usermodules_autoload=''

  ## obs sp1的/etc/issue.net 为UVP OS ##
  sed -i 's/UVP OS/Euler Linux/' /etc/issue.net
  sed -i 's/UVP OS/Euler Linux/' /etc/issue

  echo "createUsrFileList start ..."
  createUsrFileList

  echo "installUserRpm start ..."
  installUserRpm
  if [ $? -ne 0 ]; then
    return 1
  fi

  cp -a ${EL_CUSTOM_USRFILE}/* /

  if [ -f "${EL_CONFIG}" ]; then
    sed -i '/^#/d' "${EL_CONFIG}"
    sed -i '/^$/d' "${EL_CONFIG}"
    . ${EL_CONFIG}
  fi

  if [ -n "${sys_hostname}" ]; then
    dl_hostname="${sys_hostname}"
  fi
  echo "${dl_hostname}" >/etc/hostname

  if [ -f /etc/hosts.rpmnew ]; then
    mv /etc/hosts.rpmnew /etc/hosts
  fi

  if [ -f /etc/hosts ]; then
    sed -i "/\<localhost\>/!d" /etc/hosts
    sed -i "s/ localhost / ${dl_hostname} localhost /g" /etc/hosts
  fi

  echo "configTimeZone start ..."
  configTimeZone "${sys_timezone}" "${sys_utc}"

  echo "suseRemoveAllServices start ..."
  suseRemoveAllServices
  if [ $? -ne 0 ]; then
    echo "error: suseRemoveAllServices failed."
  fi

  if [ -n "${sys_service_enable}" ]; then
    dl_service_enable="${dl_service_enable} ${sys_service_enable}"
  fi

  echo "suseInsertService start ..."
  for i in ${dl_service_enable}; do
    suseInsertService $i
    if [ $? -ne 0 ]; then
      echo "error: suseInsertService ${i} failed."
    fi
  done

  echo "suseRemoveService start ..."
  if [ -n "${sys_service_disable}" ]; then
    for i in ${sys_service_disable}; do
      suseRemoveService $i
      if [ $? -ne 0 ]; then
        echo "error: suseRemoveService ${i} failed."
      fi
    done
  fi

  if [ -n "${eulerlinux_usermodules_autoload}" ]; then
    dl_usermodules_autoload="${eulerlinux_usermodules_autoload}"
  fi

  if [ -n "${sys_usermodules_autoload}" ]; then
    dl_usermodules_autoload="${sys_usermodules_autoload} ${dl_usermodules_autoload}"
  fi

  for i in ${dl_usermodules_autoload}; do
    if [ -f /etc/modules ]; then
      grep -w "^$i" /etc/modules
      if [ $? -ne 0 ]; then
        echo "$i" >>/etc/modules
      fi
    else
      echo "$i" >>/etc/modules
    fi
  done

  if [ -f /etc/modules ] && [ -d /etc/modules-load.d ]; then
    ln -s /etc/modules /etc/modules-load.d/modules.conf
  fi

  echo "getcap start ..."
  getcap /usr/bin/* /usr/sbin/* >/root/.cap || true
}

echo "Configure image: [${kiwi_iname}]..."

echo "init_euler_release start ..."
init_euler_release
if [ $? -ne 0 ]; then
  exit 1
fi

echo "suseConfig start ..."
suseConfig
if [ $? -ne 0 ]; then
  echo "error: suseConfig failed."
fi

if [ "${sys_man_cut}" = "no" ]; then
  :
else
  echo "baseStripDocs start ..."
  baseStripDocs
  if [ $? -ne 0 ]; then
    echo "error: baseStripDocs failed."
  fi
fi

echo "baseCleanMount start ..."
baseCleanMount
if [ $? -ne 0 ]; then
  echo "error: baseCleanMount failed."
fi

exit 0
