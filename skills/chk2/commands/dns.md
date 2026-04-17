---
name: chk2:dns
description: "Test DNS, DNSSEC, SPF, DMARC configuration"
allowed-tools: Read, Bash(dig *), Bash(curl *), Bash(host *), Bash(nmap *), Bash(echo *), Write
---

# chk2:dns — DNS and Email Security

Test DNS configuration for myzr.io. Write results to `SECURITY_CHECK.parts/dns.md` (see **Output** for format).

## Tests

```bash
dig myzr.io A +short
dig myzr.io AAAA +short
dig myzr.io NS +short
dig myzr.io MX +short
dig myzr.io TXT +short
dig _dmarc.myzr.io TXT +short
dig myzr.io DNSKEY +short
dig myzr.io DS +short
dig myzr.io CAA +short
```

## Checks

| # | Test | Pass Condition |
|---|------|---------------|
| D1 | NS is Cloudflare | NS records contain `cloudflare.com` |
| D2 | DNSSEC DNSKEY | DNSKEY record present |
| D3 | DNSSEC DS | DS record present |
| D4 | SPF record | TXT record contains `v=spf1` |
| D5 | SPF reject-all | SPF ends with `-all` (hard fail) not `~all` (soft) |
| D6 | DMARC present | `_dmarc` TXT record exists |
| D7 | DMARC policy reject | DMARC contains `p=reject` (not `quarantine` or `none`) |
| D8 | DMARC strict alignment | `adkim=s` and `aspf=s` present |
| D9 | No unexpected MX | No MX records (domain doesn't receive email) or MX is expected |
| D10 | CAA record | CAA record present restricting CA issuance (WARN if absent) |
| D11 | Subdomain takeover risk | CNAME records for common subdomains (www, api, mail, staging, dev, cdn) resolve to active services |
| D12 | DNS rebinding resistance | TTL on A records is >= 60 seconds (WARN if < 30s) |
| D13 | MTA-STS policy | `_mta-sts.myzr.io` TXT record present (WARN if absent) |
| DA1 | DoH resolver exposure | No internal DNS resolver exposed at /dns-query or common DoH paths |
| DA2 | Dangling CNAME detection | No CNAME records pointing to unregistered or expired domains |

### D11-D13, DA1-DA2 Additional Tests

```bash
# D11 — Subdomain takeover risk
for sub in www api mail staging dev cdn app beta; do
  cname=$(dig +short CNAME ${sub}.myzr.io)
  if [ -n "$cname" ]; then
    resolved=$(dig +short A "$cname")
    if [ -z "$resolved" ]; then
      echo "RISK: ${sub}.myzr.io -> $cname (UNRESOLVED)"
    else
      echo "OK: ${sub}.myzr.io -> $cname -> $resolved"
    fi
  fi
done

# D12 — DNS rebinding resistance
dig myzr.io A | grep -E "^myzr" | awk '{print "TTL:", $2}'

# D13 — MTA-STS
dig _mta-sts.myzr.io TXT +short

# DA1 — DoH resolver
for path in /dns-query /resolve /doh /query; do
  curl -s -o /dev/null -w "%{http_code}" "https://myzr.io${path}?name=example.com&type=A" \
    -H "Accept: application/dns-json" -H "User-Agent: Mozilla/5.0"
done

# DA2 — Dangling CNAME
for sub in www api mail staging dev cdn; do
  cname=$(dig +short CNAME ${sub}.myzr.io)
  if [ -n "$cname" ]; then
    whois_result=$(dig +short A "$cname" 2>/dev/null)
    [ -z "$whois_result" ] && echo "DANGLING: ${sub}.myzr.io -> $cname"
  fi
done
```

## Output

Write to `SECURITY_CHECK.parts/dns.md`:

```markdown
### DNS

| # | Test | Result | Evidence |
|---|------|--------|----------|
| D1 | NS is Cloudflare | {PASS/FAIL} | {NS records} |
...
```

## After

Ask the user: **Do you want help fixing the DNS issues found?** If yes, invoke `/chk2:fix` with context about which DNS tests failed.

## Status signal

End your response with exactly one of these lines (orchestrator parses only this last signal — do not include any other "CHK2-STATUS:" text in your response):

- `CHK2-STATUS: OK` — all checks completed normally
- `CHK2-STATUS: RATE_LIMITED` — one or more target requests returned HTTP 429 (or Cloudflare 1015)
- `CHK2-STATUS: ERROR` — prerequisites missing, or the category could not complete
