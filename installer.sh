#!/bin/bash

# 설정
TARGET_DISK="/dev/sda"
TARGET_MOUNT="/mnt"
UBUNTU_VERSION="jammy"  # 22.04 LTS
MIRROR="http://archive.ubuntu.com/ubuntu"

echo "[1/6] 디스크 파티셔닝"
# 기존 데이터 삭제 (주의!)
sgdisk --zap-all ${TARGET_DISK}

# 파티션 생성
parted -s ${TARGET_DISK} mklabel gpt
parted -s ${TARGET_DISK} mkpart primary 1MiB 100%
mkfs.ext4 ${TARGET_DISK}1

# 마운트
mount ${TARGET_DISK}1 ${TARGET_MOUNT}

echo "[2/6] debootstrap을 이용한 기본 시스템 설치"
apt update
apt install -y debootstrap
debootstrap --arch=amd64 ${UBUNTU_VERSION} ${TARGET_MOUNT} ${MIRROR}

echo "[3/6] fstab 설정"
cat <<EOF > ${TARGET_MOUNT}/etc/fstab
UUID=$(blkid -s UUID -o value ${TARGET_DISK}1) / ext4 defaults 0 1
EOF

echo "[4/6] 부트로더 설치"
mount --bind /dev ${TARGET_MOUNT}/dev
mount --bind /proc ${TARGET_MOUNT}/proc
mount --bind /sys ${TARGET_MOUNT}/sys

chroot ${TARGET_MOUNT} bash -c "
apt update
apt install -y grub-pc linux-generic
grub-install ${TARGET_DISK}
update-grub
"

echo "[5/6] 사용자 설정"
chroot ${TARGET_MOUNT} bash -c "
echo 'ubuntu' > /etc/hostname
echo 'root:password' | chpasswd
"

echo "[6/6] 설치 완료 - 재부팅 준비"
umount -R ${TARGET_MOUNT}
echo "설치 완료! 재부팅하세요."
