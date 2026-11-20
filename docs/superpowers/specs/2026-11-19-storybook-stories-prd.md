# PRD: Storybook stories for the web client

**Status:** Draft · **Repo:** spinquest-frontend · **Technical spec:** [Storybook stories, batch by batch](./2026-11-19-storybook-stories-design.md)

## The problem

There's no easy way to see what our web components look like in every situation. Checking a loading state, an error message, a long German translation or a narrow phone screen means running the whole app locally and getting it into that state by hand. Edge cases often go unreviewed for that reason.

Storybook is the tool for this, and it is already installed. But it covers only 7 small components, and it currently doesn't start.

## What we're doing

We'll upgrade Storybook to the current version and give each component that matters its own page there, showing its states side by side. A component "matters" when the app actually uses it, and when it's either reused or the main piece of a feature. That's about 245 pages and 750–1,000 stories.

Some things don't get a page of their own:

- **Small pieces used inside a single parent** show up on the parent's page.
- **Parked designs,** such as the landing variants that aren't being served, are left out until they go live.
- **Whole screens** are left for later. Their content is covered through the components they're built from.

The pages are grouped in Storybook's sidebar into three shelves:

| Shelf | What's on it | Examples |
|---|---|---|
| **UI** | The basic building blocks | buttons, switches, tabs, spinners |
| **Shared** | Common pieces used across the app, plus the page frame | modals, coin toggles, top bar, footer |
| **Features** | Pieces that belong to one part of the product | shop package card, redemption modal, lobby rows |

The toolbar has a **language dropdown** that switches every page to any of our 11 languages, in the same order and with the same names as the app's own language picker. It also has a **small-phone view**, 320px wide.

## Who it's for

- **Designers** see every state of a component (normal, loading, error, empty, small phone, any language) without asking an engineer to set it up.
- **Engineers** build and change UI without running the backend, against realistic fake data that is the same every time.
- **Everyone** gets automatic checks. CI renders every page in a real browser, and interactive components test their own behaviour. An accessibility check runs on every page and reports problems without blocking the pull request.

## What "done" looks like for each component

| Component | Gets |
|---|---|
| Every component | Its normal look and its main variations |
| Shows data from the server | Plus loading, error (with a Retry option) and empty versions |
| Sensitive to layout, such as a modal, a row or the page frame | Plus a small-phone view and a German view |
| Interactive, such as a form, tabs or a Retry button | Plus an automatic test that clicks through it and checks the result |

Each accessibility warning inside a component gets a ticket.

## Goals

- Every in-use component that is reusable or a feature's main piece has a Storybook page.
- Storybook works without a backend and never talks to real servers.
- A page that crashes, or whose interaction test fails, blocks the pull request.
- The latest Storybook is always available at one internal link, so nobody needs to run it locally to review.
- The approach is proven on one real flow before we commit to the rest.

## Not in scope

- **Screenshot comparison tests.** We'll revisit them before a big restyle or library upgrade.
- **Whole screens.** They're left for later.
- **Moving or renaming component files.** The shelves are labels only.
- **Fixing bugs we find along the way.** Each one gets its own ticket.

## How it rolls out

The work is a short setup, a pilot, then independent batches. Each batch is one small pull request of at most 30 stories, with one Linear ticket. Batches can go in any order, wait, or be skipped, and stopping after any pull request leaves everything working. A checked-in to-do list, enforced by a test, always shows exactly what's left.

1. **Setup (three pull requests):**
   - Upgrade Storybook and get it starting and building in CI.
   - Add the fake-data layer, the language dropdown, the small-phone view and the browser checks.
   - Publish it from `main` to an internal link on our own dev infrastructure. This needs a small piece of DevOps work. We chose our own infrastructure over Chromatic, a paid hosting service, because Chromatic's main feature is screenshot comparison, which we aren't doing.
2. **UI shelf.** Two pull requests.
3. **Pilot: the redeem flow.** Two pull requests covering the redemption components and the redemption dialog. This tests the whole approach on a real, data-heavy flow.
4. **Go/no-go.** Review what the pilot cost and delivered, and adjust the plan with real numbers.
5. **Shared and Features shelves.** 31 batches, starting with the shared building blocks and the money paths: lobby, shop, merch store and sign-in.

## Effort

| Stage | Engineer days |
|---|---|
| Setup and pilot | 4.5–6 |
| Each later batch | about 0.3 |
| All 31 later batches | 8–13 |

These are estimates with an LLM coding agent, including review. The pilot replaces them with measured numbers.

## How we'll know it worked

- The to-do list shrinks batch by batch, and Linear shows the same progress.
- The Storybook check passes in CI on every pull request.
- Design reviews link to Storybook pages instead of local screenshots.
- Every accessibility warning on a finished page has a ticket.

## Open questions

| Question | Who decides | When |
|---|---|---|
| What is the internal Storybook URL, and how is access restricted? | DevOps | Before the hosting pull request |
| Should whole screens get pages? | Engineering and design | After the pilot, or once the batches are done |
| Should each pull request get its own Storybook preview link? | Engineering and DevOps | After the hosted Storybook is live |
| Should the cards product get its own Storybook? It currently shows the casino look. | Product and engineering | Later; it doesn't block anything |
