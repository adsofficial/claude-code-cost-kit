# Data: SQL, EF Core, Cosmos DB, Databricks

## Safety first (all data work)
- Never run write, delete, schema-change or large-scan queries against production. Use local, dev, emulator or a sandbox workspace. Ask if unsure which environment a connection points to.
- All schema changes through versioned migrations; include a rollback plan.
- No real customer data or PII copied into tests, notebooks, logs or prompts.

## SQL Server / Azure SQL (and EF Core)
- Parameterized queries or stored procedures only.
- Check indexes for new `WHERE`/`JOIN`/`ORDER BY` columns; look at the execution plan for slow queries.
- Avoid `SELECT *`; paginate with keyset (seek) pagination for large tables.
- EF Core: projections with `Select`, `AsNoTracking()` for reads, `AsSplitQuery()` for wide includes, migrations via `dotnet ef migrations add`.
- Large updates in batches to avoid long locks; note any change that needs a maintenance window.

## Azure Cosmos DB
- Choose the partition key from the main query pattern; avoid hot partitions and cross-partition queries on hot paths.
- Point reads (`id` + partition key) are cheapest; queries cost more RU/s. Keep documents small and model for reads.
- Custom indexing policy: exclude paths you never query.
- Use the SDK's parameterized `QueryDefinition`; handle 429 (rate limit) with the SDK's retry settings.
- Use the Cosmos DB emulator for integration tests.

## Databricks / PySpark / Delta Lake
- Code in repos (Databricks Repos / asset bundles), not only in workspace notebooks; secrets via secret scopes.
- Prefer DataFrame API / Spark SQL over Python UDFs; avoid `collect()` on large data.
- Watch shuffles and skew; partition/Z-order (or liquid clustering) Delta tables on common filters.
- Idempotent jobs: `MERGE` for upserts, write to Delta with schema enforcement.
- Unit-test transformations with a local SparkSession on small DataFrames.
- Right-size clusters and use job clusters with auto-termination; never leave all-purpose clusters running.

## Security
- Least-privilege identities (managed identity / service principal), Unity Catalog permissions, no shared admin credentials.
- Mask or tokenize PII in lower environments.
