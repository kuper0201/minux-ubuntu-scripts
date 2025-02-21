#!/bin/bash

# 인터페이스 이름 자동 감지
IFACE=$(ip route | awk '/default/ {print $5}')

# 감지된 인터페이스가 없으면 종료
if [[ -z "$IFACE" ]]; then
    echo "No network interface found."
    exit 1
fi

# Netplan 설정 파일 생성
cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: true
EOF

# Netplan 적용
netplan apply
