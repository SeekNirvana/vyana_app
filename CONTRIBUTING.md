# Contributing to Vyana App

Thank you for helping improve Vyana.

## Getting started

1. Fork the repository and clone your fork.
2. `cp .env.example .env` and fill in values for features you are testing.
3. `flutter pub get`
4. Create a branch: `git checkout -b fix/my-change`

## Before you open a PR

```bash
flutter analyze
flutter test
```

Fix any issues reported. Keep changes focused — one logical change per PR.

## Secrets policy

Never commit:

- `.env`
- `android/key.properties`
- `*.keystore` / `*.jks`
- `android/local.properties`

Use the committed `*.example` templates only.

## Code style

Match the existing codebase: Riverpod for state, shared widgets under
`lib/src/widgets/`, feature screens as `part` files of `main.dart`.

## Questions

Open a GitHub issue for bugs and feature requests. For security concerns, see
[SECURITY.md](SECURITY.md).