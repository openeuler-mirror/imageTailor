:<<!
 * Copyright (c) Huawei Technologies Co., Ltd. 2018-2024. All rights reserved.
 * oemaker licensed under the Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *     http://license.coscl.org.cn/MulanPSL2
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR
 * PURPOSE.
 * See the Mulan PSL v2 for more details.
 * Author:
 * Create: 2024-09-26
 * Description: provide img and qcow2 cleanup
!

#!/bin/bash

set -e

script_home=$(dirname $(readlink -f "$0"))
source "${script_home}"/../lib/utils

# Check if user is root
if [ $(id -u) -ne "0" ]; then
    echo " Not root user, please using sudo command!"
    exit 1
fi

# Recursively unmount directories [hmi_build|HMI]*
for dir in $(find /tmp/ -iname "HMI*"); do
    echo "Cleanning $dir ..."
    unmount_dir "${dir}"
    [ -n "${dir}" ] && rm -rf "${dir}"
done

# vim: set nu
