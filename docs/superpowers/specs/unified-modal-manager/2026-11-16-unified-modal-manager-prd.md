# PRD: One modal manager for the web client

**Status:** Draft · **Repo:** spinquest-frontend · **Technical spec:** [FE Spec: Unified Modal Manager](./2026-11-16-unified-modal-manager-design.md)

## The problem

The web client opens pop-ups (modals) in eight different ways, and none of them knows about the others. That causes real problems for players today:

- **Players lose notifications and free spins.** If two arrive close together, the second one silently replaces the first. A free-spin award can disappear before the player sees it.
- **A pop-up can hide behind another.** The free-spin pop-up sits below every other dialog, so it can open out of sight.
- **The app can't tell when something is covering the screen.** The lobby checks three different places to decide whether a pop-up is open, and still misses most of them.
- **"Show once" messages don't follow the player.** The MFA offer and the merch store welcome come back on a new device, or after the browser storage is cleared.

## What we're doing

We'll put every pop-up behind one manager, with one simple rule:

- **What the player opens stacks.** It appears straight away, on top of whatever is open, as it does today.
- **What the system opens queues.** Payment notifications, free spins and purchase results appear one at a time, in the order they arrived, so none is lost.
- **One ordered list of layers decides what sits on top.** The order is the one the app already uses: security checks above everything, then required gates, then ordinary dialogs.

The manager also becomes the one place that remembers which one-time messages a player has already seen. First that lives in the browser, then on the server, so it follows the player across devices.

## Who it's for

- **Players** never miss a notification or a reward. Required checks always appear on top, and they're not shown the same one-time message twice.
- **Engineers** get one way to open a pop-up from anywhere, including from socket messages and API responses, and one reliable answer to "is anything open?".
- **Support and QA** get a staging-only debug panel that opens any pop-up on demand, which makes reported issues quick to reproduce.

## Goals

- No player misses a required pop-up or a system notification.
- No player sees a one-time message again after dealing with it, on any device.
- One way to open a pop-up, and one reliable "is anything open?" check.
- Each pop-up flow moves over on its own, and removes its old code when it does.

## Not in scope

- **Redesigning how pop-ups look.**
- **Changing pages that open as overlays,** such as login or the vault. They only report that they're open.
- **Guided tours.**
- **Scheduling promotional pop-ups,** such as frequency caps or showing only when the player is idle. Nothing needs this yet.
- **Feature flags for the rollout.** Each change is small and is undone by reverting it.

## How it rolls out

The work is a set of small pull requests. After the first three, every pop-up flow moves on its own: in any order, later, or never. The app works correctly at every step.

1. **Test setup.** CI starts running tests, and the test helpers every later step uses are built.
2. **Foundation (two pull requests).**
   - The manager itself, with nothing visible changing yet.
   - A bridge that lets every existing pop-up report that it's open, so "is anything open?" is right from day one.
3. **The four fixes that matter most:**
   - Notifications and free spins queue instead of overwriting each other.
   - Purchase results queue with them.
   - The MFA offer and the merch welcome remember "seen" in one place.
   - The old dialog system is retired.
4. **The other flows, as time allows:** location permission, password reset, email and phone verification, the MFA screens, and the account-blocking gates. The gates carry the most risk, so they ship on their own, at a quiet time, with someone watching.
5. **"Seen" on the server.** Once the one-time messages are on the manager, the server stores what each player has seen, so it follows them across devices.

## Effort

| Stage | Engineer days |
|---|---|
| First visible fix (queued notifications) | 2–3 |
| Recommended path: test setup, foundation, the four fixes, and "seen" on the server | 5.5–8.5 |
| Every flow moved over | 8.5–13 |

These are estimates with an LLM coding agent, including review and QA. Expect about two weeks of calendar time for the recommended path, with normal review turnaround.

## How we'll know it worked

- Two notifications sent seconds apart both reach the player, in order.
- The free-spin pop-up always appears on top of ordinary dialogs.
- A one-time message seen on one device stays hidden on another.
- The lobby animation pauses under every pop-up, including the account-blocking gates.
- The old dialog system and the per-feature pop-up stores are deleted as each flow moves.

## Open questions

| Question | Who decides | When |
|---|---|---|
| Account-blocking gates show only on the main dashboard pages today. Should they also show on other pages, such as the standalone shop page used for in-app checkout? | Product and engineering | Before the gates move over |
| Today a new gate replaces the terms screen, or the reverse. Is it acceptable for both to be open, with terms on top? | Product | Before the gates move over |
| Should the lobby's "congrats" pop-up join the queue? | Product and design | Any time |
