# SQ-1097 Spec: Index payment transactions by player

Nov 18, 2026 · @Ian Greenough

## Overview

Add an index on `payment.transaction("userId")` so per-player payment reads stop scanning the whole table. The change is two files: one decorator on the entity and one migration. Ticket: [SQ-1097](https://linear.app/social-gaming-room/issue/SQ-1097/payments-index-payment-transactions-by-player).

**Why it matters:** these all read the full table today: `/users/history/withdraws` (twice per request), `/users/history/deposits`, `/balance/shop/redemptionHistory`, the Aeropay `xtime` count, `hasCompletedRedemption`, and the admin `userTransactionSummary`. A benchmark on 20M rows took 0.5–1.2 s per query without the index and 0.4–1.8 ms with it.

**Out of scope:** `createdAt` range reads (stats, the Optimove ETL).

**Done when:**

- `transaction_userId_ikey` exists on `payment.transaction`, built with `CONCURRENTLY`
- `pnpm db:migrate`, `pnpm db:generate --check` and `pnpm db:revert` all pass
- `EXPLAIN ANALYZE` on a `userId` query shows `Index Scan using transaction_userId_ikey`
- The PR includes production numbers from before the change and the query plan
- After deploy, production `idx_scan` rises and `seq_scan` stops growing

## Step 0: Branch

Your local `PeterSons` is the default branch and is 4 commits behind origin. The working tree is clean.

- [ ] Pull and create the branch Linear suggests

```bash
git pull
git checkout -b sq-1097-payments-index-payment-transactions-by-player
```

## Step 1: Measure production first

These queries only read. Their results give the PR a "before" picture and a baseline to compare against after deploy.

- [ ] Ask Danek how you get read access to the production database
- [ ] Run the table stats and save the output

```sql
SELECT n_live_tup, seq_scan, seq_tup_read, idx_scan
FROM pg_stat_user_tables
WHERE schemaname = 'payment' AND relname = 'transaction';
```

- [ ] Run the slow-query list and save the output

```sql
SELECT calls, mean_exec_time, total_exec_time, query
FROM pg_stat_statements
WHERE query ILIKE '%payment%transaction%'
ORDER BY total_exec_time DESC
LIMIT 10;
```

A high `seq_scan` count with a large `seq_tup_read` confirms that the table is being read in full.

## Step 2: Entity change

File: `src/db/entity/Payment/PaymentTransaction.ts`. The `userId` column (around line 95) has no index today. `Index` is already imported.

- [ ] Add a bare `@Index()` to `userId`, the same way `paymentId` has one

```typescript
@Column({ type: 'bigint' })
@Index()
userId!: string
```

The index doesn't need a name. `src/db/naming-strategy.ts` builds index names as `<table>_<columns>_ikey`, which gives `transaction_userId_ikey`. That's how `paymentId` got `transaction_paymentId_ikey`.

**Name that looks like a clash:** `GeoComplyTransaction` already has an index named `transaction_userId_ikey`. It's in the `geocomply` schema, and Postgres only needs index names to be unique within a schema, so it's fine. Mention it in the PR so reviewers don't stop on it.

## Step 3: Migration file

Create a new file in `src/db/migration/`. Model it on `1782900300000-singular-emission-index.ts`: it has the cleanest structure and the comment style reviewers expect.

- [ ] Name the file `<timestamp>-payment-transaction-user-index.ts`. Use a timestamp later than the newest migration, `1793840625000-payment-transaction-application-type.ts`; running `Date.now()` works.
- [ ] Set the class name and `name` field to match, e.g. `PaymentTransactionUserIndex<timestamp>`
- [ ] Set `transaction = false`. `CREATE INDEX CONCURRENTLY` can't run inside a transaction, and `dataSource.ts` sets `migrationsTransactionMode: 'each'`.
- [ ] Write the header comment: what the index is for, why `transaction = false`, and that the build doesn't lock the table
- [ ] In `up`, build the index concurrently and keep the recovery note about INVALID indexes
- [ ] In `down`, drop it concurrently (see below for why)

Shape to aim for:

```typescript
export class PaymentTransactionUserIndex<timestamp> implements MigrationInterface {
  name = 'PaymentTransactionUserIndex<timestamp>'
  transaction = false

  async up(queryRunner: QueryRunner): Promise<void> {
    // Recovery note: a failed CONCURRENTLY build leaves an INVALID index that
    // IF NOT EXISTS would then skip. On a failed deploy:
    //   SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
    // then DROP INDEX CONCURRENTLY "payment"."transaction_userId_ikey" and re-run.
    await queryRunner.query(`
      CREATE INDEX CONCURRENTLY IF NOT EXISTS "transaction_userId_ikey"
        ON "payment"."transaction" ("userId")
    `)
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX CONCURRENTLY IF EXISTS "payment"."transaction_userId_ikey"
    `)
  }
}
```

**Where this departs from the examples:** the earlier migrations use a plain `DROP INDEX` in `down` because their tables were empty. `payment.transaction` is large and busy, and a plain drop briefly takes a lock that blocks every read and write on the table. `DROP INDEX CONCURRENTLY` avoids that. Say so in a comment.

## Step 4: Local verification

These are the same checks CI runs in `.github/workflows/test.yaml`. Run them against your local database and save the output for the PR.

- [ ] `pnpm db:migrate` applies the new migration
- [ ] `pnpm db:generate --check` reports no changes. If it wants to generate a migration, the entity and the migration disagree, usually on the index name.
- [ ] `pnpm db:revert` works. CI runs this too, so `down` must succeed.
- [ ] `pnpm db:migrate` again, to leave the index in place
- [ ] Check that the index is used:

```sql
SET enable_seqscan = off;  -- local table is tiny; without this Postgres may skip the index
EXPLAIN ANALYZE
SELECT * FROM payment.transaction WHERE "userId" = '<some user id>';
```

Expect `Index Scan using transaction_userId_ikey`. Say in the PR that you turned off `enable_seqscan` and why.

- [ ] Run `pnpm test` (plus lint, if you have it set up locally)

## Step 5: Open the PR

- [ ] Ask Claude to review both files against this spec before you push
- [ ] Commit, push, and open the PR using `pull_request_template.md`
- [ ] Title: `perf(SQ-1097): index payment transactions by user id`
- [ ] **Summary:** what the index is for, the ticket link, Type `perf`, Feature flags `none`
- [ ] **AI disclosure:** say that Claude helped plan and review, and that you wrote and checked the code
- [ ] **Design & risk notes:**
  - The index is built with `CONCURRENTLY`, so the table isn't locked; `transaction = false` is required
  - `down` also drops `CONCURRENTLY`, unlike earlier examples, because the table is busy
  - The `transaction_userId_ikey` name also exists in the `geocomply` schema; no clash
  - `createdAt` range reads are out of scope
  - Recovery if the build fails: drop the INVALID index, then re-run
- [ ] **Testing evidence:** the production numbers from Step 1, the check output, and the `EXPLAIN ANALYZE` plan
- [ ] Tick the guidelines checkbox in the template

## Step 6: After deploy

- [ ] Make sure the index is valid. This query should return no rows:

```sql
SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
```

- [ ] After a day of traffic, run the Step 1 queries again. `idx_scan` should climb, `seq_scan` should stop growing, and the history and redemption queries should drop off the slow list.
- [ ] Post the before and after numbers on SQ-1097 and let Danek know how it went

## Differences between this spec and the implementation

The rest of this spec is left as originally written. Add these to the PR description under Design & risk notes.

| # | Spec said | Implementation | Why |
| --- | --- | --- | --- |
| 1 | Step 3: `down` uses `DROP INDEX CONCURRENTLY` | `down` uses a plain `DROP INDEX IF EXISTS` | TypeORM 0.3.21's `migration:revert` always wraps `down()` in a transaction and ignores `transaction = false` (`MigrationExecutor.js`, `undoLastMigration`). Postgres rejects `CONCURRENTLY` inside a transaction (error `25001`), so `pnpm db:revert` failed locally and would have failed in CI. Trade-off: the drop briefly locks `payment.transaction`, so run any revert off-peak. |
| 2 | Step 3: the newest migration is `1793840625000-payment-transaction-application-type.ts` | Timestamp `1795022701002` | `1794868563991-merch-order-shopify-name.ts` landed after the spec was written. The new timestamp is later than both. |
| 3 | Step 1: measure production with `pg_stat_user_tables` and `pg_stat_statements` before the change | Skipped | Danek (Slack, Nov 18, 9:24 AM): no one on the team has production database access, and the ticket's projection already justifies the index. Step 6's production re-check can't be done without that access either; Sawyer can run it if he wants it. |
| 4 | Step 5: AI disclosure says Claude helped plan and review, and Ian wrote the code | Claude also drafted the migration's class skeleton and header comment, and ran lint and the type check | The disclosure should match what happened. |
| 5 | Step 3: `up` uses `CREATE INDEX CONCURRENTLY IF NOT EXISTS` with a manual recovery note | `up` runs `DROP INDEX CONCURRENTLY IF EXISTS`, then `CREATE INDEX CONCURRENTLY` | review-crew finding FAIL-1: after a failed build, `IF NOT EXISTS` would skip the INVALID index on a re-run, and TypeORM would record the migration as applied with an index the planner never uses. |
| 6 | Step 5: PR title type `perf` | `chore` | review-crew finding CI-1: the repo's `lint-pr` check doesn't allow `perf`, although the PR template lists it. |
