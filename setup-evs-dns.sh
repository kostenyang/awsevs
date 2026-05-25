#!/usr/bin/env bash
#
# AWS EVS (Elastic VMware Service) - Forward & Reverse DNS bootstrap
# -------------------------------------------------------------------
# Creates Route 53 Private Hosted Zones (PHZ) for the EVS lab domain
# and inserts A (forward) + PTR (reverse) records for every appliance.
#
# Forward zone : evs.vs.local
# Reverse zones: 0.66.100.in-addr.arpa   (covers 100.66.0.0/24)
#                80.66.100.in-addr.arpa  (covers 100.66.80.0/24)
#
# Usage:
#   export AWS_REGION=ap-northeast-1      # or your EVS region
#   export VPC_ID=vpc-xxxxxxxx            # EVS VPC ID
#   ./setup-evs-dns.sh                    # plan + apply
#   ./setup-evs-dns.sh --dry-run          # only print the change-batch JSON
#
# Requires: awscli v2, jq
set -euo pipefail

FORWARD_ZONE="evs.vs.local"
REVERSE_ZONES=("0.66.100.in-addr.arpa" "80.66.100.in-addr.arpa")
CALLER_REF="evs-dns-$(date +%s)"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

: "${AWS_REGION:?set AWS_REGION (e.g. ap-northeast-1)}"
: "${VPC_ID:?set VPC_ID (the EVS VPC id, e.g. vpc-0abc...)}"

command -v aws >/dev/null || { echo "awscli not found"; exit 1; }
command -v jq  >/dev/null || { echo "jq not found";    exit 1; }

# host -> ip mapping (single source of truth)
HOSTS=(
  "tko-100005:100.66.0.5"
  "tko-100006:100.66.0.6"
  "tko-100007:100.66.0.7"
  "tko-100008:100.66.0.8"
  "tko-100085-vc:100.66.80.85"
  "tko-100086-nsxt:100.66.80.86"
  "tko-100087-sddcm:100.66.80.87"
  "tko-100088-cb:100.66.80.88"
  "tko-100089-edge:100.66.80.89"
  "tko-100090-edge:100.66.80.90"
  "tko-100091-nsx:100.66.80.91"
  "tko-100092-nsx:100.66.80.92"
  "tko-100093-nsx:100.66.80.93"
)

# ---------- helpers ----------------------------------------------------------

# Find an existing Private Hosted Zone by name+VPC, else create one.
ensure_phz() {
  local zone_name=$1
  local zone_id
  zone_id=$(aws route53 list-hosted-zones-by-vpc \
              --vpc-id "$VPC_ID" --vpc-region "$AWS_REGION" \
              --query "HostedZoneSummaries[?Name=='${zone_name}.'].HostedZoneId | [0]" \
              --output text 2>/dev/null || true)

  if [[ -z "$zone_id" || "$zone_id" == "None" ]]; then
    echo ">> creating PHZ: $zone_name" >&2
    zone_id=$(aws route53 create-hosted-zone \
                --name "$zone_name" \
                --caller-reference "${CALLER_REF}-${zone_name}" \
                --hosted-zone-config Comment="EVS lab ${zone_name}",PrivateZone=true \
                --vpc VPCRegion="$AWS_REGION",VPCId="$VPC_ID" \
                --query 'HostedZone.Id' --output text)
    zone_id=${zone_id##*/}
  else
    echo ">> reusing PHZ: $zone_name ($zone_id)" >&2
  fi
  printf '%s' "$zone_id"
}

# Render a change-batch JSON for one zone from a list of "NAME TYPE VALUE" lines.
build_batch() {
  jq -n --arg comment "EVS DNS bootstrap $(date -u +%FT%TZ)" '
    { Comment: $comment, Changes: [ inputs |
        split(" ") as $f |
        { Action: "UPSERT",
          ResourceRecordSet: {
            Name: $f[0], Type: $f[1], TTL: 300,
            ResourceRecords: [ { Value: $f[2] } ]
          } } ] }'
}

apply_batch() {
  local zone_id=$1 batch_file=$2
  if (( DRY_RUN )); then
    echo "----- change-batch for $zone_id -----"
    cat "$batch_file"
    return
  fi
  aws route53 change-resource-record-sets \
    --hosted-zone-id "$zone_id" \
    --change-batch "file://$batch_file" \
    --query 'ChangeInfo.[Id,Status]' --output text
}

# ---------- forward zone -----------------------------------------------------

FWD_ID=$(ensure_phz "$FORWARD_ZONE")
FWD_TMP=$(mktemp)
{
  for kv in "${HOSTS[@]}"; do
    name=${kv%%:*}; ip=${kv##*:}
    echo "${name}.${FORWARD_ZONE}. A ${ip}"
  done
} | build_batch > "$FWD_TMP"
apply_batch "$FWD_ID" "$FWD_TMP"

# ---------- reverse zones ----------------------------------------------------

for rz in "${REVERSE_ZONES[@]}"; do
  RV_ID=$(ensure_phz "$rz")
  RV_TMP=$(mktemp)

  # Pick which /24 this reverse zone covers from its name.
  # e.g. "0.66.100.in-addr.arpa" => prefix "100.66.0."
  octets=${rz%.in-addr.arpa}
  IFS='.' read -r o3 o2 o1 <<<"$octets"
  net_prefix="${o1}.${o2}.${o3}."

  {
    for kv in "${HOSTS[@]}"; do
      name=${kv%%:*}; ip=${kv##*:}
      [[ "$ip" == ${net_prefix}* ]] || continue
      host_octet=${ip##*.}
      echo "${host_octet}.${rz}. PTR ${name}.${FORWARD_ZONE}."
    done
  } | build_batch > "$RV_TMP"

  apply_batch "$RV_ID" "$RV_TMP"
done

echo "Done."
