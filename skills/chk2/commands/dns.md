# chk2:dns — DNS and Email Security

Test DNS configuration for myzr.io. Append results to `SECURITY_CHECK.md`.

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

## Output

Append to `SECURITY_CHECK.md`:

```markdown
### DNS

| # | Test | Result | Evidence |
|---|------|--------|----------|
| D1 | NS is Cloudflare | {PASS/FAIL} | {NS records} |
...
```

## After

Ask the user: **Do you want help fixing the DNS issues found?** If yes, invoke `/chk2:fix` with context about which DNS tests failed.
