#!/usr/bin/env bash
# AWS CloudShell - Route 53 Resolver Inbound Endpoint + DHCP Option Set
# ----------------------------------------------------------------------
# 在 EVS VPC 內建一個 Resolver Inbound Endpoint(會給你 2 個 DNS IP),
# 再建一份 DHCP Option Set 用這 2 個 IP + domain `evs.local` + AWS Time Sync
# NTP `169.254.169.123`,最後 associate 到 EVS VPC。
#
# 跑之前要先建好 PHZ(看 setup-evs-dns.sh 或 CONSOLE.md §0/§0B)。
# ======================================================================

# §1 ── 環境變數(必跑)─────────────────────────────────────────────────
export VPC_ID=vpc-08464602dd04513f0       # EVS lab VPC
export AWS_REGION=ap-northeast-1          # EVS lab region (Tokyo)

# §2 ── 自動挑 2 個不同 AZ 的 subnet ────────────────────────────────────
read -r SUBNET_A SUBNET_B <<<"$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].[SubnetId,AvailabilityZone]' --output text | \
  awk '!seen[$2]++ {print $1}' | head -2 | tr '\n' ' ')"
echo "SUBNET_A=$SUBNET_A  SUBNET_B=$SUBNET_B"
[ -z "$SUBNET_B" ] && { echo "ERROR: 需要至少 2 個不同 AZ 的 subnet"; exit 1; }

# §3 ── 建 Security Group(允許 VPC 內 UDP/TCP 53 進來)─────────────────
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].CidrBlock' --output text)

SG_ID=$(aws ec2 create-security-group \
  --group-name evs-resolver-inbound \
  --description "Route53 Resolver inbound for EVS" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol udp --port 53 --cidr "$VPC_CIDR" >/dev/null
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 53 --cidr "$VPC_CIDR" >/dev/null
echo "SG_ID=$SG_ID  (open 53/udp + 53/tcp from $VPC_CIDR)"

# §4 ── 建 Resolver Inbound Endpoint ─────────────────────────────────────
ENDPOINT_ID=$(aws route53resolver create-resolver-endpoint \
  --creator-request-id "evs-inbound-$(date +%s)" \
  --name evs-inbound \
  --security-group-ids "$SG_ID" \
  --direction INBOUND \
  --ip-addresses SubnetId=$SUBNET_A SubnetId=$SUBNET_B \
  --query 'ResolverEndpoint.Id' --output text)
echo "ENDPOINT_ID=$ENDPOINT_ID  (creating, takes ~2-5 min)"

# 等到 OPERATIONAL
while :; do
  s=$(aws route53resolver get-resolver-endpoint --resolver-endpoint-id "$ENDPOINT_ID" \
        --query 'ResolverEndpoint.Status' --output text)
  echo "  status=$s"
  [ "$s" = "OPERATIONAL" ] && break
  sleep 15
done

# §5 ── 抓回 2 個 DNS IP ──────────────────────────────────────────────────
read -r DNS_IP1 DNS_IP2 <<<"$(aws route53resolver list-resolver-endpoint-ip-addresses \
  --resolver-endpoint-id "$ENDPOINT_ID" \
  --query 'IpAddresses[].Ip' --output text)"
echo "DNS_IP1=$DNS_IP1  DNS_IP2=$DNS_IP2"

# §6 ── 建 DHCP Option Set ───────────────────────────────────────────────
DOS_ID=$(aws ec2 create-dhcp-options \
  --dhcp-configurations \
    "Key=domain-name-servers,Values=$DNS_IP1,$DNS_IP2" \
    "Key=domain-name,Values=evs.local" \
    "Key=ntp-servers,Values=169.254.169.123" \
  --query 'DhcpOptions.DhcpOptionsId' --output text)

aws ec2 create-tags --resources "$DOS_ID" \
  --tags Key=Name,Value=evs-dhcp-options >/dev/null
echo "DOS_ID=$DOS_ID"

# §7 ── Associate 到 EVS VPC ─────────────────────────────────────────────
aws ec2 associate-dhcp-options --dhcp-options-id "$DOS_ID" --vpc-id "$VPC_ID"
echo "associated DHCP options $DOS_ID -> $VPC_ID"

cat <<EOF

================ Summary ================
Resolver Endpoint : $ENDPOINT_ID
DNS IPs           : $DNS_IP1, $DNS_IP2
DHCP Option Set   : $DOS_ID
  domain-name        = evs.local
  domain-name-servers= $DNS_IP1, $DNS_IP2
  ntp-servers        = 169.254.169.123
Attached to VPC   : $VPC_ID
==========================================

⚠️ 已開機的 EC2 / EVS appliance 不會立刻拿到新的 DHCP options。
   要 renew DHCP lease(Linux: dhclient -r && dhclient ; Windows: ipconfig /release /renew)
   或重開機才會生效。
EOF
