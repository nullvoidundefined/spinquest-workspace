# PRD: Storybook stories for the web client

**Status:** Draft · **Repo:** spinquest-frontend · **Technical spec:** [Storybook stories, batch by batch](./2026-11-19-storybook-stories-design.md)

## The problem

There's no easy way to see what our web components look like in every situation. Checking a loading state, an error message, a long German translation or a narrow phone screen means running the whole app locally and getting it into that state by hand. Edge cases often go unreviewed for that reason.

Storybook is the tool for this, and it is already installed. But it covers only 7 small components, and none of them currently render.

## What we're doing

We'll upgrade Storybook to the current version and give each component that matters its own page there, showing its states side by side. A component "matters" when the app actually uses it, and when it's either reused or the main piece of a feature. That's about 244 pages and 750–1,000 stories.

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
- **Everyone** gets automatic checks. A Storybook check renders every page in a real browser, and interactive components test their own behaviour. Developers run it before opening a pull request. An accessibility check runs on every page and reports problems without blocking.
- **Whoever adds a component** is asked, when Claude creates it, whether to generate its Storybook page straight away.

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
- A page that crashes, or whose interaction test fails, fails the Storybook check.
- Nobody's builds or deploys get slower. Storybook stays out of CI and deploys until we've measured what it would cost.
- If that measurement says yes, the latest Storybook is always available at one internal link, so nobody needs to run it locally to review.
- New components get a page from the start.
- The approach is proven on one real flow before we commit to the rest.

## Not in scope

- **Screenshot comparison tests.** We'll revisit them before a big restyle or library upgrade.
- **Whole screens.** They're left for later.
- **Moving or renaming component files.** The shelves are labels only.
- **Fixing bugs we find along the way.** Each one gets its own ticket.

## How it rolls out

The work is a short setup, a pilot, then independent batches. Each batch is one small pull request of at most 30 stories, with one Linear ticket. Batches can go in any order, wait, or be skipped, and stopping after any pull request leaves everything working. A checked-in to-do list, enforced by a test, always shows exactly what's left.

1. **Setup:**
   - Upgrade Storybook and get it starting again.
   - Add the fake-data layer, the language dropdown, the small-phone view and the browser checks, which developers run locally.
   - Add a Claude prompt that offers a Storybook page whenever a new component is created.
   - Later, best after the pilot: measure what Storybook would cost in CI. If it's worth it, add a separate check that only runs when components change, and publish Storybook from `main` to an internal link on our own dev infrastructure. Publishing needs a small piece of DevOps work. We chose our own infrastructure over Chromatic, a paid hosting service, because Chromatic's main feature is screenshot comparison, which we aren't doing.
2. **UI shelf.** Two pull requests.
3. **Pilot: the redeem flow.** Two pull requests covering the redemption components and the redemption dialog. This tests the whole approach on a real, data-heavy flow.
4. **Go/no-go.** Review what the pilot cost and delivered, and adjust the plan with real numbers.
5. **Shared and Features shelves.** 32 batches, starting with the shared building blocks and the money paths: lobby, shop, merch store and sign-in.

## Effort

| Stage | Engineer days |
|---|---|
| Setup and pilot | 5–6.5 |
| Each later batch | about 0.3 |
| All 32 later batches | 8–13 |

These are estimates with an LLM coding agent, including review. The pilot replaces them with measured numbers.

## How we'll know it worked

- The to-do list shrinks batch by batch, and Linear shows the same progress.
- The Storybook check passes on every Storybook pull request, and in CI once that's approved.
- Design reviews link to Storybook pages instead of local screenshots. This needs the hosted Storybook; until then, designers run it locally.
- Of the pages built so far, how many have a loading, error and small-phone view where the checklist calls for one. The to-do list and story tests report this.
- Every accessibility warning on a finished page has a ticket.

## Open questions

| Question | Who decides | When |
|---|---|---|
| Do we approve the extra packages the browser checks need (a browser-mode provider, Playwright and a Chromium download)? | Administrator | Before the setup PRs install them |
| Should Storybook run in CI and be hosted, given what it costs? | Engineering | After measuring it, best after the pilot |
| If it's hosted, what is the internal URL, and how is access restricted? | DevOps | Once hosting is approved |
| Should whole screens get pages? | Engineering and design | After the pilot, or once the batches are done |
| Should each pull request get its own Storybook preview link? | Engineering and DevOps | After the hosted Storybook is live |
| Should the cards product get its own Storybook? It currently shows the casino look. | Product and engineering | Later; it doesn't block anything |
