#!/usr/bin/env bash
# Quick sanity check for forward + reverse DNS of the EVS lab.
# Run from inside the EVS VPC (or any client whose resolver points at the
# Route 53 Resolver inbound endpoint for evs.vs.local).
set -u

HOSTS=(
  "tko-100005.evs.vs.local:100.66.0.5"
  "tko-100006.evs.vs.local:100.66.0.6"
  "tko-100007.evs.vs.local:100.66.0.7"
  "tko-100008.evs.vs.local:100.66.0.8"
  "tko-100085-vc.evs.vs.local:100.66.80.85"
  "tko-100086-nsxt.evs.vs.local:100.66.80.86"
  "tko-100087-sddcm.evs.vs.local:100.66.80.87"
  "tko-100088-cb.evs.vs.local:100.66.80.88"
  "tko-100089-edge.evs.vs.local:100.66.80.89"
  "tko-100090-edge.evs.vs.local:100.66.80.90"
  "tko-100091-nsx.evs.vs.local:100.66.80.91"
  "tko-100092-nsx.evs.vs.local:100.66.80.92"
  "tko-100093-nsx.evs.vs.local:100.66.80.93"
)

ok=0; bad=0
for kv in "${HOSTS[@]}"; do
  fqdn=${kv%%:*}; ip=${kv##*:}
  a=$(dig +short "$fqdn"           | head -1)
  p=$(dig +short -x "$ip"          | head -1)
  if [[ "$a" == "$ip" && "$p" == "${fqdn}." ]]; then
    printf 'OK   %-35s -> %-14s  /  PTR %s\n' "$fqdn" "$a" "$p"; ((ok++))
  else
    printf 'FAIL %-35s expected=%s got_A=%s got_PTR=%s\n' "$fqdn" "$ip" "${a:-<none>}" "${p:-<none>}"; ((bad++))
  fi
done

echo "---- $ok ok, $bad failed ----"
exit $(( bad == 0 ? 0 : 1 ))
