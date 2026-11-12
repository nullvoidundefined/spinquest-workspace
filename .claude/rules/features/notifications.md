---
paths:
  - "Backend/src/services/socketEmiter/**"
  - "Backend/src/sockets/**"
  - "Backend/src/services/NotificationService.ts"
  - "Backend/src/services/FirebaseMessageService.ts"
  - "Backend/src/api/controllers/main/NotificationController.ts"
  - "Backend/src/api/controllers/admin/NotificationController.ts"
  - "Backend/src/db/entity/Notification.ts"
  - "Backend/src/db/entity/NotificationReceived.ts"
  - "Backend/src/db/entity/FirebaseMessage.ts"
  - "spinquest-frontend/src/features/notifications/**"
  - "spinquest-frontend/src/lib/api/notification/**"
  - "spinquest-frontend/src/lib/socket/**"
  - "spinquest-mobile-app/src/features/notifications/**"
  - "spinquest-mobile-app/src/lib/notifications/**"
  - "spinquest-mobile-app/src/lib/optimove/**"
  - "spinquest-mobile-app/src/lib/firebase/**"
  - "spinquest-mobile-app/src/hooks/use-optimove-push-handlers.ts"
---

## Summary

Notifications are split: in-app notifications are `notifications` rows pushed by a Postgres trigger and `LISTEN emitter` over Socket.IO to web and mobile bells; push is sent by Optimove from the mobile app; the Backend only stores FCM tokens.

## Invariants

- The listener runs only when `API_TYPE === 'Fundist'` and `FORK_ZERO` are set; other processes insert but never emit.
- The listener emits only `type === 'toast'` rows (event `notification`) or rows with a `command` (event `command`).
- `popup` rows (free spins, push bonus) are emitted directly after commit; the listener ignores them.
- `notification` and `command` go to room `usr<userId>`; the client acks `notificationReceived { notificationId, multi, userId }`.
- `receivedAt` is the soft-delete column; global rows (`userId` null) record reads in `notifications_received`.
- FE presentation is keyed on title strings: changing a Backend title changes or breaks which modal or toast appears.
- Mobile push priorities: `critical`, `gameplay` (default), `engagement`, `promotional`; opened pushes navigate via the payload's custom `url`, not Optimove's `notification.url`.
- The Backend token upsert reads `appDeviceId` and `fcmToken`, only when `source !== 'web'`.

## Gotchas

- FE matcher `❌ Failed` never matches Backend `❌ Purchase Failed`; `Redemption Confirmed` and `Deposit Failed` titles have no live source.
- `notificationReceived` has no ownership check and `multi` arrives undefined, so a global row can be soft-deleted for everyone.
- No replay on reconnect; missed rows appear on the next `GET /notification`.
- Mobile sends `deviceId` and `token` (Backend reads other names) and never sets `pushNotifications`, so `push_notification_bonus` is never paid.
- `tray` rows and global rows are never delivered live (inferred: room `usrnull`).

## Start here

`Backend/src/services/socketEmiter/DBEmitterService.ts`, `Backend/src/sockets/controllers/CommonController.ts`, `spinquest-frontend/src/features/notifications/components/notifications-socket-provider.tsx`, `spinquest-mobile-app/src/hooks/use-optimove-push-handlers.ts`.

Distilled on 2026-11-11 from personal-docs/notifications.md; re-check with /trace-feature refresh.
