# ClaudeCodeHubMobile Technical Spec

## Scope

This document defines the initial architecture for a native SwiftUI iOS client that consumes an existing Claude Code Hub backend.

## Platform

- Language: Swift
- UI: SwiftUI
- Networking: URLSession
- Auth persistence: HTTPCookieStorage and Keychain when needed
- Local state: Observable macro or ObservableObject depending on deployment needs
- Minimum deployment target: iOS 18.0 in the current scaffold

## First-Phase Architecture

### App Layers

1. App
   - App entry point
   - Root navigation
   - Session bootstrap

2. Features
   - Login
   - Overview
   - Logs
   - Account

3. Services
   - Auth service
   - Usage service
   - Session store

4. Models
   - DTOs mapped from backend JSON
   - View models for presentation state

## Proposed Project Structure

```text
ClaudeCodeHubMobile/
  App/
  Core/
    Networking/
    Session/
    Models/
  Features/
    Login/
    Overview/
    Logs/
    Account/
  Shared/
```

The current repo does not yet use this structure. It should be introduced incrementally after the spec is accepted.

## Backend Integration

### Login Endpoint

- `POST /api/auth/login`
- Request body:

```json
{
  "key": "user-access-key"
}
```

### Planned Read-Only Actions

- `POST /api/actions/myUsage/getMyQuota`
- `POST /api/actions/myUsage/getMyStatsSummary`
- `POST /api/actions/myUsage/getMyUsageLogsBatchFull`
- `POST /api/actions/myUsage/getMyAvailableModels`
- `POST /api/actions/myUsage/getMyAvailableEndpoints`
- `POST /api/actions/system/getServerTimeZone`

## Networking Strategy

- Use one shared `URLSession` configured with cookie storage.
- Persist authenticated web session through cookies first.
- Normalize backend errors into app-level error states.
- Add a thin API client instead of binding views directly to raw JSON.

## State Management

- `SessionStore` owns base URL, auth state, and logout flow.
- Each feature owns its own screen state and loading lifecycle.
- Filters for logs should be stored in-memory for the first version.

## UI Notes

- Use tab-based navigation for v1.
- Overview should emphasize quota, remaining balance, and expiration.
- Logs should prefer dense rows with clear status and model labels.
- Date rendering must respect server timezone where backend semantics depend on server-local day boundaries.

## Error Handling

- Invalid server URL
- Login failed
- Session expired
- Network timeout
- Empty usage data
- Schema drift between app DTOs and backend responses

## Security Considerations

- Do not store the raw key in plain UserDefaults.
- Prefer cookie-backed auth after successful login.
- If raw key persistence is required later, use Keychain only.
- Avoid logging credentials or full request payloads in release builds.

## Testing Plan

- Unit tests for API request building
- Unit tests for DTO decoding
- Unit tests for session persistence behavior
- UI smoke tests for login and overview load

## Delivery Plan

### Milestone 1

- Establish project structure
- Build login flow
- Store session

### Milestone 2

- Build Overview screen
- Integrate quota and stats endpoints

### Milestone 3

- Build Logs screen
- Add filtering and refresh

### Milestone 4

- Add Account screen
- Add logout and session recovery polish

## Risks

- Backend action payloads may change because they originate from web-oriented action surfaces rather than a dedicated mobile API contract.
- Session behavior may differ between cookie mode and opaque session mode.
- Some server deployments may sit behind reverse proxies with nonstandard base paths.
