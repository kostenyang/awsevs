# AWS EVS DNS bootstrap

Forward + reverse DNS records for an AWS Elastic VMware Service (EVS) SDDC,
delivered as Route 53 **Private Hosted Zones** attached to the EVS VPC.

## Zones

| Purpose | Zone | Covers |
|---|---|---|
| Forward | `evs.vs.local` | all appliances |
| Reverse | `0.66.100.in-addr.arpa` | `100.66.0.0/24` (ESXi hosts) |
| Reverse | `80.66.100.in-addr.arpa` | `100.66.80.0/24` (mgmt plane) |

## Records

| FQDN | IP | Role |
|---|---|---|
| tko-100005.evs.vs.local | 100.66.0.5 | ESXi |
| tko-100006.evs.vs.local | 100.66.0.6 | ESXi |
| tko-100007.evs.vs.local | 100.66.0.7 | ESXi |
| tko-100008.evs.vs.local | 100.66.0.8 | ESXi |
| tko-100085-vc.evs.vs.local | 100.66.80.85 | vCenter |
| tko-100086-nsxt.evs.vs.local | 100.66.80.86 | NSX-T |
| tko-100087-sddcm.evs.vs.local | 100.66.80.87 | SDDC Manager |
| tko-100088-cb.evs.vs.local | 100.66.80.88 | Cloud Builder |
| tko-100089-edge.evs.vs.local | 100.66.80.89 | NSX Edge |
| tko-100090-edge.evs.vs.local | 100.66.80.90 | NSX Edge |
| tko-100091-nsx.evs.vs.local | 100.66.80.91 | NSX Manager |
| tko-100092-nsx.evs.vs.local | 100.66.80.92 | NSX Manager |
| tko-100093-nsx.evs.vs.local | 100.66.80.93 | NSX Manager |

## Apply

Pre-reqs: `awscli v2`, `jq`, AWS credentials with Route 53 + EC2 read perms,
and the EVS VPC id.

```bash
export AWS_REGION=ap-northeast-1    # your EVS region
export VPC_ID=vpc-0xxxxxxxxxxxxxxxx # the EVS VPC

./setup-evs-dns.sh --dry-run        # preview the JSON change-batch
./setup-evs-dns.sh                  # create PHZs + UPSERT all records
```

The script is idempotent: it re-uses an existing PHZ with the same name on
the same VPC, and all record changes use `UPSERT`, so re-running is safe.

## Verify

From any client whose resolver points at the EVS VPC (or via a Route 53
Resolver inbound endpoint):

```bash
./verify-evs-dns.sh
```

The script `dig`s every A and PTR record and prints a per-host pass/fail line.

## Alternative: /etc/hosts only

If you can't (or don't want to) wire up Route 53, [hosts.txt](hosts.txt) is a
drop-in `/etc/hosts` fragment:

```bash
sudo sh -c 'cat hosts.txt >> /etc/hosts'
```
