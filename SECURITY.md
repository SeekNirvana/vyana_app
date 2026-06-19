# Security Policy

## Reporting a vulnerability

If you discover a security issue in Vyana App, please report it responsibly.

**Do not** open a public GitHub issue for exploitable vulnerabilities.

Contact: **security@seeknirvana.com** (or open a
[GitHub Security Advisory](https://github.com/SeekNirvana/vyana_app/security/advisories/new)
on this repository).

Include:

- Description of the issue
- Steps to reproduce
- Impact assessment
- Suggested fix (if any)

We aim to acknowledge reports within 72 hours.

## Secrets

This repository must never contain:

- Production `.env` values
- Android signing keystores or `key.properties` passwords
- Private API keys or RPC credentials with billing attached

If you accidentally commit a secret, rotate it immediately and force-push is
not sufficient — treat the secret as compromised.

## Scope

In scope: Vyana App source in this repository, release build configuration that
ships with the app.

Out of scope: Third-party services (Reown, Solana RPC providers, HuggingFace model
hosting), user devices, PRANA ring firmware.