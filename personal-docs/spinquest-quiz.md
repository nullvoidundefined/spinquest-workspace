# SpinQuest orientation quiz (140 questions)

Twenty questions on each of Loc's seven topics: feature flags, signup and onboarding, first-time user experience, the lobby, promotions and bonuses, notifications, and payments. Questions about the product model (Gold Coins and Sweeps Coins, AMOE, blocked states) are folded into the closest topic.

Based on the code as read on 2026-11-11: Backend `PeterSons`, `spinquest-frontend`, and `spinquest-mobile-app` `master` at `fce425f0`. Several questions are about known gaps that may get fixed; if an answer looks wrong, check the matching note in this folder.

**To re-run it:** ask Claude to "quiz me from `personal-docs/spinquest-quiz.md`", optionally naming a topic or a number of questions. To test yourself without Claude, expand the answer under each question. Answer positions are shuffled.

## Contents

1. [Feature flags](#feature-flags) (Q1-20)
2. [Signup and onboarding](#signup-and-onboarding) (Q21-40)
3. [First-time user experience](#first-time-user-experience) (Q41-60)
4. [Lobby](#lobby) (Q61-80)
5. [Promotions and bonuses](#promotions-and-bonuses) (Q81-100)
6. [Notifications](#notifications) (Q101-120)
7. [Payments](#payments) (Q121-140)

## Feature flags

### Q1. Which vendor powers SpinQuest's feature flags on both the frontend and backend?

- **A.** Optimove
- **B.** PostHog
- **C.** Firebase Remote Config
- **D.** LaunchDarkly

<details><summary>Answer</summary>

**B.** PostHog

The backend uses posthog-node (FeatureFlagService.ts) and the frontend uses posthog-js.

</details>

### Q2. Which flag prefix marks a server-only kill-switch that is never sent to the client?

- **A.** perm-
- **B.** ops-
- **C.** feat-
- **D.** exp-

<details><summary>Answer</summary>

**B.** ops-

ops- flags stay on the server so a kill-switch can't fail open when an ad blocker stops PostHog in the browser.

</details>

### Q3. What does the frontend getFlag() return when asked for an ops- key?

- **A.** Always true
- **B.** It throws an error
- **C.** The caller's fallback value
- **D.** The live PostHog value

<details><summary>Answer</summary>

**C.** The caller's fallback value

getFlag short-circuits ops- keys to the fallback, because these flags are enforced on the server.

</details>

### Q4. With ENABLE_SERVER_FLAGS on and a user logged in, where does getFlag() read flags from?

- **A.** localStorage
- **B.** A zustand store filled from the server, falling back to the caller's default
- **C.** The PostHog browser SDK
- **D.** A cookie set at login

<details><summary>Answer</summary>

**B.** A zustand store filled from the server, falling back to the caller's default

Logged-in users read only the store the server fills. A missing key fails closed to the fallback and never re-evaluates in the browser.

</details>

### Q5. How often does the FlagsSync component poll GET /flags?

- **A.** Every 2 minutes
- **B.** Every 30 minutes
- **C.** Only on window focus
- **D.** Every 10 seconds

<details><summary>Answer</summary>

**A.** Every 2 minutes

TWO_MIN polling plus the backend's flag-definition poll gets a flipped flag to an active session within about 2.5 minutes.

</details>

### Q6. Is the frontend server-flag store persisted between page loads?

- **A.** Yes, in sessionStorage
- **B.** Yes, in IndexedDB
- **C.** No. Each cold load starts empty and re-fetches
- **D.** Yes, in localStorage

<details><summary>Answer</summary>

**C.** No. Each cold load starts empty and re-fetches

Not persisting it avoids stale flags on boot. While the store is empty, callers get their safe defaults.

</details>

### Q7. What does the requireOpsFlag middleware return when its flag is off?

- **A.** 404
- **B.** 403
- **C.** 401
- **D.** 503

<details><summary>Answer</summary>

**D.** 503

Kill-switched routes answer 503 Service Unavailable.

</details>

### Q8. Why should you never subscribe to the flag store inside DashboardLayout?

- **A.** A flag-driven re-render spreads down to the game iframe
- **B.** It breaks i18n
- **C.** It leaks PII
- **D.** It disables polling

<details><summary>Answer</summary>

**A.** A flag-driven re-render spreads down to the game iframe

Read flags in leaf components, or imperatively with getState(), so the game Outlet doesn't re-render.

</details>

### Q9. How is an entire provider integration (for example Aeropay) left out of a backend deployment?

- **A.** An ops- PostHog flag
- **B.** A database setting
- **C.** ENABLE_*_API env vars that decide which controller folders express.ts loads
- **D.** A build-time Vite variable

<details><summary>Answer</summary>

**C.** ENABLE_*_API env vars that decide which controller folders express.ts loads

express.ts skips a controller folder whose ENABLE_*_API var is false. That's the env-var switch mechanism, separate from PostHog.

</details>

### Q10. Which of these must NEVER be wrapped in a feature flag?

- **A.** GeoComply, the blocked-states check, KYC on redemption, or AMOE
- **B.** A beta-access entitlement
- **C.** A new cashier UI
- **D.** An A/B test on lobby copy

<details><summary>Answer</summary>

**A.** GeoComply, the blocked-states check, KYC on redemption, or AMOE

These are legally required invariants listed in the runbook.

</details>

### Q11. What is the correct default value for a gradual-rollout feat- flag?

- **A.** 'control'
- **B.** false
- **C.** null
- **D.** true

<details><summary>Answer</summary>

**B.** false

Rollout flags default to false, so the old behaviour is the safe default. Flags that switch a protection on default to true.

</details>

### Q12. Where does a newly logged-in user's first set of server flags come from, before the first poll?

- **A.** A cookie set at registration
- **B.** Server-side rendering
- **C.** A WebSocket event
- **D.** Embedded in the login or signup response

<details><summary>Answer</summary>

**D.** Embedded in the login or signup response

AuthController's resolveAuthFlags embeds client-safe flags in the auth response, so the first screen already has them.

</details>

### Q13. Which env var builds the web app as either the casino or the cards product?

- **A.** FORK_ZERO
- **B.** VITE_APP_PRODUCT
- **C.** NODE_ENV
- **D.** API_TYPE

<details><summary>Answer</summary>

**B.** VITE_APP_PRODUCT

VITE_APP_PRODUCT=casino|cards. The backend has its own PRODUCT=sweeps|cards, and the two must agree.

</details>

### Q14. Does a backend flag check make a network call to PostHog on the request path?

- **A.** Only for ops- flags
- **B.** Only for anonymous users
- **C.** No. posthog-node evaluates locally against flag definitions it polls in the background
- **D.** Yes, every check

<details><summary>Answer</summary>

**C.** No. posthog-node evaluates locally against flag definitions it polls in the background

FeatureFlagService uses onlyEvaluateLocally: true. Until warmup loads the definitions, checks return the default.

</details>

### Q15. What do backend flag checks return when ENABLE_POSTHOG is false or the PostHog client fails to start?

- **A.** true
- **B.** They throw
- **C.** The last cached value
- **D.** The caller's defaultValue

<details><summary>Answer</summary>

**D.** The caller's defaultValue

That's why you must never pass defaultValue: true to requireOpsFlag: a failed init would quietly turn the feature on.

</details>

### Q16. A flag named feat-ops-kill would be...

- **A.** Renamed automatically
- **B.** Sent to the client, since it starts with feat-
- **C.** Treated as an experiment
- **D.** Rejected from the client payload, because it contains an 'ops' segment

<details><summary>Answer</summary>

**D.** Rejected from the client payload, because it contains an 'ops' segment

isClientSafeFlag rejects any key with an ops segment as defence in depth, while allowing words like 'coops'.

</details>

### Q17. If PostHog can't evaluate a flag locally, what does getClientFlags put in the map for it?

- **A.** null
- **B.** The rollout percentage
- **C.** Nothing; the key is left out so the client uses its own default
- **D.** false

<details><summary>Answer</summary>

**C.** Nothing; the key is left out so the client uses its own default

The server never guesses a value for the client.

</details>

### Q18. A handler checks five flags for one user. Which method should it use?

- **A.** evaluateAll() once, then read from the returned scope
- **B.** A Redis cache
- **C.** isEnabled five times
- **D.** getClientFlags

<details><summary>Answer</summary>

**A.** evaluateAll() once, then read from the returned scope

evaluateAll does a single evaluation and returns a scope with isEnabled and getVariant.

</details>

### Q19. A flag targets users by email domain. What must the backend pass, or the flag returns its default?

- **A.** The JWT
- **B.** A cohort id
- **C.** personProperties (for example { email })
- **D.** The userId only

<details><summary>Answer</summary>

**C.** personProperties (for example { email })

Local evaluation can't apply property-based rules without the properties.

</details>

### Q20. Why does the web client call posthog.identify(user.id) with the backend user id?

- **A.** To start session replay
- **B.** So the frontend and backend put the user in the same bucket for each flag
- **C.** To enable push
- **D.** To log out other devices

<details><summary>Answer</summary>

**B.** So the frontend and backend put the user in the same bucket for each flag

PostHog buckets by distinct_id; using the verbatim backend id keeps both sides consistent.

</details>

## Signup and onboarding

### Q21. Which endpoint does the web client call to register a user with email and password?

- **A.** POST /auth/signup
- **B.** POST /users
- **C.** POST /auth/register
- **D.** POST /auth/social-signup

<details><summary>Answer</summary>

**D.** POST /auth/social-signup

The single signup endpoint is /auth/social-signup. The web's useRegister -> /auth/signup is dead code with no backend route.

</details>

### Q22. What must a new user confirm before they can load ANY game?

- **A.** Email
- **B.** MFA enrollment
- **C.** KYC identity
- **D.** Phone number

<details><summary>Answer</summary>

**D.** Phone number

/apps/load throws 'Phone not Verified!' without isPhoneConfirmed, for both currencies.

</details>

### Q23. On the backend, what does User.isVerified() check?

- **A.** KYC VERIFIED
- **B.** MFA enabled
- **C.** isPhoneConfirmed only
- **D.** Phone and email confirmed

<details><summary>Answer</summary>

**C.** isPhoneConfirmed only

isVerified() is just isPhoneConfirmed. isVerifiedFully() requires phone and email.

</details>

### Q24. Which vendor sends the SMS phone-verification codes?

- **A.** Vonage
- **B.** Optimove
- **C.** Twilio
- **D.** Sinch

<details><summary>Answer</summary>

**D.** Sinch

SinchService handles start and verify. Outside production, a DANGEROUS_PHONE_VERIFICATION_BYPASS_CODE works.

</details>

### Q25. For which signup sources is the Cloudflare Turnstile captcha skipped?

- **A.** web
- **B.** ios and android
- **C.** All sources
- **D.** None

<details><summary>Answer</summary>

**B.** ios and android

AuthController skips verifyTurnstile when source is ios or android.

</details>

### Q26. Where does the coin bonus a new account starts with come from?

- **A.** The signup_bonus row in json_config
- **B.** SIGNUP_GOLD_COINS_BONUS env var
- **C.** There is no signup bonus
- **D.** A hard-coded constant in AuthService

<details><summary>Answer</summary>

**A.** The signup_bonus row in json_config

getUserSignupBonus reads json_config 'signup_bonus' (gold coins and diamonds). The SIGNUP_*_COINS_BONUS env vars are unused.

</details>

### Q27. What happens when the IDComply check fails after the signup transaction commits?

- **A.** The user is soft-deleted with deletedReason 'idComply' and gets a 403
- **B.** Nothing; it's logged only
- **C.** Signup is retried
- **D.** The user is flagged for KYC

<details><summary>Answer</summary>

**A.** The user is soft-deleted with deletedReason 'idComply' and gets a 403

The row already exists, so it's soft-deleted, and ForbiddenError('IDComply failed') is returned. The verification email has already been sent.

</details>

### Q28. Which URL parameter carries a referral code that ReferralCodeProvider saves in a cookie?

- **A.** ?aff=
- **B.** ?code=
- **C.** ?u=
- **D.** ?ref=

<details><summary>Answer</summary>

**C.** ?u=

?u= is the referral code (30-day cookie). ?lpc= is the landing-page code (24-hour override).

</details>

### Q29. How does the native app do Google, Apple or Meta signup?

- **A.** The native SDK returns an ID token, which is posted as authSecret to /auth/login, then /auth/social-signup
- **B.** It doesn't support social signup
- **C.** Through the backend /auth/*/relay redirect routes
- **D.** Through a WebView to the web signup page

<details><summary>Answer</summary>

**A.** The native SDK returns an ID token, which is posted as authSecret to /auth/login, then /auth/social-signup

Mobile uses the provider SDKs and sends the token directly. No client in the workspace uses the relay and exchange routes.

</details>

### Q30. What is the mobile app built with?

- **A.** A web wrapper (Capacitor)
- **B.** Flutter
- **C.** Swift and Kotlin
- **D.** React Native with Expo

<details><summary>Answer</summary>

**D.** React Native with Expo

Expo and React Native with Expo Router and NativeWind. Almost no hand-written native code; native SDKs come in through config plugins.

</details>

### Q31. Which of these is NOT required to play with Gold Coins?

- **A.** A valid login token
- **B.** Current terms accepted
- **C.** Phone confirmed
- **D.** Email confirmed

<details><summary>Answer</summary>

**D.** Email confirmed

Email confirmation gates redemption, rewards and merch. It doesn't gate gameplay.

</details>

### Q32. On which backend branch should backend code be read?

- **A.** PeterSons
- **B.** main
- **C.** feature/auth-central
- **D.** master

<details><summary>Answer</summary>

**A.** PeterSons

PeterSons is effectively the backend's main branch.

</details>

### Q33. Which states are blocked by default (BLOCKED_STATES)?

- **A.** WA, ID, NV
- **B.** NY, LA, NJ
- **C.** CA, TX, FL
- **D.** None

<details><summary>Answer</summary>

**B.** NY, LA, NJ

A non-empty ALLOWED_STATES allow-list takes priority, and the cards product requires one.

</details>

### Q34. What happens when someone under 18 submits signup?

- **A.** They get gold-coins-only mode
- **B.** BadRequestError: 'Must be atleast 18 years old to sign up'
- **C.** Their account needs parental KYC
- **D.** They're soft-deleted

<details><summary>Answer</summary>

**B.** BadRequestError: 'Must be atleast 18 years old to sign up'

socialCasinoSignupService checks the date of birth before anything else.

</details>

### Q35. With NEW_TERMS off, is terms acceptance enforced at signup?

- **A.** No. Signup doesn't require it, and isUserTermsCurrent returns true
- **B.** Only for sweeps play
- **C.** Yes
- **D.** Only on mobile

<details><summary>Answer</summary>

**A.** No. Signup doesn't require it, and isUserTermsCurrent returns true

With NEW_TERMS on, signup requires all active terms, and every request checks that the user's terms are current.

</details>

### Q36. At signup, which column does the phone number go into first?

- **A.** phoneNumberNew. It's copied to phoneNumber when the code is confirmed
- **B.** users_phone
- **C.** phoneNumber
- **D.** It isn't stored until confirmed

<details><summary>Answer</summary>

**A.** phoneNumberNew. It's copied to phoneNumber when the code is confirmed

confirmUserPhone sets isPhoneConfirmed and copies phoneNumberNew into phoneNumber.

</details>

### Q37. What happens when a second account confirms a phone number already used by another account?

- **A.** The second account is soft-deleted with deletedReason 'phoneLock'
- **B.** The first account loses the number
- **C.** Both accounts are merged
- **D.** Nothing

<details><summary>Answer</summary>

**A.** The second account is soft-deleted with deletedReason 'phoneLock'

The unique index users_phoneNumber_ukey fires, and the call returns 'Could not verify phone'.

</details>

### Q38. What is marketingEmails set to for every new signup?

- **A.** false
- **B.** It's unset until settings are opened
- **C.** It follows the SMS checkbox
- **D.** true

<details><summary>Answer</summary>

**D.** true

marketingEmails is always true at signup; only marketingSMSs follows the checkbox.

</details>

### Q39. How is the email confirmation link verified?

- **A.** A PostHog event
- **B.** A Sinch callback
- **C.** A JWT signed with JWT_EMAIL_VERIFICATION_SECRET_KEY, posted to /auth/confirm-email
- **D.** A one-time code in Redis

<details><summary>Answer</summary>

**C.** A JWT signed with JWT_EMAIL_VERIFICATION_SECRET_KEY, posted to /auth/confirm-email

The link opens /auth/confirm-email?token=..., and an expired token gives ExpiredEmailConfirmationTokenError.

</details>

### Q40. Which accounts bypass the geo checks (and IDComply at signup)?

- **A.** All staging accounts
- **B.** Usernames in GEO_WHITELIST, any account when LOCAL_ENV is set, and @spinquest.com emails
- **C.** VIP users
- **D.** Mobile users

<details><summary>Answer</summary>

**B.** Usernames in GEO_WHITELIST, any account when LOCAL_ENV is set, and @spinquest.com emails

The bypass places the user in Colorado. The team has recorded this as a bug risk.

</details>

## First-time user experience

### Q41. Where does the WEB casino lobby tour keep its 'seen' state?

- **A.** localStorage
- **B.** A cookie
- **C.** In memory only, so it's lost on refresh
- **D.** A User column

<details><summary>Answer</summary>

**C.** In memory only, so it's lost on refresh

casino-ftue.store.ts is deliberately session-only. A refresh means the tour is never shown again.

</details>

### Q42. Where does the MOBILE lobby tour keep its state?

- **A.** In memory only
- **B.** AsyncStorage, saved on the device
- **C.** Optimove
- **D.** The backend

<details><summary>Answer</summary>

**B.** AsyncStorage, saved on the device

lobby-tour.store uses zustand persist with AsyncStorage.

</details>

### Q43. On the web, when does the casino tour start?

- **A.** On every login
- **B.** On the first purchase
- **C.** After the phone is confirmed
- **D.** Right after signup, before the phone is verified

<details><summary>Answer</summary>

**C.** After the phone is confirmed

Web goes phone first, then tour. activateFtue() runs when isPhoneConfirmed flips.

</details>

### Q44. What can happen on mobile right after the lobby tour finishes or is skipped?

- **A.** The shop opens
- **B.** The KYC flow opens
- **C.** The app restarts
- **D.** The push-notification permission prompt may be shown

<details><summary>Answer</summary>

**D.** The push-notification permission prompt may be shown

next() and skip() call maybeShowNotificationPermissionPrompt().

</details>

### Q45. Which client sends TUTORIAL_BEGIN, TUTORIAL_COMPLETE and TUTORIAL_SKIP analytics events?

- **A.** Web only
- **B.** Mobile only
- **C.** Both
- **D.** Neither

<details><summary>Answer</summary>

**B.** Mobile only

The web tour sends no analytics events.

</details>

### Q46. What does the cards tour and welcome pack run against?

- **A.** Central services
- **B.** The Cards controllers on the backend
- **C.** PostHog
- **D.** A frontend mock (mock-service.ts)

<details><summary>Answer</summary>

**D.** A frontend mock (mock-service.ts)

The backend's welcomeBundle isn't connected to any route.

</details>

### Q47. What's wrong with the cards tour's localStorage key, cards.ftue.state.v1?

- **A.** It expires too fast
- **B.** It isn't per user, so a second account on the same browser inherits 'completed'
- **C.** It's encrypted
- **D.** Nothing

<details><summary>Answer</summary>

**B.** It isn't per user, so a second account on the same browser inherits 'completed'

The key has no user id in it.

</details>

### Q48. When is the new_player_offer shop package hidden from a user?

- **A.** Once user.newPlayerOffer is true
- **B.** After 15 minutes
- **C.** After KYC
- **D.** Never

<details><summary>Answer</summary>

**A.** Once user.newPlayerOffer is true

checkShopPackage filters it out. The flag is set when a payment for that package is credited.

</details>

### Q49. How is a user's first settled deposit marked?

- **A.** A PostHog event only
- **B.** user.firstDeposit = true
- **C.** A row in first_purchases
- **D.** PaymentTransaction.xtime = 1

<details><summary>Answer</summary>

**D.** PaymentTransaction.xtime = 1

xtime is the per-user deposit sequence number. xtime = 1 triggers the FTD and first_purchase events.

</details>

### Q50. Which oddly named mobile store holds the flag that gates onboarding in production?

- **A.** useFeatureFlagsStore
- **B.** useDeveloperSettingsStore (showOnboarding)
- **C.** useNavStore
- **D.** useAuthStore

<details><summary>Answer</summary>

**B.** useDeveloperSettingsStore (showOnboarding)

Signup sets showOnboarding to true in the developer-settings store.

</details>

### Q51. For a 'seen' flag that works across web AND the app, which storage pattern should you use?

- **A.** localStorage or AsyncStorage
- **B.** A column on User (needs a migration)
- **C.** In-memory store
- **D.** A PostHog person property

<details><summary>Answer</summary>

**B.** A column on User (needs a migration)

Only a server column survives a new device, a new browser and both clients.

</details>

### Q52. What does the web casino tour end with?

- **A.** A survey
- **B.** A KYC prompt
- **C.** An offer card for the new_player_offer package
- **D.** The daily bonus

<details><summary>Answer</summary>

**C.** An offer card for the new_player_offer package

The last steps (offerDrop, offerSquash) show the offer, and its button opens that shop package.

</details>

### Q53. What does the web tour do if the new_player_offer package isn't in the shop (for example, already bought)?

- **A.** Skips the offer steps once the shop has finished loading
- **B.** Waits forever
- **C.** Shows a different package
- **D.** Shows an error

<details><summary>Answer</summary>

**A.** Skips the offer steps once the shop has finished loading

checkShopPackage hides the package, so the controller calls skip() at the offer steps.

</details>

### Q54. Which step list does the web tour use in a gold-coins-only jurisdiction?

- **A.** The cards tour
- **B.** GOLD_COINS_ONLY_STEPS, a filtered version of the same list
- **C.** No tour
- **D.** FULL_MODE_STEPS

<details><summary>Answer</summary>

**B.** GOLD_COINS_ONLY_STEPS, a filtered version of the same list

The sweeps-specific steps are removed.

</details>

### Q55. What does the web tour do on a short mobile-landscape viewport?

- **A.** Skips itself
- **B.** Waits for portrait
- **C.** Shows a compact version
- **D.** Rotates the screen

<details><summary>Answer</summary>

**A.** Skips itself

CasinoFtue calls skip() when the landscape media query matches.

</details>

### Q56. What happens to the web tour state on logout?

- **A.** It's kept
- **B.** It's moved to localStorage
- **C.** It's saved to the server
- **D.** reset() is called, then the page reloads

<details><summary>Answer</summary>

**D.** reset() is called, then the page reloads

use-logout.ts resets the store and reloads the page.

</details>

### Q57. How often is the one-time MFA offer shown?

- **A.** Every login
- **B.** Once per day
- **C.** Never on web
- **D.** At most once per user per device, after a deposit, withdrawal or redemption, if MFA is off

<details><summary>Answer</summary>

**D.** At most once per user per device, after a deposit, withdrawal or redemption, if MFA is off

It's stored in localStorage as sq:mfa-prompt-seen:<userId>, with an in-memory fallback.

</details>

### Q58. When is the first_15_minutes shop discount hidden?

- **A.** After KYC
- **B.** After the tour
- **C.** Once it's bought, or once the account is more than 15 minutes old
- **D.** Never

<details><summary>Answer</summary>

**C.** Once it's bought, or once the account is more than 15 minutes old

checkShopPackage checks user.first15minutes and the account's age. There's no frontend constant for this value.

</details>

### Q59. How would you add a 'replay tour' button on web?

- **A.** Clear localStorage
- **B.** Log out and back in
- **C.** Call the casino FTUE store's activate()
- **D.** Call an API

<details><summary>Answer</summary>

**C.** Call the casino FTUE store's activate()

The store comment says a replay control only needs activate(). The cards controller accepts a manualLaunchToken instead.

</details>

### Q60. Is either tour (casino or cards) gated by a feature flag?

- **A.** Yes, feat-ftue
- **B.** Yes, an ops- flag
- **C.** No. No PostHog flag or env key gates either tour
- **D.** Only on mobile

<details><summary>Answer</summary>

**C.** No. No PostHog flag or env key gates either tour

If you add a new first-time experience, rolling it out behind a feat- or exp- flag is the suggested pattern.

</details>

## Lobby

### Q61. In casino terms, what is 'the lobby'?

- **A.** The home screen where players browse and launch games
- **B.** The admin dashboard
- **C.** The VIP area
- **D.** A chat room where players socialize

<details><summary>Answer</summary>

**A.** The home screen where players browse and launch games

It's a storefront and launcher. There's no chat and no friends feature.

</details>

### Q62. What drives the lobby's rows and tabs?

- **A.** Merchants
- **B.** Tags
- **C.** Groups (GET /apps/groups)
- **D.** Categories

<details><summary>Answer</summary>

**C.** Groups (GET /apps/groups)

Groups contain categories, and categories contain games. The lobby calls groups and merchants.

</details>

### Q63. Which call launches a game?

- **A.** GET /apps/play
- **B.** GET /apps/games/:id
- **C.** POST /casino/launch
- **D.** POST /apps/load/:gameId?currency=GC|FC

<details><summary>Answer</summary>

**D.** POST /apps/load/:gameId?currency=GC|FC

It returns { url, allow, reload, grantId }, and the client embeds the url.

</details>

### Q64. For which currency do the GeoComply and blocked-state middlewares run on /apps/load?

- **A.** FC (Sweeps) only
- **B.** GC only
- **C.** Both
- **D.** Neither

<details><summary>Answer</summary>

**A.** FC (Sweeps) only

Both middlewares skip when currency isn't FC.

</details>

### Q65. Which of these is NOT a game provider integration in the backend?

- **A.** Iconic21
- **B.** Paytech
- **C.** BGaming
- **D.** Alea

<details><summary>Answer</summary>

**B.** Paytech

Paytech is a payment provider. The game providers are Alea, Iconic21, BGaming, PeterSons and Sweepium.

</details>

### Q66. How do balance changes during play reach the client?

- **A.** The iframe posts the balance
- **B.** Push notification
- **C.** Polling GET /balance every second
- **D.** The socket 'balance' event to room usr<userId>, emitted after wallet callbacks

<details><summary>Answer</summary>

**D.** The socket 'balance' event to room usr<userId>, emitted after wallet callbacks

CommonWalletService.makeBalance updates atomically, then sends the balance over the socket.

</details>

### Q67. What does GET /apps/wins currently return?

- **A.** An empty array, because it returns early under a TODO
- **B.** Top wins of the day
- **C.** The last 10 wins
- **D.** A 404

<details><summary>Answer</summary>

**A.** An empty array, because it returns early under a TODO

Live wins come only from the socket 'recentWins' room.

</details>

### Q68. Which provider's game catalogue is synced by the daily cron?

- **A.** Alea only
- **B.** Sweepium only
- **C.** All providers
- **D.** None

<details><summary>Answer</summary>

**A.** Alea only

cronController only calls aleaService.syncGames(). The other syncGames methods have no caller.

</details>

### Q69. How long are lobby group results cached in Redis?

- **A.** 60 seconds, per state
- **B.** 10 minutes
- **C.** 5 seconds
- **D.** 24 hours

<details><summary>Answer</summary>

**A.** 60 seconds, per state

The key is group.<md5>.<state>, set with setex 60.

</details>

### Q70. What Origin header does the mobile game WebView send?

- **A.** The app's bundle id
- **B.** https://spinquest.com
- **C.** The API URL
- **D.** None

<details><summary>Answer</summary>

**B.** https://spinquest.com

GAME_WEBVIEW_HEADERS hard-codes Origin and Referer to look like the production web origin.

</details>

### Q71. How does the web client embed a game?

- **A.** A sandboxed iframe
- **B.** A new tab
- **C.** A Web Component
- **D.** An iframe with no sandbox attribute

<details><summary>Answer</summary>

**D.** An iframe with no sandbox attribute

<iframe src={url} allow={allow}> with no sandbox, which is listed as a risk.

</details>

### Q72. For Gold Coin launches, why don't the per-merchant state restrictions apply?

- **A.** They do apply
- **B.** Restrictions are a feature flag
- **C.** GC games have no merchants
- **D.** The geo middleware skips GC, so state is '' and getRestrictedMerchantIds('') returns nothing

<details><summary>Answer</summary>

**D.** The geo middleware skips GC, so state is '' and getRestrictedMerchantIds('') returns nothing

The game lists still filter by the guessed state, so this mainly affects direct links.

</details>

### Q73. What is the only social-ish element in the lobby?

- **A.** Player chat
- **B.** A live feed of other players' recent wins
- **C.** Friends list
- **D.** Multiplayer tables

<details><summary>Answer</summary>

**B.** A live feed of other players' recent wins

It's social proof over the socket. There's no chat or messaging.

</details>

### Q74. Which post-login prompts does the MOBILE lobby release when it gets focus?

- **A.** KYC and MFA
- **B.** Terms and privacy
- **C.** App rating, the pending push notification, and the queued push-permission prompt
- **D.** None

<details><summary>Answer</summary>

**C.** App rating, the pending push notification, and the queued push-permission prompt

It's the only post-login prompt queue in either client, and web has nothing equivalent.

</details>

### Q75. What does the cards product (PRODUCT=cards) refuse at game launch?

- **A.** Gold Coin launches (CurrencyNotAvailable)
- **B.** Sweeps Coin launches
- **C.** Mobile launches
- **D.** Nothing

<details><summary>Answer</summary>

**A.** Gold Coin launches (CurrencyNotAvailable)

Cards is sweeps-only and requires ALLOWED_STATES or the backend throws at boot.

</details>

### Q76. In what order does GuessStateMiddleware work out a visitor's state for the catalogue?

- **A.** The user's profile state only
- **B.** The geoToken cookie, then the cf-region-code header, then a MaxMind lookup on the IP
- **C.** The browser's geolocation API
- **D.** MaxMind first, then GeoComply

<details><summary>Answer</summary>

**B.** The geoToken cookie, then the cf-region-code header, then a MaxMind lookup on the IP

The guessed state filters the lists; the verified state is used at launch.

</details>

### Q77. Which conditions must hold for a game to appear in the lobby lists?

- **A.** enabled AND providerEnabled AND an enabled merchant AND not restricted for the guessed state
- **B.** Any game in the table
- **C.** enabled only
- **D.** providerEnabled only

<details><summary>Answer</summary>

**A.** enabled AND providerEnabled AND an enabled merchant AND not restricted for the guessed state

enabled is SpinQuest's own flag, providerEnabled is the vendor's flag, and merchant restrictions are per state.

</details>

### Q78. What does the RECENT_CATEGORY_ID category actually contain?

- **A.** Trending games
- **B.** Recent wins
- **C.** Each user's recently played games
- **D.** The 50 newest enabled games, rebuilt daily

<details><summary>Answer</summary>

**D.** The 50 newest enabled games, rebuilt daily

The name is misleading. Per-user recently played comes from /apps/games?recent=true.

</details>

### Q79. While a player is playing with Sweeps Coins, how often does the client re-check geolocation?

- **A.** Only at launch
- **B.** Every 5 minutes
- **C.** Every 30 seconds
- **D.** Never

<details><summary>Answer</summary>

**C.** Every 30 seconds

Both web and mobile do this. A failure sets geoBlocked and replaces the game with an error view.

</details>

### Q80. What does each provider service create when a game launches?

- **A.** A payment row
- **B.** A PostHog event only
- **C.** A session row in the database, a 30-minute Redis session hash, and an upserted 'recent' row
- **D.** Nothing

<details><summary>Answer</summary>

**C.** A session row in the database, a 30-minute Redis session hash, and an upserted 'recent' row

Vendor wallet callbacks then use that session token.

</details>

## Promotions and bonuses

### Q81. What happened to the promotion engine (the promotion schema with campaigns and claims)?

- **A.** It was dropped by the DropPromotionDomain migration
- **B.** It moved to Optimove
- **C.** It's live in Postgres
- **D.** It's behind a feature flag

<details><summary>Answer</summary>

**A.** It was dropped by the DropPromotionDomain migration

What's left is separate mechanisms: json_config rewards, shop discounts, AMOE, and admin grants.

</details>

### Q82. Where are reward amounts like the daily bonus and wheel configured?

- **A.** Rows in json_config
- **B.** Env vars
- **C.** PostHog
- **D.** Frontend constants

<details><summary>Answer</summary>

**A.** Rows in json_config

daily_bonus, login_streak, wheel_spin, push_notification_bonus and signup_bonus. The setters have no callers, so you edit the rows directly.

</details>

### Q83. Which recurring reward is fully implemented in BOTH clients?

- **A.** Login streak
- **B.** VIP level rewards
- **C.** Daily bonus
- **D.** Wheel spin

<details><summary>Answer</summary>

**C.** Daily bonus

The wheel and login streak exist only on the backend; neither client calls them.

</details>

### Q84. How much playthrough does a daily bonus claim add?

- **A.** 3x the sweeps amount
- **B.** 10x the gold amount
- **C.** 1x the sweeps amount
- **D.** None

<details><summary>Answer</summary>

**A.** 3x the sweeps amount

applyDailyBonus adds playThrough = 3 x diamonds credited.

</details>

### Q85. Which daily bonus claim route is a state-changing GET?

- **A.** GET /rewards/dailyBonus
- **B.** POST /rewards/dailyBonus/claim
- **C.** PUT /rewards
- **D.** GET /rewards/dailyBonus/claim

<details><summary>Answer</summary>

**D.** GET /rewards/dailyBonus/claim

It's the legacy 'claim all' route. POST is the newer per-tap route.

</details>

### Q86. Which of these is NOT a shop_package.discount value?

- **A.** one_time_offer_50k_gc
- **B.** first_15_minutes
- **C.** new_player_offer
- **D.** vip_tier_bonus

<details><summary>Answer</summary>

**D.** vip_tier_bonus

Only the first three exist. Each is hidden by a matching User boolean.

</details>

### Q87. What is AMOE, and what does an accepted entry credit?

- **A.** An admin goodwill grant
- **B.** A mail-in free entry ('no purchase necessary'), crediting 5M GC + 500 SC, hard-coded
- **C.** A VIP reward
- **D.** An affiliate payout of 10% revenue

<details><summary>Answer</summary>

**B.** A mail-in free entry ('no purchase necessary'), crediting 5M GC + 500 SC, hard-coded

AMOE (Alternative Method of Entry) is the legal free route to SC. The amounts are literals in AdminAmoeService.

</details>

### Q88. Why is the push-notification bonus probably never paid?

- **A.** It's behind an ops- flag
- **B.** Optimove blocks it
- **C.** The mobile app never sends pushNotifications: true to PUT /users
- **D.** Its json_config row is empty

<details><summary>Answer</summary>

**C.** The mobile app never sends pushNotifications: true to PUT /users

The backend credits it only when PUT /users flips pushNotifications on.

</details>

### Q89. Why can /rewards/* return 401 for a logged-in user?

- **A.** The rate limit was hit
- **B.** Terms weren't accepted
- **C.** Phone or email isn't confirmed (UserAuthService checks the URL prefix)
- **D.** Geo failed

<details><summary>Answer</summary>

**C.** Phone or email isn't confirmed (UserAuthService checks the URL prefix)

UnverifiedEmailPhoneError (401). An outdated-terms rejection is a 403, not a 401.

</details>

### Q90. How is the 500K giveaway (prizes, deadline) configured?

- **A.** Hard-coded constants, defined separately in both the web and mobile apps
- **B.** json_config
- **C.** A backend campaign table
- **D.** Optimove

<details><summary>Answer</summary>

**A.** Hard-coded constants, defined separately in both the web and mobile apps

A change needs two deploys, and the two copies can drift.

</details>

### Q91. What is POST /rewards/checkPromo?

- **A.** A mobile lobby ping (at most every 5 minutes) to a route that has never existed on the backend
- **B.** An Optimove webhook
- **C.** The web daily bonus status
- **D.** An admin promo tool

<details><summary>Answer</summary>

**A.** A mobile lobby ping (at most every 5 minutes) to a route that has never existed on the backend

It was added in mobile commit 87f69468 ('ping check promo, sale ribbon') and fails today.

</details>

### Q92. What does the VIP level endpoint return?

- **A.** A level computed from purchases
- **B.** Always vipLevel 0 (it's a stub)
- **C.** A 404
- **D.** The user's real tier

<details><summary>Answer</summary>

**B.** Always vipLevel 0 (it's a stub)

getUserVipLevel('1') ignores the id. The VIP club is static content.

</details>

### Q93. Which reward route lets a purchase flag skip its once-a-day limit?

- **A.** Login streak
- **B.** Wheel spin (purchase: true skips the daily check)
- **C.** AMOE
- **D.** Daily bonus

<details><summary>Answer</summary>

**B.** Wheel spin (purchase: true skips the daily check)

The free wheel spin is once per day using lastWheelSpin, and purchase: true bypasses it. No client calls the wheel today.

</details>

### Q94. Which statement about Gold Coins is true?

- **A.** Expire daily
- **B.** Only from AMOE
- **C.** Redeemable for cash
- **D.** Play money with no cash value, and can be bought

<details><summary>Answer</summary>

**D.** Play money with no cash value, and can be bought

Purchases are legally of Gold Coins. Sweeps Coins come with them as a free bonus.

</details>

### Q95. What are Sweeps Coins called in the code?

- **A.** credits
- **B.** tokens
- **C.** sweeps
- **D.** diamonds in the balance, and FC as the launch currency

<details><summary>Answer</summary>

**D.** diamonds in the balance, and FC as the launch currency

Balance.diamonds holds SC in cents; 1 SC = $1 at redemption.

</details>

### Q96. What makes the sweepstakes model 'no purchase necessary'?

- **A.** Redemption is optional
- **B.** Gold Coins are free
- **C.** KYC
- **D.** SC can be obtained free, including by mail-in AMOE, rather than bought

<details><summary>Answer</summary>

**D.** SC can be obtained free, including by mail-in AMOE, rather than bought

That's why AMOE is a legal invariant that's never put behind a flag. Legal status still varies by state.

</details>

### Q97. How do support staff give a player coins by hand?

- **A.** Through Optimove
- **B.** Edit the balance table
- **C.** POST /rewards/grant
- **D.** PUT /credit/:id on the admin players controller, with a subtype such as bonus_vip, good_will or promo

<details><summary>Answer</summary>

**D.** PUT /credit/:id on the admin players controller, with a subtype such as bonus_vip, good_will or promo

addUserCredit adds goldCoins and diamonds with a playthrough multiplier.

</details>

### Q98. How are free spins issued, and how do their wins appear?

- **A.** Through Optimove; as reward
- **B.** Via the wheel; as wheel_spin
- **C.** Support calls POST /admin/free-spins/issue (default 30-day expiry); wins come back as promo_win
- **D.** Automatically daily; as daily_bonus

<details><summary>Answer</summary>

**C.** Support calls POST /admin/free-spins/issue (default 30-day expiry); wins come back as promo_win

The player sees a FreeSpinDialog opened from a socket notification.

</details>

### Q99. What happens when a user tries to redeem affiliate commission with AFFILIATE_PAYOUT_ENABLED off?

- **A.** It succeeds
- **B.** It throws 'not implemented'
- **C.** It's queued
- **D.** It pays in Gold Coins

<details><summary>Answer</summary>

**B.** It throws 'not implemented'

The affiliate payout cron has been off since 2025-06-01, according to central-tech/TODO.md.

</details>

### Q100. Do the /rewards routes apply the GeoComply and blocked-state middleware?

- **A.** Yes
- **B.** Only for sweeps
- **C.** Only on mobile
- **D.** No. The decorator is commented out

<details><summary>Answer</summary>

**D.** No. The decorator is commented out

The shop routes apply them, so the two are inconsistent.

</details>

## Notifications

### Q101. Who actually sends push notifications to players' phones?

- **A.** The backend, through firebase-admin
- **B.** Sinch
- **C.** Expo Push Service
- **D.** Optimove (the Optimobile SDK), from campaigns set up in its console

<details><summary>Answer</summary>

**D.** Optimove (the Optimobile SDK), from campaigns set up in its console

The backend has no push sender. Campaigns live outside all the repos.

</details>

### Q102. Why does the backend's firebase_messaging token table never get rows from the current app?

- **A.** Web logins only
- **B.** The table was dropped
- **C.** Mobile sends deviceId and token, but the backend reads appDeviceId and fcmToken
- **D.** Tokens are encrypted

<details><summary>Answer</summary>

**C.** Mobile sends deviceId and token, but the backend reads appDeviceId and fcmToken

The upsert only runs when body.fcmToken is set, which it never is.

</details>

### Q103. What is the path of an in-app notification?

- **A.** Email -> app
- **B.** Polling GET /notification every 30 seconds
- **C.** notifications row -> Postgres trigger pg_notify -> DBEmitterService -> socket 'notification' -> bell list
- **D.** Optimove -> app

<details><summary>Answer</summary>

**C.** notifications row -> Postgres trigger pg_notify -> DBEmitterService -> socket 'notification' -> bell list

There's no polling. GET /notification runs only on page load.

</details>

### Q104. Which backend process runs the Postgres LISTEN for notifications?

- **A.** Only the one with API_TYPE=Fundist and FORK_ZERO=true
- **B.** The cron process
- **C.** A separate worker service
- **D.** Every process

<details><summary>Answer</summary>

**A.** Only the one with API_TYPE=Fundist and FORK_ZERO=true

Other processes insert rows but never emit them.

</details>

### Q105. In the mobile app, what priority does a push get if its payload doesn't set one?

- **A.** promotional
- **B.** gameplay
- **C.** critical
- **D.** engagement

<details><summary>Answer</summary>

**B.** gameplay

extractPriority falls back to 'gameplay'.

</details>

### Q106. With the app in the foreground, what happens to a 'promotional' push?

- **A.** Held until the lobby
- **B.** Suppressed
- **C.** Converted to email
- **D.** Shown

<details><summary>Answer</summary>

**B.** Suppressed

In the foreground only critical always shows. Gameplay is conditional; engagement and promotional are suppressed.

</details>

### Q107. What happens to a 'gameplay' push that arrives while the player is in a game?

- **A.** It's sent as SMS
- **B.** It's held as the pending notification (up to 60 minutes) and shown back at the lobby
- **C.** It's dropped
- **D.** It interrupts the game

<details><summary>Answer</summary>

**B.** It's held as the pending notification (up to 60 minutes) and shown back at the lobby

The lobby calls maybeShowPendingNotification() when it gets focus.

</details>

### Q108. When does the mobile app ask for push permission?

- **A.** At first launch
- **B.** After the lobby tour, through an app guard; it re-asks after 10 days, then every 60 days
- **C.** At signup
- **D.** Never

<details><summary>Answer</summary>

**B.** After the lobby tour, through an app guard; it re-asks after 10 days, then every 60 days

maybeShowNotificationPermissionPrompt waits for the tour, and there's a TODO to move the intervals to PostHog.

</details>

### Q109. Which in-app notification causes a visible reaction on both clients in practice?

- **A.** KYC success modal
- **B.** Purchase Failed modal
- **C.** The free-spins dialog
- **D.** Redemption Confirmed toast

<details><summary>Answer</summary>

**C.** The free-spins dialog

Several title matchers (for example 'Redemption Confirmed', 'Failed') don't match anything the backend sends.

</details>

### Q110. What does the web bell badge count?

- **A.** Today's notifications
- **B.** The total length of the list, read and unread
- **C.** Notifications marked important
- **D.** Unread notifications

<details><summary>Answer</summary>

**B.** The total length of the list, read and unread

Read rows stay until Clear All, which is a hard delete.

</details>

### Q111. What source does mobile PASSWORD login send?

- **A.** Hard-coded 'ios', even on Android
- **B.** 'mobile'
- **C.** 'web'
- **D.** Platform.OS

<details><summary>Answer</summary>

**A.** Hard-coded 'ios', even on Android

login-form.tsx uses AuthSource.IOS. Social login uses the real platform.

</details>

### Q112. Which channel carries redemption, KYC and AMOE status messages?

- **A.** Slack
- **B.** Optimove push
- **C.** In-app notifications (plus some emails)
- **D.** SMS

<details><summary>Answer</summary>

**C.** In-app notifications (plus some emails)

These are what Loc meant by the 'legacy in-app' channel. Slack is used only for internal alerts.

</details>

### Q113. Which mobile env var switches the Optimove SDK on?

- **A.** OPTIMOVE_API_KEY
- **B.** EXPO_PUBLIC_ENABLE_OPTIMOBILE (default false)
- **C.** ENABLE_POSTHOG
- **D.** ENABLE_PUSH

<details><summary>Answer</summary>

**B.** EXPO_PUBLIC_ENABLE_OPTIMOBILE (default false)

Every Optimove call is a no-op when it's off.

</details>

### Q114. What does the mobile app do with Optimove on logout?

- **A.** unregisterOptimovePush() and signOutOptimoveUser()
- **B.** Deletes the app
- **C.** Sends a goodbye push
- **D.** Nothing

<details><summary>Answer</summary>

**A.** unregisterOptimovePush() and signOutOptimoveUser()

On login it calls setOptimoveUserId and requests the push token if permission is granted.

</details>

### Q115. When a player taps a push, where does the app navigate?

- **A.** To the custom url in the payload (not Optimove's own notification.url), through parseAppUrl
- **B.** The shop
- **C.** Always the lobby
- **D.** The notifications list

<details><summary>Answer</summary>

**A.** To the custom url in the payload (not Optimove's own notification.url), through parseAppUrl

Optimove would take over its own url field when the app is closed.

</details>

### Q116. With the app in the background, which push priority is still suppressed?

- **A.** engagement
- **B.** critical
- **C.** gameplay
- **D.** promotional

<details><summary>Answer</summary>

**D.** promotional

In the background critical, gameplay and engagement show; only promotional is suppressed.

</details>

### Q117. How does the client mark an in-app notification as read?

- **A.** It's automatic after 24 hours
- **B.** Clear All only
- **C.** It emits notificationReceived over the socket, which soft-deletes a per-user row (sets receivedAt)
- **D.** PUT /notification/:id

<details><summary>Answer</summary>

**C.** It emits notificationReceived over the socket, which soft-deletes a per-user row (sets receivedAt)

There's no REST read route, and the socket handler doesn't check ownership.

</details>

### Q118. What does 'Clear All' in the bell do?

- **A.** Archives them
- **B.** DELETE /notification, which hard-deletes the user's own rows (global rows are untouched)
- **C.** Marks everything read
- **D.** Hides the list until next login

<details><summary>Answer</summary>

**B.** DELETE /notification, which hard-deletes the user's own rows (global rows are untouched)

There's no history afterwards.

</details>

### Q119. A notification is created while the player's socket is disconnected. When do they see it?

- **A.** Immediately on reconnect, through a replay
- **B.** Only on the next GET /notification (on page load)
- **C.** By email
- **D.** Never

<details><summary>Answer</summary>

**B.** Only on the next GET /notification (on page load)

The replay on 'auth' is commented out in UserService.

</details>

### Q120. Which in-app notification types does the DB listener emit live?

- **A.** Only 'popup'
- **B.** 'toast' rows, and rows that carry a command
- **C.** Only 'tray'
- **D.** All types

<details><summary>Answer</summary>

**B.** 'toast' rows, and rows that carry a command

'tray' rows, and 'popup' rows without a command, only show up on the next list fetch unless emitted directly.

</details>

## Payments

### Q121. Which purchase providers are live?

- **A.** Aeropay and Paytech
- **B.** Stripe and LinkMoney
- **C.** Crypto and Paytech
- **D.** Paytech and LinkMoney

<details><summary>Answer</summary>

**D.** Paytech and LinkMoney

Paytech handles card and Apple Pay; LinkMoney handles ACH. Aeropay is wired up but dead, and crypto isn't integrated.

</details>

### Q122. What actually credits coins after a purchase?

- **A.** A nightly cron
- **B.** The admin
- **C.** The vendor webhook calling addCoinsToBalance
- **D.** The browser's payment-success page

<details><summary>Answer</summary>

**C.** The vendor webhook calling addCoinsToBalance

The browser only polls the status. addCoinsToBalance is the only place purchase value is credited.

</details>

### Q123. What stops a repeated COMPLETED webhook from crediting twice?

- **A.** Vendor idempotency key
- **B.** Redis lock
- **C.** xtime being null, inside a SERIALIZABLE transaction
- **D.** Nothing

<details><summary>Answer</summary>

**C.** xtime being null, inside a SERIALIZABLE transaction

shouldProcessTx = state === 'COMPLETED' && !xtime, and xtime is set as part of crediting.

</details>

### Q124. What does POST /balance/shop/purchase/initiate return?

- **A.** A JWT
- **B.** An invoice PDF
- **C.** A sessionToken and a single-use paymentNonce, valid 30 minutes in Redis
- **D.** A Paytech redirect URL

<details><summary>Answer</summary>

**C.** A sessionToken and a single-use paymentNonce, valid 30 minutes in Redis

PaymentSessionService stores the userId, packageId, state and pixel for 1,800 seconds.

</details>

### Q125. How is the payment nonce consumed?

- **A.** By a webhook
- **B.** On logout
- **C.** Atomically with Redis GETDEL, just before the charge
- **D.** Never deleted

<details><summary>Answer</summary>

**C.** Atomically with Redis GETDEL, just before the charge

One session can start only one charge.

</details>

### Q126. Where does the purchase price come from?

- **A.** PostHog
- **B.** The client's query string
- **C.** The vendor
- **D.** The ShopPackage row in the database, re-read on the server

<details><summary>Answer</summary>

**D.** The ShopPackage row in the database, re-read on the server

The price and coin fields in the checkout URL are for display only.

</details>

### Q127. What is the default daily purchase cap?

- **A.** $500
- **B.** $5,000
- **C.** No cap
- **D.** $9,500 ($50,000 if the limit is lifted)

<details><summary>Answer</summary>

**D.** $9,500 ($50,000 if the limit is lifted)

maxPurchasePerDay = 9500_00, even though a stale comment says $5k. It's checked at creation but incremented at credit, so parallel checkouts can exceed it.

</details>

### Q128. How is the Paytech webhook verified?

- **A.** IP allow-list in code
- **B.** mTLS
- **C.** Not at all
- **D.** HMAC-SHA256 of the raw body with PAYTECH_WEBHOOK_KEY, compared to the signature header

<details><summary>Answer</summary>

**D.** HMAC-SHA256 of the raw body with PAYTECH_WEBHOOK_KEY, compared to the signature header

The compare uses !== rather than a constant-time compare. A mismatch is dropped silently, but the response is still 200.

</details>

### Q129. How is the LinkMoney webhook authenticated?

- **A.** OAuth
- **B.** HMAC with LINKMONEY_WEBHOOK_KEY
- **C.** A shared secret in the URL
- **D.** It isn't. There's no auth and no signature check

<details><summary>Answer</summary>

**D.** It isn't. There's no auth and no signature check

LINKMONEY_WEBHOOK_KEY exists but nothing reads it. This is the top risk to raise privately.

</details>

### Q130. At which LinkMoney state are coins credited?

- **A.** COMPLETED
- **B.** SCHEDULED
- **C.** DISBURSED
- **D.** AUTHORIZED, before ACH settles

<details><summary>Answer</summary>

**D.** AUTHORIZED, before ACH settles

A later payment.failed only overwrites the state. No code takes the coins back.

</details>

### Q131. Which provider pays out redemptions?

- **A.** Paytech only
- **B.** LinkMoney
- **C.** Aeropay
- **D.** Crypto wallet

<details><summary>Answer</summary>

**A.** Paytech only

Admin approval throws 'No Payment Solution' for anything other than Paytech.

</details>

### Q132. What happens to a bank (ACH) redemption request?

- **A.** Waits in CHECKOUT (with a Slack alert) until support approves it with PUT /admin/payment/:id
- **B.** Rejected
- **C.** Paid instantly
- **D.** Auto-approved by cron

<details><summary>Answer</summary>

**A.** Waits in CHECKOUT (with a Slack alert) until support approves it with PUT /admin/payment/:id

Approving flips the ledger row to 'withdraw' and queues the Paytech payout.

</details>

### Q133. What is required before a user can redeem to a card?

- **A.** VIP level 1
- **B.** At least one earlier redemption that COMPLETED
- **C.** Nothing extra
- **D.** A purchase in the last 30 days

<details><summary>Answer</summary>

**B.** At least one earlier redemption that COMPLETED

Card is marked availableAfterFirstRedemption, so the first payout has to be by bank.

</details>

### Q134. How is redeemable SC calculated?

- **A.** goldCoins / 100
- **B.** A stored redeemable column
- **C.** diamonds
- **D.** floor(diamonds - playThrough)

<details><summary>Answer</summary>

**D.** floor(diamonds - playThrough)

There's no separate column. The playthrough subtraction is applied atomically in the debit UPDATE.

</details>

### Q135. What are the minimum redemption and the frequency limit?

- **A.** 1 SC, hourly
- **B.** 10 SC, unlimited
- **C.** 50 SC; once per calendar day and at least 6 hours apart
- **D.** 100 SC, weekly

<details><summary>Answer</summary>

**C.** 50 SC; once per calendar day and at least 6 hours apart

Bank is 50-5,000 SC and card is 50-500 SC. The day boundary uses TIMEZONE.

</details>

### Q136. What happens to the player's SC when a payout fails or is declined?

- **A.** Held for 30 days
- **B.** Converted to GC
- **C.** Lost
- **D.** rollbackClaim credits it back and sends a rejection email

<details><summary>Answer</summary>

**D.** rollbackClaim credits it back and sends a rejection email

Without a transition guard, a DECLINED arriving after COMPLETED could also trigger a refund.

</details>

### Q137. How does the mobile app take payments?

- **A.** A native Paytech SDK
- **B.** In-app purchases through the App Store
- **C.** It initiates the session natively, then loads the WEB checkout page in a WebView
- **D.** It opens Safari

<details><summary>Answer</summary>

**C.** It initiates the session natively, then loads the WEB checkout page in a WebView

A web checkout regression breaks mobile purchases too.

</details>

### Q138. Where do mobile's /balance/shop/purchase/session/:token/... routes come from?

- **A.** Paytech
- **B.** Central payment-service
- **C.** An unmerged March 2026 backend branch. Only dead native code calls them
- **D.** Backend PeterSons

<details><summary>Answer</summary>

**C.** An unmerged March 2026 backend branch. Only dead native code calls them

Commits f978e089, 780bb6f8 and 28661110 aren't in PeterSons, and BillingDetailsModal is never rendered.

</details>

### Q139. Why do clients call redemption-rate routes that the backend doesn't have?

- **A.** Planned feature
- **B.** Leftovers from a removed crypto redemption. The failed call keeps crypto hidden
- **C.** A typo
- **D.** They're served by Optimove

<details><summary>Answer</summary>

**B.** Leftovers from a removed crypto redemption. The failed call keeps crypto hidden

Web calls /redemption/rate and mobile calls /redemptionRate; neither exists on the backend.

</details>

### Q140. Where are bank routing and account numbers stored for ACH redemptions?

- **A.** Only at Paytech
- **B.** In plain text in payment.transaction.parentPaymentId
- **C.** Not stored
- **D.** In the vault, encrypted

<details><summary>Answer</summary>

**B.** In plain text in payment.transaction.parentPaymentId

It's stored as '<routing>:<account>:<addressId>' in a varchar column, and listed as a risk.

</details>
