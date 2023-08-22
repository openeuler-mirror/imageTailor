:<<!
 * Copyright (c) Huawei Technologies Co., Ltd. 2018-2023. All rights reserved.
 * imageTailor licensed under the Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *     http://license.coscl.org.cn/MulanPSL2
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR
 * PURPOSE.
 * See the Mulan PSL v2 for more details.
 * Author:
 * Create: 2023-06-06
 * Description: provide raspberryPi make functions
!

#!/bin/bash

function set_pwd() {
  usr_name=$1
  usr_pwd=$2
  chmod 600 /etc/shadow
  str=$(sed -n "/^${usr_name}:/p" /etc/shadow | awk -F "${usr_name}:" '{print $2}')
  mv /etc/shadow /etc/shadow_bak
  sed -i "/^${usr_name}:/d" /etc/shadow_bak
  echo "${usr_name}:"${usr_pwd}${str:1} >/etc/shadow
  cat /etc/shadow_bak >>/etc/shadow
  rm -rf /etc/shadow_bak
  chmod 000 /etc/shadow
}

systemctl enable sshd
systemctl enable systemd-timesyncd
systemctl enable hciuart
systemctl enable haveged
echo openEuler >/etc/hostname

# 设置root/pi密码；pi用户与树莓派官方保持默认密码
set_pwd root "${ROOT_PWD}"
useradd -m -G "wheel" -s "/bin/bash" pi
set_pwd pi "${PI_PWD}"

if [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
  if [ -f /etc/localtime ]; then
    rm -f /etc/localtime
  fi
  ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
fi

if [ -f /etc/rc.d/rc.local ]; then
  chmod +x /etc/rc.d/rc.local
fi
cd /etc/rc.d/init.d

chmod +x extend-root.sh
chkconfig --add extend-root.sh
chkconfig extend-root.sh on

cd -
ln -s /lib/firmware /etc/firmware

if [ -f /etc/locale.conf ]; then
  sed -i -e "s/^LANG/#LANG/" /etc/locale.conf
fi
echo 'LANG="en_US.utf8"' >>/etc/locale.conf
