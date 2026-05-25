#!/usr/bin/env bash
# AWS CloudShell - 每筆 record 一條指令版本
# ----------------------------------------------------------------------
# 用法:
#   1. AWS Console 右上角切到 EVS 所在 region
#   2. 點 `>_` 圖示開 CloudShell
#   3. 先設好 VPC_ID,再從 §1 開始一段一段貼(或整份貼)
#
# 每條 aws 指令都是獨立的 — 你可以只跑想跑的那一筆,也可以全部跑完。
# 全部都用 UPSERT,重複跑不會出錯,值會被覆蓋成最新。
# ======================================================================

# §0 ── 設定環境變數(必跑)────────────────────────────────────────────
export VPC_ID=vpc-08464602dd04513f0        # EVS lab VPC
export AWS_REGION=$AWS_DEFAULT_REGION      # CloudShell 自帶


# §1 ── 建 3 個 Private Hosted Zone(必跑,只要跑一次)──────────────────

# Forward zone
FWD_ID=$(aws route53 create-hosted-zone \
  --name evs.vs.local \
  --caller-reference "evs-fwd-$(date +%s)" \
  --hosted-zone-config Comment="EVS forward",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text); FWD_ID=${FWD_ID##*/}
echo "FWD_ID=$FWD_ID"

# Reverse zone for 100.66.0.0/24
RV1_ID=$(aws route53 create-hosted-zone \
  --name 0.66.100.in-addr.arpa \
  --caller-reference "evs-rv1-$(date +%s)" \
  --hosted-zone-config Comment="EVS reverse 100.66.0/24",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text); RV1_ID=${RV1_ID##*/}
echo "RV1_ID=$RV1_ID"

# Reverse zone for 100.66.80.0/24
RV2_ID=$(aws route53 create-hosted-zone \
  --name 80.66.100.in-addr.arpa \
  --caller-reference "evs-rv2-$(date +%s)" \
  --hosted-zone-config Comment="EVS reverse 100.66.80/24",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text); RV2_ID=${RV2_ID##*/}
echo "RV2_ID=$RV2_ID"

# ⚠️ 已經建過了想重跑下面 §2/§3?從 Console 抓回 ID:
#   FWD_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='evs.vs.local.'].Id|[0]" --output text); FWD_ID=${FWD_ID##*/}
#   RV1_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='0.66.100.in-addr.arpa.'].Id|[0]" --output text); RV1_ID=${RV1_ID##*/}
#   RV2_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='80.66.100.in-addr.arpa.'].Id|[0]" --output text); RV2_ID=${RV2_ID##*/}


# §2 ── Forward A records(13 筆,每筆一條獨立指令)─────────────────────

# tko-100005  →  100.66.0.5
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100005.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.5"}]}}]}'

# tko-100006  →  100.66.0.6
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100006.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.6"}]}}]}'

# tko-100007  →  100.66.0.7
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100007.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.7"}]}}]}'

# tko-100008  →  100.66.0.8
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100008.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.8"}]}}]}'

# tko-100085-vc  →  100.66.80.85   (vCenter)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100085-vc.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.85"}]}}]}'

# tko-100086-nsxt  →  100.66.80.86   (NSX-T)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100086-nsxt.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.86"}]}}]}'

# tko-100087-sddcm  →  100.66.80.87   (SDDC Manager)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100087-sddcm.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.87"}]}}]}'

# tko-100088-cb  →  100.66.80.88   (Cloud Builder)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100088-cb.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.88"}]}}]}'

# tko-100089-edge  →  100.66.80.89   (NSX Edge)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100089-edge.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.89"}]}}]}'

# tko-100090-edge  →  100.66.80.90   (NSX Edge)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100090-edge.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.90"}]}}]}'

# tko-100091-nsx  →  100.66.80.91   (NSX Manager)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100091-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.91"}]}}]}'

# tko-100092-nsx  →  100.66.80.92   (NSX Manager)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100092-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.92"}]}}]}'

# tko-100093-nsx  →  100.66.80.93   (NSX Manager)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100093-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.93"}]}}]}'


# §3 ── Reverse PTR records ─────────────────────────────────────────────

# --- 100.66.0.0/24 → RV1_ID ---

# 100.66.0.5  →  tko-100005.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"5.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100005.evs.vs.local."}]}}]}'

# 100.66.0.6  →  tko-100006.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"6.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100006.evs.vs.local."}]}}]}'

# 100.66.0.7  →  tko-100007.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"7.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100007.evs.vs.local."}]}}]}'

# 100.66.0.8  →  tko-100008.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"8.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100008.evs.vs.local."}]}}]}'

# --- 100.66.80.0/24 → RV2_ID ---

# 100.66.80.85  →  tko-100085-vc.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"85.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100085-vc.evs.vs.local."}]}}]}'

# 100.66.80.86  →  tko-100086-nsxt.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"86.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100086-nsxt.evs.vs.local."}]}}]}'

# 100.66.80.87  →  tko-100087-sddcm.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"87.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100087-sddcm.evs.vs.local."}]}}]}'

# 100.66.80.88  →  tko-100088-cb.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"88.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100088-cb.evs.vs.local."}]}}]}'

# 100.66.80.89  →  tko-100089-edge.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"89.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100089-edge.evs.vs.local."}]}}]}'

# 100.66.80.90  →  tko-100090-edge.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"90.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100090-edge.evs.vs.local."}]}}]}'

# 100.66.80.91  →  tko-100091-nsx.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"91.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100091-nsx.evs.vs.local."}]}}]}'

# 100.66.80.92  →  tko-100092-nsx.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"92.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100092-nsx.evs.vs.local."}]}}]}'

# 100.66.80.93  →  tko-100093-nsx.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"93.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100093-nsx.evs.vs.local."}]}}]}'


# §4 ── 驗證(在 EVS VPC 內任何 Linux/Windows 跑)─────────────────────────
# dig +short tko-100085-vc.evs.vs.local       # 預期 100.66.80.85
# dig +short -x 100.66.80.85                  # 預期 tko-100085-vc.evs.vs.local.
