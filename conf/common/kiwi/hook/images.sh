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
echo "Configure image: [${kiwi_iname}]..."

workdir=/opt/trans-workdir
rpmlistdir=${workdir}/rpmlist
rpmandsrclist=${workdir}/rpm_to_src
srclist=${workdir}/src_list
binlist=${workdir}/bin_list
filelist=${workdir}/all_file

rm -rf ${workdir}/*
mkdir -p ${workdir}
mkdir -p ${rpmlistdir}

function getFileListAndSrcList() {
  which rpm >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    return
  fi

  echo "rpm_sort_list start ..."
  rpm_sort_list=$(rpm -qa)
  echo "rpm_sort_list end"

  for rpmn in ${rpm_sort_list}; do
    rpm -ql ${rpmn} >${rpmlistdir}/${rpmn}
    if [ $? -ne 0 ]; then
      echo "get src info error: failed to get the rpm files."
      return
    fi

    echo ${rpmn} $(rpm -q --qf "%{SOURCERPM}" ${rpmn} | sed 's/.src.rpm//g') >>${rpmandsrclist}
    if [ $? -ne 0 ]; then
      echo "get src info error: failed to get rpm and src."
      return
    fi
  done
}

function findAllFiles() {
  find / -type f | grep -v '^/proc' | grep -v '/etc/ima/digest_lists' >${filelist}
  if [ $? -ne 0 ]; then
    echo "get src info error: findAllFiles failed."
    return 1
  fi

  for dir in /usr/bin/ /usr/sbin/ /usr/lib/ /usr/lib64/; do
    grep ^${dir} ${filelist} | sed 's:^/usr/:/:g' >>${filelist}
    if [ $? -ne 0 ]; then
      echo "error: sed filelist failed: ${dir}"
      return 1
    fi
  done

  if [ ! -s ${filelist} ]; then
    return 1
  fi
}

function getAllFilesAndPrint() {
  findAllFiles
  if [ $? -ne 0 ]; then
    echo "get src info error: failed to find all files."
    return 1
  fi

  echo "start print initrd file list"
  cat ${filelist}
  echo "end print initrd file list"
}

function getSrcInfo() {
  rpm --test >/dev/null 2>&1
  if [ $? -eq 0 -a "${sys_cut}" = "no" ]; then
    getSrcInfoFromRpm
    return
  fi

  if [ ! -f "${rpmandsrclist}" ]; then
    getAllFilesAndPrint
    return
  fi

  findAllFiles
  if [ $? -ne 0 ]; then
    echo "get src info error: failed to find all files."
    return 1
  fi

  while read line; do
    find_rpm=$(grep ^${line}$ ${rpmlistdir}/* | awk -F ':' '{print $1}')
    if [ -n "${find_rpm}" ]; then
      for rname in ${find_rpm}; do
        grep $(basename $rname) ${rpmandsrclist} | awk '{print $2}' >>${workdir}/find_src
        if [ $? -ne 0 ]; then
          echo "get src info error: failed to grep ${rname} ${rpmandsrclist}."
          return 1
        fi

        grep $(basename $rname) ${rpmandsrclist} | awk '{print $1}' >>${workdir}/find_info
        if [ $? -ne 0 ]; then
          echo "get bin info error: failed to grep ${rname} ${rpmandsrclist}."
          return 1
        fi
      done
    else
      echo ${line} >>${workdir}/not_grep_files.log
    fi
  done <${filelist}

  cat ${workdir}/find_src | sort | uniq >${srclist}
  catSrcInfoToLog

  cat ${workdir}/find_info | sort | uniq >${binlist}
  catBinInfoToLog
}

function catBinInfoToLog() {
  echo "start print bin info"
  cat ${binlist}
  echo "end print bin info"
}

function catSrcInfoToLog() {
  echo "start print src info"
  cat ${srclist}
  echo "end print src info"
}

function getSrcInfoFromRpm() {
  rpm -qa --qf "%{SOURCERPM}\n" | sed 's/.src.rpm//g' | uniq >${srclist}
  if [ $? -ne 0 ]; then
    echo "get src info error: getSrcInfoFromRpm failed."
    return
  fi

  catSrcInfoToLog

  rpm -qa | uniq >${binlist}
  if [ $? -ne 0 ]; then
    echo "get bin info error: getBinInfoFromRpm failed."
    return
  fi

  catBinInfoToLog
}

EL_CONFIG='/usr/Euler/conf/euler-release'
EL_USRRPM_FILELIST='/opt/usrrpm_filelst'
EL_UER_KOLST='/opt/usrrpm_filelst_kolst'

sys_cut=
sys_language=
sys_gconv=
sys_translations=
if [ -f ${EL_CONFIG} ]; then
  sys_cut=$(cat $EL_CONFIG | grep "^sys_cut=")
  sys_cut=$(echo ${sys_cut#*=} | sed "s/^'//g" | sed "s/'$//g")

  sys_language=$(cat $EL_CONFIG | grep "^sys_language=")
  sys_language=$(echo ${sys_language#*=} | sed "s/^'//g" | sed "s/'$//g")

  sys_gconv=$(cat $EL_CONFIG | grep "^sys_gconv=")
  sys_gconv=$(echo ${sys_gconv#*=} | sed "s/^'//g" | sed "s/'$//g")

  sys_translations=$(cat $EL_CONFIG | grep "^sys_translations=")
  sys_translations=$(echo ${sys_translations#*=} | sed "s/^'//g" | sed "s/'$//g")
fi

#======================================
# default sys_cut=yes
#======================================
if [ -z "${sys_cut}" ]; then
  sys_cut="yes"
fi

if [ -f '/usr/Euler/conf/euler-release' ]; then
  rm -rf /etc/sysconfig/grub
fi

if [ "${sys_cut}" = "yes" ] || [ "${sys_cut}" = "debug" ]; then
  echo "getFileListAndSrcList start ..."
  getFileListAndSrcList
  echo "getFileListAndSrcList end"

  #================================================
  # add usr ko to kiwi_drivers, will keep in system
  #================================================
  echo "read line start ..."
  if [ -f ${EL_USRRPM_FILELIST} ]; then
    grep ^/lib/modules/ ${EL_USRRPM_FILELIST} | grep kernel | grep ko$ >$EL_UER_KOLST
    while read line; do
      koname=${line#/lib/modules/}
      koname=${koname#*/kernel/}
      kiwi_drivers="${kiwi_drivers},${koname}"
    done <$EL_UER_KOLST
  fi
  echo "read line end"

  #================================================
  # remove unneeded kernel files
  #================================================
  echo "suseStripKernel start ..."
  suseStripKernel
  echo "suseStripKernel end"

  #================================================
  # remove unneeded initrd files
  #================================================
  echo "suseStripInitrd start ..."
  suseStripInitrd
  echo "suseStripInitrd end"

  echo "baseStripLocales start ..."
  if [ -z "${sys_language}" ] || [ "${sys_language}" = "null" ] || [ "${sys_language}" = "NULL" ]; then
    baseStripLocales $(for i in $(echo ${kiwi_language} | tr "," " "); do echo -n "${i}.utf8 "; done)
  elif [ "${sys_language}" != "all" ] && [ "${sys_language}" = "ALL" ]; then
    baseStripLocales $(for i in $(echo ${sys_language} | tr "," " "); do echo -n "${i} "; done)
  fi
  echo "baseStripLocales end"

  echo "baseStripTranslations start ..."
  if [ -z "${sys_translations}" ] || [ "${sys_translations}" = "null" ] || [ "${sys_translations}" = "NULL" ]; then
    baseStripTranslations kiwi.mo
  elif [ "${sys_translations}" != "all" ] && [ "${sys_translations}" != "ALL" ]; then
    baseStripTranslations $(for i in $(echo ${sys_translations} | tr "," " "); do echo -n "${i} "; done)
  fi
  echo "baseStripTranslations end"

  echo "baseStripGconv start ..."
  if [ -z "${sys_gconv}" ] || [ "${sys_gconv}" = "null" ] || [ "${sys_gconv}" = "NULL" ]; then
    directories="/usr/lib/gconv /usr/lib64/gconv"
    find ${directories} 2>/dev/null | xargs rm -f
    if [ $? -ne 0 ]; then
      echo "delete directories failed: ${directories}"
    fi
  elif [ "${sys_gconv}" != "all" ] && [ "${sys_gconv}" != "ALL" ]; then
    baseStripGconv "$(for i in $(echo ${sys_gconv} | tr "," " "); do echo -n "${i} "; done) gconv-modules gconv-modules.cache"
  fi
  echo "baseStripGconv end"

fi

echo "getSrcInfo start ..."
getSrcInfo
echo "getSrcInfo end"

cp -a /usr/custom/usrfile/* /
depmod -a $(uname -r)

if [ -f /etc/modules ] && [ -d /usr/Euler/conf ]; then
  cat /etc/modules >>/usr/Euler/conf/modules
fi

rm -rf /usr/custom
chmod +x /etc/rc.d/rc.local 2>/dev/null

if [ -f '/usr/Euler/conf/euler-release' ]; then
  [ -d /usr/lib/grub ] && ln -s /usr/lib/grub /usr/lib/grub2
fi

#================================================
# umount /proc
#================================================
echo "umount start ..."
umount /proc &>/dev/null
rm -rf /.profile /.kconfig /image /opt/need_rpmlst &>/dev/null
rm -rf ${EL_USRRPM_FILELIST} ${EL_UER_KOLST}
rm -rf /etc/euler-release
rm -rf ${workdir}
echo "umount end"

exit 0
