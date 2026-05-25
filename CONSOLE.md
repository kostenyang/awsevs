# 用 AWS Console 設定 EVS DNS

四條路:
- **A. CloudShell 一鍵跑指令**(最快,~30 秒) — §0
- **B. CloudShell 每筆 record 獨立指令**(可以只跑單筆) — §0B
- **C. CloudShell 建 Resolver Inbound Endpoint + DHCP Option Set** — §0C
- **D. Route 53 UI 一筆一筆建** — §1 開始

> 前置(兩條路都要):記下 EVS 用的 **VPC ID** 和 **Region**。
> 在 VPC console (`https://console.aws.amazon.com/vpc/`) → Your VPCs 找到 EVS 那一個,把 `vpc-xxxxxxxx` 抄起來。

---

## §0 — AWS CloudShell 一鍵跑

**CloudShell** 就是 Console 右上角那個 `>_` 圖示(在 region 選單左邊那一排小 icon 裡)。
點開會跳出一個瀏覽器內的 terminal,已經登入你的 AWS 身份,`aws` / `jq` / `git` 都裝好了。

> ⚠️ CloudShell 是 **per-region** 的。先在 Console 右上角把 region 切到 EVS 所在的 region,再打開 CloudShell,跑出來的指令才會打到對的 region。

打開 CloudShell 後,把這整段貼進去執行:

```bash
# 1) 設好 EVS VPC ID(改成你自己的)
export VPC_ID=vpc-08464602dd04513f0
export AWS_REGION=$AWS_DEFAULT_REGION   # CloudShell 自帶,等於你 Console 當前 region

# 2) 抓腳本下來跑(repo 推上去之後才能這樣抓)
git clone https://github.com/kostenyang/awsevs.git
cd awsevs
./setup-evs-dns.sh
```

**或者完全不 clone,直接把整段 inline 在 CloudShell 跑**:

```bash
export VPC_ID=vpc-08464602dd04513f0
export AWS_REGION=$AWS_DEFAULT_REGION

# 建 forward zone
FWD_ID=$(aws route53 create-hosted-zone \
  --name evs.vs.local \
  --caller-reference "evs-fwd-$(date +%s)" \
  --hosted-zone-config Comment="EVS forward",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text)
FWD_ID=${FWD_ID##*/}

# 建兩個 reverse zone
RV1_ID=$(aws route53 create-hosted-zone \
  --name 0.66.100.in-addr.arpa \
  --caller-reference "evs-rv1-$(date +%s)" \
  --hosted-zone-config Comment="EVS reverse 100.66.0/24",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text); RV1_ID=${RV1_ID##*/}

RV2_ID=$(aws route53 create-hosted-zone \
  --name 80.66.100.in-addr.arpa \
  --caller-reference "evs-rv2-$(date +%s)" \
  --hosted-zone-config Comment="EVS reverse 100.66.80/24",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text); RV2_ID=${RV2_ID##*/}

# 寫 A records
cat > /tmp/fwd.json <<'EOF'
{ "Changes": [
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100005.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.5"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100006.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.6"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100007.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.7"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100008.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.8"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100085-vc.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.85"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100086-nsxt.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.86"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100087-sddcm.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.87"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100088-cb.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.88"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100089-edge.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.89"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100090-edge.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.90"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100091-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.91"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100092-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.92"}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100093-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.93"}]}}
]}
EOF
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch file:///tmp/fwd.json

# PTR for 100.66.0.0/24
cat > /tmp/rv1.json <<'EOF'
{ "Changes": [
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"5.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100005.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"6.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100006.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"7.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100007.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"8.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100008.evs.vs.local."}]}}
]}
EOF
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch file:///tmp/rv1.json

# PTR for 100.66.80.0/24
cat > /tmp/rv2.json <<'EOF'
{ "Changes": [
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"85.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100085-vc.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"86.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100086-nsxt.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"87.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100087-sddcm.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"88.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100088-cb.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"89.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100089-edge.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"90.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100090-edge.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"91.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100091-nsx.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"92.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100092-nsx.evs.vs.local."}]}},
  {"Action":"UPSERT","ResourceRecordSet":{"Name":"93.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100093-nsx.evs.vs.local."}]}}
]}
EOF
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch file:///tmp/rv2.json

echo "Done. FWD=$FWD_ID  RV1=$RV1_ID  RV2=$RV2_ID"
```

跑完到 Route 53 → Hosted zones 應該看到 3 個新的 PHZ,每個都有對應筆數的記錄。

> CloudShell 環境每個 region 有 1GB 持久空間,但暫存檔放 `/tmp` 重開就沒了,沒關係,記錄已經寫進 Route 53。

---

## §0B — CloudShell 每筆 record 獨立指令

跟 §0 一樣是貼進 CloudShell,差別是 **每筆 DNS record 都是獨立一行 `aws` 指令**。
適合想單獨重跑某一筆(例如某台 IP 改了)或想看清楚每筆在做什麼的情境。

> 完整檔案在 repo 的 [`cloudshell-per-record.sh`](cloudshell-per-record.sh),CloudShell 裡也可以直接:
> ```bash
> git clone https://github.com/kostenyang/awsevs.git && cd awsevs && less cloudshell-per-record.sh
> ```

### Step A — 設環境變數(必跑)

```bash
export VPC_ID=vpc-08464602dd04513f0              # EVS lab VPC
export AWS_REGION=$AWS_DEFAULT_REGION   # CloudShell 自帶,等於當前 region
```

### Step B — 建 3 個 Private Hosted Zone(必跑,只跑一次)

```bash
# Forward zone: evs.vs.local
FWD_ID=$(aws route53 create-hosted-zone \
  --name evs.vs.local \
  --caller-reference "evs-fwd-$(date +%s)" \
  --hosted-zone-config Comment="EVS forward",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text); FWD_ID=${FWD_ID##*/}
echo "FWD_ID=$FWD_ID"
```

```bash
# Reverse zone: 100.66.0.0/24
RV1_ID=$(aws route53 create-hosted-zone \
  --name 0.66.100.in-addr.arpa \
  --caller-reference "evs-rv1-$(date +%s)" \
  --hosted-zone-config Comment="EVS reverse 100.66.0/24",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text); RV1_ID=${RV1_ID##*/}
echo "RV1_ID=$RV1_ID"
```

```bash
# Reverse zone: 100.66.80.0/24
RV2_ID=$(aws route53 create-hosted-zone \
  --name 80.66.100.in-addr.arpa \
  --caller-reference "evs-rv2-$(date +%s)" \
  --hosted-zone-config Comment="EVS reverse 100.66.80/24",PrivateZone=true \
  --vpc VPCRegion=$AWS_REGION,VPCId=$VPC_ID \
  --query 'HostedZone.Id' --output text); RV2_ID=${RV2_ID##*/}
echo "RV2_ID=$RV2_ID"
```

> 已經建過 zone、CloudShell session 斷了想重跑後面 record 指令?從 Console 抓回 ID:
> ```bash
> FWD_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='evs.vs.local.'].Id|[0]" --output text); FWD_ID=${FWD_ID##*/}
> RV1_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='0.66.100.in-addr.arpa.'].Id|[0]" --output text); RV1_ID=${RV1_ID##*/}
> RV2_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='80.66.100.in-addr.arpa.'].Id|[0]" --output text); RV2_ID=${RV2_ID##*/}
> ```

### Step C — Forward A records(13 筆,每筆一條獨立指令)

```bash
# tko-100005  →  100.66.0.5
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100005.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.5"}]}}]}'
```

```bash
# tko-100006  →  100.66.0.6
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100006.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.6"}]}}]}'
```

```bash
# tko-100007  →  100.66.0.7
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100007.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.7"}]}}]}'
```

```bash
# tko-100008  →  100.66.0.8
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100008.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.0.8"}]}}]}'
```

```bash
# tko-100085-vc  →  100.66.80.85   (vCenter)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100085-vc.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.85"}]}}]}'
```

```bash
# tko-100086-nsxt  →  100.66.80.86   (NSX-T)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100086-nsxt.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.86"}]}}]}'
```

```bash
# tko-100087-sddcm  →  100.66.80.87   (SDDC Manager)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100087-sddcm.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.87"}]}}]}'
```

```bash
# tko-100088-cb  →  100.66.80.88   (Cloud Builder)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100088-cb.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.88"}]}}]}'
```

```bash
# tko-100089-edge  →  100.66.80.89   (NSX Edge)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100089-edge.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.89"}]}}]}'
```

```bash
# tko-100090-edge  →  100.66.80.90   (NSX Edge)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100090-edge.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.90"}]}}]}'
```

```bash
# tko-100091-nsx  →  100.66.80.91   (NSX Manager)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100091-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.91"}]}}]}'
```

```bash
# tko-100092-nsx  →  100.66.80.92   (NSX Manager)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100092-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.92"}]}}]}'
```

```bash
# tko-100093-nsx  →  100.66.80.93   (NSX Manager)
aws route53 change-resource-record-sets --hosted-zone-id "$FWD_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"tko-100093-nsx.evs.vs.local.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.66.80.93"}]}}]}'
```

### Step D — Reverse PTR records (100.66.0.0/24)

```bash
# 100.66.0.5  →  tko-100005.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"5.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100005.evs.vs.local."}]}}]}'
```

```bash
# 100.66.0.6  →  tko-100006.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"6.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100006.evs.vs.local."}]}}]}'
```

```bash
# 100.66.0.7  →  tko-100007.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"7.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100007.evs.vs.local."}]}}]}'
```

```bash
# 100.66.0.8  →  tko-100008.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV1_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"8.0.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100008.evs.vs.local."}]}}]}'
```

### Step E — Reverse PTR records (100.66.80.0/24)

```bash
# 100.66.80.85  →  tko-100085-vc.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"85.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100085-vc.evs.vs.local."}]}}]}'
```

```bash
# 100.66.80.86  →  tko-100086-nsxt.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"86.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100086-nsxt.evs.vs.local."}]}}]}'
```

```bash
# 100.66.80.87  →  tko-100087-sddcm.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"87.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100087-sddcm.evs.vs.local."}]}}]}'
```

```bash
# 100.66.80.88  →  tko-100088-cb.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"88.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100088-cb.evs.vs.local."}]}}]}'
```

```bash
# 100.66.80.89  →  tko-100089-edge.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"89.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100089-edge.evs.vs.local."}]}}]}'
```

```bash
# 100.66.80.90  →  tko-100090-edge.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"90.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100090-edge.evs.vs.local."}]}}]}'
```

```bash
# 100.66.80.91  →  tko-100091-nsx.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"91.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100091-nsx.evs.vs.local."}]}}]}'
```

```bash
# 100.66.80.92  →  tko-100092-nsx.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"92.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100092-nsx.evs.vs.local."}]}}]}'
```

```bash
# 100.66.80.93  →  tko-100093-nsx.evs.vs.local
aws route53 change-resource-record-sets --hosted-zone-id "$RV2_ID" --change-batch \
'{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"93.80.66.100.in-addr.arpa.","Type":"PTR","TTL":300,"ResourceRecords":[{"Value":"tko-100093-nsx.evs.vs.local."}]}}]}'
```

### Step F — 驗證(從 EVS VPC 內任何一台 host 跑)

```bash
dig +short tko-100085-vc.evs.vs.local       # 預期: 100.66.80.85
dig +short -x 100.66.80.85                  # 預期: tko-100085-vc.evs.vs.local.
```

---

## §0C — CloudShell 建 Resolver Inbound Endpoint + DHCP Option Set

PHZ 預設只給 **附加到 PHZ 的 VPC 自己的 resolver** 用。EVS appliance(vCenter / NSX
/ SDDC Manager…)在開機時要透過 DHCP 拿到 DNS server,還要走 link-local NTP,所以
需要:

1. **Route 53 Resolver Inbound Endpoint** — 給 EVS appliance 一組可路由的 DNS IP
2. **DHCP Option Set** — 把 DNS IP + domain + NTP 塞給 DHCP client
3. 把這個 Option Set **associate 到 EVS VPC**

目標設定:

| 欄位 | 值 |
|---|---|
| Domain name servers | Resolver Inbound Endpoint 給的 2 個 IP |
| Domain name | `evs.local` |
| NTP servers | `169.254.169.123` (AWS Time Sync, link-local) |

完整檔案在 [`cloudshell-resolver-dhcp.sh`](cloudshell-resolver-dhcp.sh)。下面是 CloudShell 裡每段獨立貼的版本。

### Step A — 設環境變數(必跑)

```bash
export VPC_ID=vpc-08464602dd04513f0
export AWS_REGION=$AWS_DEFAULT_REGION
```

### Step B — 自動挑 2 個不同 AZ 的 subnet(Resolver Endpoint 需要)

```bash
read -r SUBNET_A SUBNET_B <<<"$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].[SubnetId,AvailabilityZone]' --output text | \
  awk '!seen[$2]++ {print $1}' | head -2 | tr '\n' ' ')"
echo "SUBNET_A=$SUBNET_A  SUBNET_B=$SUBNET_B"
```

> 不滿意自動挑的?手動指定: `SUBNET_A=subnet-xxxx; SUBNET_B=subnet-yyyy`(必須在不同 AZ)。

### Step C — 建 Security Group(只放行 VPC 內 53 進來)

```bash
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].CidrBlock' --output text)

SG_ID=$(aws ec2 create-security-group \
  --group-name evs-resolver-inbound \
  --description "Route53 Resolver inbound for EVS" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol udp --port 53 --cidr "$VPC_CIDR"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 53 --cidr "$VPC_CIDR"
echo "SG_ID=$SG_ID"
```

### Step D — 建 Resolver Inbound Endpoint

```bash
ENDPOINT_ID=$(aws route53resolver create-resolver-endpoint \
  --creator-request-id "evs-inbound-$(date +%s)" \
  --name evs-inbound \
  --security-group-ids "$SG_ID" \
  --direction INBOUND \
  --ip-addresses SubnetId=$SUBNET_A SubnetId=$SUBNET_B \
  --query 'ResolverEndpoint.Id' --output text)
echo "ENDPOINT_ID=$ENDPOINT_ID  (約 2-5 分鐘變 OPERATIONAL)"
```

等到 OPERATIONAL(會自己 loop 到好):

```bash
while :; do
  s=$(aws route53resolver get-resolver-endpoint --resolver-endpoint-id "$ENDPOINT_ID" \
        --query 'ResolverEndpoint.Status' --output text)
  echo "  status=$s"
  [ "$s" = "OPERATIONAL" ] && break
  sleep 15
done
```

### Step E — 抓回 2 個 DNS IP(後面 DHCP Option Set 要用)

```bash
read -r DNS_IP1 DNS_IP2 <<<"$(aws route53resolver list-resolver-endpoint-ip-addresses \
  --resolver-endpoint-id "$ENDPOINT_ID" \
  --query 'IpAddresses[].Ip' --output text)"
echo "DNS_IP1=$DNS_IP1  DNS_IP2=$DNS_IP2"
```

### Step F — 建 DHCP Option Set

```bash
DOS_ID=$(aws ec2 create-dhcp-options \
  --dhcp-configurations \
    "Key=domain-name-servers,Values=$DNS_IP1,$DNS_IP2" \
    "Key=domain-name,Values=evs.local" \
    "Key=ntp-servers,Values=169.254.169.123" \
  --query 'DhcpOptions.DhcpOptionsId' --output text)

aws ec2 create-tags --resources "$DOS_ID" \
  --tags Key=Name,Value=evs-dhcp-options
echo "DOS_ID=$DOS_ID"
```

### Step F-alt — 已經有 Resolver IP?一條一條貼的版本

CloudShell 開好後,**一個 code block = 一條指令**,依序貼:

> 本 lab 已知值:
> - VPC ID: `vpc-08464602dd04513f0`
> - Resolver Inbound IP: `100.66.146.33` / `100.66.175.116`
> - domain: `evs.local`,NTP: `169.254.169.123`
>
> 下面所有值都已經寫死,**完全照貼即可**。

#### 1. 設 EVS VPC ID

```bash
export VPC_ID=vpc-08464602dd04513f0
```

#### 2. 建 DHCP Option Set(把 4 個值塞進去)

```bash
aws ec2 create-dhcp-options \
  --dhcp-configurations \
    "Key=domain-name-servers,Values=100.66.146.33,100.66.175.116" \
    "Key=domain-name,Values=evs.local" \
    "Key=ntp-servers,Values=169.254.169.123"
```

> 跑完會回一段 JSON,把裡面 `"DhcpOptionsId": "dopt-xxxxxxxx"` 那個值記下來,下面要用。

#### 3. 把 DhcpOptionsId 設成變數(換成上一步拿到的 dopt-xxxxxxxx)

```bash
export DOS_ID=dopt-xxxxxxxx
```

#### 4. (選用)幫它打個 Name tag

```bash
aws ec2 create-tags --resources "$DOS_ID" --tags Key=Name,Value=evs-dhcp-options
```

#### 5. 把 Option Set 綁到 EVS VPC

```bash
aws ec2 associate-dhcp-options --dhcp-options-id "$DOS_ID" --vpc-id "$VPC_ID"
```

#### 6. 確認 VPC 已經改用這份 Option Set

```bash
aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].DhcpOptionsId' --output text
```

> 預期輸出 = 你剛剛 `DOS_ID` 那個 `dopt-xxxxxxxx`。

#### 7. 確認 Option Set 內容是對的

```bash
aws ec2 describe-dhcp-options --dhcp-options-ids "$DOS_ID" --query 'DhcpOptions[0].DhcpConfigurations'
```

> 預期看到 4 個 entry: `domain-name-servers` = `100.66.146.33, 100.66.175.116`、`domain-name` = `evs.local`、`ntp-servers` = `169.254.169.123`。

### Step G — Associate 到 EVS VPC

```bash
aws ec2 associate-dhcp-options --dhcp-options-id "$DOS_ID" --vpc-id "$VPC_ID"
```

### Step H — 確認

```bash
aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
  --query 'Vpcs[0].DhcpOptionsId' --output text   # 應該等於上面的 DOS_ID

aws ec2 describe-dhcp-options --dhcp-options-ids "$DOS_ID" \
  --query 'DhcpOptions[0].DhcpConfigurations'
```

> ⚠️ **已開機的 EC2 / EVS appliance 不會自動套用新 DHCP options**。
> 要 renew DHCP lease(Linux: `sudo dhclient -r && sudo dhclient`、Windows: `ipconfig /release && ipconfig /renew`)或直接重開機才會生效。
> 全新部署的 EVS 在 provisioning 階段拿,所以走 DHCP option set 沒問題。

---

## §1 — Route 53 UI 一筆一筆建

### Step 1 — 建立 Forward Zone `evs.vs.local`

1. 進入 **Route 53** → 左邊 **Hosted zones** → 右上 **Create hosted zone**
2. 填:
   - **Domain name**: `evs.vs.local`
   - **Type**: **Private hosted zone** ← 一定要選這個
   - **VPCs to associate**:
     - Region: 你的 EVS Region (e.g. `ap-northeast-1`)
     - VPC ID: 選 EVS 的 VPC
   - Comment: `EVS lab forward zone`
3. **Create hosted zone**

進到這個 zone 後,**Create record** × 13 次(或用下面的 batch 方法):

| Record name | Type | Value (IP) |
|---|---|---|
| `tko-100005` | A | `100.66.0.5` |
| `tko-100006` | A | `100.66.0.6` |
| `tko-100007` | A | `100.66.0.7` |
| `tko-100008` | A | `100.66.0.8` |
| `tko-100085-vc` | A | `100.66.80.85` |
| `tko-100086-nsxt` | A | `100.66.80.86` |
| `tko-100087-sddcm` | A | `100.66.80.87` |
| `tko-100088-cb` | A | `100.66.80.88` |
| `tko-100089-edge` | A | `100.66.80.89` |
| `tko-100090-edge` | A | `100.66.80.90` |
| `tko-100091-nsx` | A | `100.66.80.91` |
| `tko-100092-nsx` | A | `100.66.80.92` |
| `tko-100093-nsx` | A | `100.66.80.93` |

每筆設定:
- **Record name**: 表格的 name(只填左邊,Console 會自動接 `.evs.vs.local`)
- **Record type**: `A`
- **Value**: 對應 IP
- **TTL**: 300 (秒)
- **Routing policy**: Simple routing
- **Create records**

> 想一次塞 13 筆? Console 右上有個 **Quick create record** 模式,可以在同一頁連按 **Add another record** 加滿再一次 Create。

---

### Step 2 — 建立 Reverse Zone 1 `0.66.100.in-addr.arpa` (給 100.66.0.x)

1. **Hosted zones** → **Create hosted zone**
2. 填:
   - **Domain name**: `0.66.100.in-addr.arpa`
   - **Type**: **Private hosted zone**
   - **VPCs to associate**: 同一個 EVS VPC
3. **Create**

進入後加 PTR:

| Record name | Type | Value (FQDN, **結尾要點**) |
|---|---|---|
| `5`  | PTR | `tko-100005.evs.vs.local.` |
| `6`  | PTR | `tko-100006.evs.vs.local.` |
| `7`  | PTR | `tko-100007.evs.vs.local.` |
| `8`  | PTR | `tko-100008.evs.vs.local.` |

> Record name 只填最後一段 octet,Console 自動接 `.0.66.100.in-addr.arpa`
> Value 結尾的 `.` 不要漏,否則會被當成相對名稱

---

### Step 3 — 建立 Reverse Zone 2 `80.66.100.in-addr.arpa` (給 100.66.80.x)

同樣步驟,zone name 改成 `80.66.100.in-addr.arpa`。

PTR 記錄:

| Record name | Type | Value |
|---|---|---|
| `85` | PTR | `tko-100085-vc.evs.vs.local.` |
| `86` | PTR | `tko-100086-nsxt.evs.vs.local.` |
| `87` | PTR | `tko-100087-sddcm.evs.vs.local.` |
| `88` | PTR | `tko-100088-cb.evs.vs.local.` |
| `89` | PTR | `tko-100089-edge.evs.vs.local.` |
| `90` | PTR | `tko-100090-edge.evs.vs.local.` |
| `91` | PTR | `tko-100091-nsx.evs.vs.local.` |
| `92` | PTR | `tko-100092-nsx.evs.vs.local.` |
| `93` | PTR | `tko-100093-nsx.evs.vs.local.` |

---

### Step 4 — 確認 VPC DNS 設定有開

在 VPC console → 你的 EVS VPC → **Actions** → **Edit VPC settings**:
- ✅ **Enable DNS resolution**
- ✅ **Enable DNS hostnames**

兩個都要開,Private Hosted Zone 才會被 VPC 內的 resolver 看到。

---

### Step 5 — 從 VPC 內驗證

SSH 到 EVS VPC 內任何一台 Linux box(或 jump host),跑:

```bash
# 正解
dig +short tko-100085-vc.evs.vs.local
# 期望: 100.66.80.85

# 反解
dig +short -x 100.66.80.85
# 期望: tko-100085-vc.evs.vs.local.

# 一次驗全部
for h in tko-100005 tko-100006 tko-100007 tko-100008 \
         tko-100085-vc tko-100086-nsxt tko-100087-sddcm tko-100088-cb \
         tko-100089-edge tko-100090-edge \
         tko-100091-nsx tko-100092-nsx tko-100093-nsx; do
  printf '%-30s -> %s\n' "$h" "$(dig +short $h.evs.vs.local)"
done
```

---

### Step 6 (選用) — 給 on-prem / 其他 VPC 也能解到

PHZ 只有 associated VPC 內的 resolver 看得到。要讓 VMware Cloud Foundation
管理介面 / on-prem / peer VPC 也能解,要建 **Route 53 Resolver Inbound
Endpoint**:

1. **Route 53** → **Resolver** → **Inbound endpoints** → **Create**
2. VPC = EVS VPC,選 2 個不同 AZ 的 subnet
3. Security group 開 **UDP/TCP 53** from 你想讓它查的來源 CIDR
4. Endpoint 會給你 2 個 IP — 把這 2 個 IP 設成 on-prem DNS 的 conditional
   forwarder for `evs.vs.local` / `0.66.100.in-addr.arpa` / `80.66.100.in-addr.arpa`

---

### 常見坑

| 症狀 | 原因 |
|---|---|
| 從 VPC 內 dig 不到 | Step 4 沒打開 `enableDnsSupport` / `enableDnsHostnames` |
| Reverse 解不到 | PTR value 結尾少了 `.`,變成 `tko-xxx.evs.vs.local.0.66.100.in-addr.arpa.` |
| Hosted zone 建錯成 public | Type 沒勾 Private,public PHZ 不會回給 VPC resolver |
| 不同 region | PHZ 沒 region 限制,但 VPC association 要寫對 region |
