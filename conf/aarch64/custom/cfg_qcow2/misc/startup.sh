:<<!
 * Copyright (c) Huawei Technologies Co., Ltd. 2018-2023. All rights reserved.
 * oemaker licensed under the Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *     http://license.coscl.org.cn/MulanPSL2
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR
 * PURPOSE.
 * See the Mulan PSL v2 for more details.
 * Author:
 * Create: 2023-05-05
 * Description: provide qcow2 startup
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

if [ ! -f "$1" ]; then
    echo "File $1 don't exist."
    exit 1
fi

hmi_mount_dir=$(mktemp -t -d --tmpdir="${TMP_DIR:-/tmp}" HMI.XXXXXXXX)

echo "Chroot into $hmi_mount_dir ..."
mount -o offset=525336576 "$1" "${hmi_mount_dir}"
mount -o offset=1048576 "$1" "${hmi_mount_dir}"/boot

sync
mount -t proc none "${hmi_mount_dir}"/proc
mount --bind /dev "${MOUNT_WORKSPACE_DIR}"/dev
mount --bind /dev/pts "${MOUNT_WORKSPACE_DIR}"/dev/pts
mount -t sysfs none "${hmi_mount_dir}"/sys

chroot "${hmi_mount_dir}"

unmount_dir "${hmi_mount_dir}"
[ -n "${hmi_mount_dir}" ] && rm -rf "${hmi_mount_dir}"
echo "Leved from ${hmi_mount_dir}"

