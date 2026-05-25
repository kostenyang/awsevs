#!/usr/bin/env bash
# AWS CloudShell - Quick DHCP Option Set (Resolver IPs already known)
# -------------------------------------------------------------------
# 跳過 Resolver Endpoint 的建立(假設已經存在),只做:
#   1) create DHCP Option Set (domain-name-servers / domain-name / ntp-servers)
#   2) associate 到 EVS VPC
#
# 用法:
#   export VPC_ID=vpc-xxxxxxxx
#   ./cloudshell-dhcp-quick.sh
set -euo pipefail

: "${VPC_ID:?set VPC_ID (the EVS VPC id)}"

# === 已知值 — 你 lab 的 Route 53 Resolver Inbound Endpoint IP =========
DNS_IP1=100.66.146.33
DNS_IP2=100.66.175.116
DOMAIN_NAME=evs.local
NTP_IP=169.254.169.123
# =====================================================================

DOS_ID=$(aws ec2 create-dhcp-options \
  --dhcp-configurations \
    "Key=domain-name-servers,Values=$DNS_IP1,$DNS_IP2" \
    "Key=domain-name,Values=$DOMAIN_NAME" \
    "Key=ntp-servers,Values=$NTP_IP" \
  --query 'DhcpOptions.DhcpOptionsId' --output text)

aws ec2 create-tags --resources "$DOS_ID" \
  --tags Key=Name,Value=evs-dhcp-options >/dev/null

aws ec2 associate-dhcp-options --dhcp-options-id "$DOS_ID" --vpc-id "$VPC_ID"

cat <<EOF
DHCP Option Set : $DOS_ID
  domain-name        = $DOMAIN_NAME
  domain-name-servers= $DNS_IP1, $DNS_IP2
  ntp-servers        = $NTP_IP
Attached to VPC : $VPC_ID

驗證:
  aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].DhcpOptionsId' --output text
  aws ec2 describe-dhcp-options --dhcp-options-ids $DOS_ID --query 'DhcpOptions[0].DhcpConfigurations'

⚠️ 已開機的 instance 要 DHCP renew 或 reboot 才會套用。
EOF
