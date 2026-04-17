---
name: chk1:security
description: Deep security audit — injection, auth, data exposure, crypto
allowed-tools: Read, Grep, Glob, Bash(git *)
---

# chk1:security — Security-Focused Audit

Deep security audit of the changed code. Focuses exclusively on security vulnerabilities, input validation, authentication, authorization, data exposure, and injection vectors.

## Instructions

1. Determine scope using the same logic as the full audit
2. Run pre-flight checks
3. Run `git diff <base>..<head>` and read all changed files
4. For each changed file, exhaustively check for:

### Injection Vulnerabilities
- SQL injection (string concatenation in queries, unsanitized parameters)
- Command injection (shell exec with user input, template strings in exec)
- XSS (unescaped output, innerHTML, dangerouslySetInnerHTML, v-html)
- Path traversal (user input in file paths, `..` sequences)
- LDAP injection, XML injection, header injection
- Server-Side Request Forgery (SSRF) — user-controlled URLs in fetch/request

### Authentication & Authorization
- Missing auth checks on new endpoints/routes
- Broken access control (horizontal/vertical privilege escalation)
- Hardcoded credentials, API keys, tokens, secrets
- Insecure session handling (predictable tokens, no expiry, no rotation)
- Missing CSRF protection on state-changing operations

### Data Exposure
- Sensitive data in logs (passwords, tokens, PII)
- Overly permissive API responses (returning more fields than needed)
- Error messages leaking internal details (stack traces, paths, versions)
- Secrets in source code, config files, or environment defaults

### Input Validation
- Missing validation on user input at system boundaries
- Type coercion vulnerabilities
- Regex denial of service (ReDoS)
- Integer overflow/underflow
- Deserialization of untrusted data

### Cryptography
- Weak algorithms (MD5, SHA1 for security purposes)
- Hardcoded IVs, salts, or keys
- Math.random() for security-sensitive values
- Missing HTTPS enforcement

5. Output format:

```markdown
### Security Audit

**Scope**: <base>..<head> (N commits, N files)

### Vulnerabilities

| # | File | Line | Category | Severity | OWASP | Description |
|---|------|------|----------|----------|-------|-------------|
| 1 | path/file | :42 | Injection | Critical | A03 | SQL injection via string concat |

### Security Warnings

| # | File | Line | Category | Description |
|---|------|------|----------|-------------|
| 1 | path/file | :15 | Data Exposure | API key in default config |

### Verdict

VERDICT: BLOCKED | PERMITTED | PERMITTED WITH WARNINGS
Vulnerabilities: N critical, N high, N medium, N low
```

OWASP references use the [2021 Top 10](https://owasp.org/www-project-top-ten/) categories:
- A01: Broken Access Control
- A02: Cryptographic Failures
- A03: Injection
- A04: Insecure Design
- A05: Security Misconfiguration
- A06: Vulnerable Components
- A07: Auth Failures
- A08: Data Integrity Failures
- A09: Logging Failures
- A10: SSRF

## After

Ask the user: **Do you want help fixing the security issues found?** If yes, invoke `/chk1:fix`.
