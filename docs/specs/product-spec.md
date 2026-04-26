# ClaudeCodeHubMobile Product Spec

## Summary

ClaudeCodeHubMobile is a native iOS app for viewing personal Claude Code Hub usage records. The first release focuses on read-only usage visibility for individual users who already have access to a Claude Code Hub server.

## Goals

- Let a user sign in to an existing Claude Code Hub server from iPhone or iPad.
- Show current personal quota and expiration information.
- Show recent usage metrics in a mobile-friendly summary.
- Show usage logs with lightweight filtering.
- Keep the first release strictly read-only.

## Non-Goals

- No admin dashboard features.
- No server management, key management, or proxy configuration.
- No write actions such as account edits or quota changes.
- No offline-first syncing in the first release.
- No push notifications in the first release.

## Target Users

- Individual Claude Code Hub users who want to inspect current usage from mobile.
- Team members who need a quick read-only view of quota, cost, and request history without opening the web console.

## Core User Stories

1. As a user, I can enter a server URL and key to sign in.
2. As a user, I can see whether my account is still active and when it expires.
3. As a user, I can see my current quota, remaining amount, and recent consumption.
4. As a user, I can inspect recent request logs by model, endpoint, and time.
5. As a user, I can refresh the data to see the latest status.

## MVP Screens

### 1. Login

- Input: server base URL
- Input: access key
- Action: sign in
- State: loading, success, failure

### 2. Overview

- User status
- Expiration time
- Current quota summary
- Today or recent usage summary
- Top models or endpoint breakdown

### 3. Logs

- Paginated usage records
- Filter by model
- Filter by endpoint
- Filter by status
- Pull to refresh

### 4. Account

- Current server
- Current signed-in user context if available
- Sign out

## Information Architecture

- Tab 1: Overview
- Tab 2: Logs
- Tab 3: Account

## Data Requirements

The app is expected to rely on existing Claude Code Hub backend actions for:

- Login session creation
- Personal quota lookup
- Personal usage summary
- Personal usage logs
- Available model list
- Available endpoint list
- Server timezone lookup

## Success Criteria

- User can complete sign-in on a valid Claude Code Hub deployment.
- Overview data loads in one session without using the web UI.
- Logs page can display recent records and apply basic filters.
- Session remains usable across app restarts until logout or session expiry.

## Open Questions

- Whether login should use cookie session only or support bearer mode as a fallback.
- Whether Overview should default to today, rolling 24 hours, or a server-defined range.
- Whether iPad should use the same tab layout or a split layout in v1.

