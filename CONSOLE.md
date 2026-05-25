# 用 AWS Console 設定 EVS DNS

兩條路:
- **A. CloudShell 一鍵跑指令**(最快,~30 秒) — 看下面 §0
- **B. Route 53 UI 一筆一筆建** — §1 開始

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
export VPC_ID=vpc-xxxxxxxx
export AWS_REGION=$AWS_DEFAULT_REGION   # CloudShell 自帶,等於你 Console 當前 region

# 2) 抓腳本下來跑(repo 推上去之後才能這樣抓)
git clone https://github.com/kostenyang/awsevs.git
cd awsevs
./setup-evs-dns.sh
```

**或者完全不 clone,直接把整段 inline 在 CloudShell 跑**:

```bash
export VPC_ID=vpc-xxxxxxxx
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
