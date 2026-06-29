# Casandra — Hybrid Forum + AI Assistant Feature Kit

> **Important:** This kit lives in the `casandra-web` repo, which is the **compiled Flutter
> web build output** (deploy artifact). You cannot build this feature here — copy the files
> below into the **Casandra Flutter source repository** (the one with `lib/` and
> `pubspec.yaml`) and wire them in there.

This is a portable starter kit for adding two things to the Casandra automotive companion app:

1. **A hybrid community forum** — topic boards + threads/posts (async, persistent) *and*
   real-time chat rooms (live messages, presence, typing).
2. **An AI assistant chat** — a conversational "Casandra" assistant powered by Claude, fronted
   by a Cloud Function so the API key never ships in the client.

## Architecture

```
┌─────────────────────── Flutter app (lib/) ───────────────────────┐
│  features/                                                        │
│    forum/        boards → threads → posts        (async)         │
│    chat/         rooms → messages + presence      (real-time)     │
│    ai_assistant/ streaming chat with Claude                      │
│    messaging/    shared data layer (models, Firestore refs)      │
└──────────────┬───────────────────────────────┬──────────────────┘
               │ Firestore SDK                  │ HTTPS (SSE stream)
               ▼                                ▼
        ┌─────────────┐               ┌──────────────────────┐
        │  Firestore  │               │  Cloud Function       │
        │  + Auth     │               │  /aiAssistantStream   │
        │  + FCM      │               │  (holds ANTHROPIC key)│
        └─────────────┘               └──────────┬───────────┘
                                                 │ Anthropic SDK
                                                 ▼
                                          Claude (claude-opus-4-8)
```

**Why a Cloud Function for the AI part?** Calling Claude directly from Flutter would expose
`ANTHROPIC_API_KEY` in the shipped bundle. The function holds the key, enforces auth (Firebase
ID token), and streams the response back over SSE.

## What's in this kit

| Path | Purpose |
|---|---|
| `firestore.rules` | Security rules for boards, threads, posts, rooms, messages, presence |
| `firestore.indexes.json` | Composite indexes the queries need |
| `cloud-functions/` | TypeScript Cloud Function fronting the Claude API (streaming) |
| `flutter/lib/features/messaging/` | Shared data models + Firestore references |
| `flutter/lib/features/forum/` | Forum repository + minimal screens |
| `flutter/lib/features/chat/` | Real-time chat repository + minimal screen |
| `flutter/lib/features/ai_assistant/` | AI assistant client (talks to the Cloud Function) + screen |

## Setup (in the Flutter source repo)

### 1. Firebase

If the app isn't already on Firebase, add it:

```bash
flutter pub add firebase_core cloud_firestore firebase_auth firebase_messaging
flutterfire configure
```

Deploy rules + indexes:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### 2. Cloud Function (AI assistant)

```bash
cd cloud-functions
npm install
# Set the API key as a secret (never commit it)
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase deploy --only functions:aiAssistantStream
```

Copy the deployed function URL into `flutter/lib/features/ai_assistant/ai_assistant_repository.dart`
(`_functionUrl`).

### 3. Flutter

Copy `flutter/lib/features/*` into the app's `lib/features/` and add the three screens to your
router/navigation. The repositories are plain classes — wire them into whatever state management
the app already uses (Riverpod / Bloc / Provider).

## Model choice for the assistant

The Cloud Function uses **`claude-opus-4-8`** (most capable, 1M context). For a high-volume
consumer assistant you may prefer **`claude-sonnet-4-6`** (cheaper/faster) or **`claude-haiku-4-5`**
(cheapest) — change the `model` field in `cloud-functions/src/index.ts`. See the `claude-api`
reference for the trade-offs.

## Automotive extension idea

The assistant is set up to optionally use **tool calling** so it can pull the user's vehicle data
(make/model/year, maintenance history) and nearby service centers (you already integrate Google
Maps) into its answers. A `get_vehicle_context` tool stub is included in the Cloud Function —
wire it to your own data source.
