# ClaudeCodeHubMobile

Native SwiftUI iOS client for [Claude Code Hub](https://github.com/ding113/claude-code-hub). It provides a mobile-friendly way to sign in to an existing Claude Code Hub deployment, inspect personal usage, and operate the admin monitoring surfaces without opening the web dashboard.

<p align="center">
<img width="15%" alt="image" src="https://github.com/user-attachments/assets/492b4fa6-c148-4e68-80da-c72633af33ac" />
<img  width="15%"  alt="image" src="https://github.com/user-attachments/assets/42413db8-86ba-4510-a7e1-1717d021d1b3" />
<img  width="15%"  alt="image" src="https://github.com/user-attachments/assets/78f1b16f-e014-478d-93e3-622e80e57a7d" />
</p>

## Current Status

The app is no longer an empty scaffold. It includes a working SwiftUI implementation with live Claude Code Hub API integration, Simulator builds, and read-oriented admin tooling.

## Features

### Personal usage

- Sign in with server URL + access key.
- Restore cookie-backed sessions across app launches.
- View quota/account status, recent usage, top models, and endpoint breakdowns.
- Browse paginated usage logs with model, endpoint, and status filters.
- Respect server timezone for date rendering.

### Admin dashboard

- Overview cards aligned with the web dashboard home:
  - concurrent sessions
  - recent RPM
  - today requests/cost
  - average response time
  - active sessions
  - daily leaderboards
- Circuit breaker panel showing providers currently in `open` or `half-open` state, plus operational alerts for error-rate, latency, spend, and provider health thresholds.
- Logs page with live monitoring, active sessions, operational alert summaries, server-backed usage-record search, and auto-refresh.
- Full rankings page for users, providers, and models across daily/weekly/monthly/all-time periods.
- User management inspection and safe writes:
  - searchable users
  - enabled/disabled state
  - provider groups/tags
  - keys and today usage
  - copy token action for copyable keys without displaying the full token inline
  - confirmation-gated user/key enable-disable writes with refresh-after-write feedback
- Provider management inspection and safe operations:
  - searchable providers
  - enabled/disabled filter
  - provider type/group
  - priority/weight/cost multiplier
  - today calls/cost and last model
  - confirmation-gated provider circuit reset for recovered open/half-open circuits

## Project Structure

```text
ClaudeCodeHubMobile/
  App/                    Root navigation and tab wiring
  Core/
    Models/               Flexible DTOs for Claude Code Hub responses
    Networking/           APIClient and response decoding
    Session/              SessionStore and auth persistence
  Features/
    Account/              Account/server controls
    Login/                Server URL + key sign-in
    Logs/                 Personal/admin usage logs and search
    Overview/             Personal/admin dashboard overview
    Providers/            Admin provider inspection
    Rankings/             Admin leaderboard views
    Users/                Admin user/key inspection
  Shared/                 Formatters and shared SwiftUI views
Tests/                    API contract and live integration tests
```

## Open in Xcode

Open `ClaudeCodeHubMobile.xcodeproj` in Xcode.

For a public repository, avoid committing personal signing values such as `DEVELOPMENT_TEAM` in `ClaudeCodeHubMobile.xcodeproj/project.pbxproj`. Keep local signing changes uncommitted or use local Xcode settings.

## Build and Test

### Unit/contract tests

```bash
swift test
```

### Live Claude Code Hub integration test

Requires a valid admin-capable key in the environment. Do not print or commit the key.

```bash
zsh -ic 'source ~/.zshrc >/dev/null 2>&1 || true; \
  CCH_BASE_URL="https://cch.com" \
  CCH_KEY="$CCH_KEY" \
  swift test --filter LiveServerIntegrationTests'
```

### Simulator build

```bash
xcodebuild -project ClaudeCodeHubMobile.xcodeproj \
  -scheme ClaudeCodeHubMobile \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Next Three Directions

1. **Safe admin write operations**
   - Add carefully confirmed enable/disable, quota, group, and provider edits.
   - Require confirmation sheets, clear before/after diffs, and audit-friendly success/failure states.
   - Start with low-risk toggles before provider endpoint/routing edits.

2. **Operational alerts and richer monitoring**
   - Add charted trends for cost, requests, errors, latency, and provider health.
   - Turn circuit breaker changes and high spend/error states into visible alerts.
   - Consider push/local notifications once the app has a background-safe refresh strategy.

3. **Device-ready release hardening**
   - Move any raw-key persistence to Keychain if persistence is needed beyond cookies.
   - Polish iPhone/iPad layouts, empty states, and accessibility labels.
   - Prepare signing, archive, TestFlight/manual distribution notes, and release tagging discipline. See `docs/release/preflight.md` for the current checklist.
  

## 社区支持
Linux.do 社区：https://linux.do/

## 许可证
MIT License
