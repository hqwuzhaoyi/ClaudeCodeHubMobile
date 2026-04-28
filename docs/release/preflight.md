# Release Preflight

Use this checklist before running on a real device, archiving, or pushing a TestFlight/manual build.

## Security and signing

- Do not commit raw access keys, cookies, or screenshots containing full tokens.
- Keep `DEVELOPMENT_TEAM` and local provisioning values out of `ClaudeCodeHubMobile.xcodeproj/project.pbxproj` in public commits.
- Sign in with a test/admin key only on trusted devices; the app discards the raw key after login and restores via server cookies.
- Verify admin write actions show a confirmation dialog with before/after state before tapping the destructive action.

## Required local checks

```bash
swift test

xcodebuild -project ClaudeCodeHubMobile.xcodeproj \
  -scheme ClaudeCodeHubMobile \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Device smoke test

1. Open the app on iPhone and iPad size classes.
2. Sign in to a staging or trusted Claude Code Hub deployment.
3. Verify Overview, Logs, Rankings, Users, Providers, and Account load without layout clipping.
4. Confirm operational alerts appear when the server reports high error rate, high latency, cost spike, or open provider circuits.
5. For safe admin writes, test enable/disable against a disposable user/key and reset only a recovered provider circuit.
6. Sign out and relaunch; confirm cookies/server state are cleared for that server.

## Release notes discipline

- Mention any admin write endpoint compatibility assumptions.
- Document whether live integration tests were run and with which server environment class (staging/production), never with secrets.
- Tag releases only after the above checks pass and the git tree excludes local signing values.
