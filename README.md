# dbt Semantic Layer POC — Retail Sales Metrics

Replicates the Databricks Metric View for retail sales using the **dbt Semantic Layer** (MetricFlow).

---

## Project Structure

```
dbt_semantic_poc/
├── dbt_project.yml                    # Project configuration
├── packages.yml                       # Package dependencies (none required)
├── macros/
│   └── generate_schema_name.sql       # Forces exact schema (no prefix)
├── models/
│   ├── sources/
│   │   └── _sources.yml               # Source definitions (existing tables)
│   ├── staging/
│   │   ├── stg_fact_sales.sql         # Fact staging + derived columns
│   │   ├── stg_dim_store.sql          # Store dimension staging
│   │   ├── stg_dim_product.sql        # Product dimension staging
│   │   ├── stg_dim_customer.sql       # Customer dimension staging
│   │   ├── mf_time_spine_day.sql      # Time spine (refs existing table)
│   │   └── _staging_models.yml        # Model configs + time spine setup
│   └── semantic/
│       ├── _sem_sales.yml             # Semantic model: sales fact
│       ├── _sem_dimensions.yml        # Semantic models: store, product, customer
│       └── _metrics_sales.yml         # All metric definitions
└── README.md
```

---

## Prerequisites

| Requirement | Detail |
|---|---|
| dbt Cloud plan | Team or Enterprise (Semantic Layer requires this) |
| dbt version | 1.6+ (MetricFlow included) |
| Data platform | Databricks |
| Catalog / Schema | `development.dev_cf_ebi_semantic_poc` |
| Time spine table | `development.dev_cf_ebi_semantic_poc.metricflow_time_spine` (pre-existing, column: `date_day`) |

---

## Deployment Steps

### 1. Push to GitHub

```bash
cd dbt_semantic_poc
git init
git add .
git commit -m "Initial commit: dbt Semantic Layer POC"
git remote add origin <YOUR_GITHUB_REPO_URL>
git push -u origin main
```

### 2. Connect to dbt Cloud

1. In dbt Cloud → **Account Settings** → **Projects** → **New Project**.
2. Connect the GitHub repository you just pushed.
3. Set the **Project subdirectory** to `/` (or the path to `dbt_project.yml`).

### 3. Configure the Connection (Profile)

In the dbt Cloud **Environment** settings:

| Setting | Value |
|---|---|
| Adapter | Databricks |
| Catalog | `development` |
| Schema | `dev_cf_ebi_semantic_poc` |
| Host | Your Databricks SQL Warehouse host |
| HTTP Path | Your SQL Warehouse HTTP path |

> **Important**: The target schema must be `dev_cf_ebi_semantic_poc`. The custom `generate_schema_name` macro ensures dbt writes all views into this exact schema without prepending a prefix.

### 4. Run dbt build

In the **dbt Cloud IDE** or a **Job**, execute:

```bash
# Parse and validate the project (generates semantic manifest)
dbt parse

# Build all staging views (required before querying metrics)
dbt build
```

This creates the staging views in `development.dev_cf_ebi_semantic_poc`:
- `stg_fact_sales`
- `stg_dim_store`
- `stg_dim_product`
- `stg_dim_customer`
- `mf_time_spine_day`

### 5. Enable the Semantic Layer

1. Go to **Account Settings** → **Projects** → your project → **Semantic Layer**.
2. Set the **Environment** to a deployment environment.
3. Create a **Service Token** with Semantic Layer permissions.
4. Deploy a dbt job at least once to publish the semantic manifest.

---

## Querying Metrics

### Option A: dbt Cloud IDE (`dbt sl` commands)

```bash
# ── Simple metrics ──────────────────────────────────────────────
# Total net revenue by month
dbt sl query --metrics total_net_revenue --group-by metric_time__month --order-by metric_time__month

# Total net revenue by region
dbt sl query --metrics total_net_revenue --group-by store__region_name --order-by store__region_name

# Transaction count and unique customers by product category
dbt sl query --metrics transaction_count,unique_customers --group-by product__category_name --order-by product__category_name

# Return transactions
dbt sl query --metrics return_transactions --group-by metric_time__month

# ── Derived metrics ─────────────────────────────────────────────
# Gross margin and gross margin % by region
dbt sl query --metrics gross_margin,gross_margin_pct --group-by store__region_name

# Average order value by store format
dbt sl query --metrics avg_order_value --group-by store__store_format

# Discount rate by product division
dbt sl query --metrics discount_rate --group-by product__division_name

# Return rate by month
dbt sl query --metrics return_rate --group-by metric_time__month --order-by metric_time__month

# ── Cumulative / Window metrics ─────────────────────────────────
# Trailing 7-day revenue by day
dbt sl query --metrics trailing_7d_revenue --group-by metric_time__day --order-by metric_time__day

# YTD revenue by month
dbt sl query --metrics ytd_revenue --group-by metric_time__month --order-by metric_time__month

# Cumulative (all-time) revenue by day
dbt sl query --metrics cumulative_revenue --group-by metric_time__day --order-by metric_time__day

# Day-over-day growth
dbt sl query --metrics day_over_day_revenue_growth --group-by metric_time__day --order-by metric_time__day

# ── Multi-metric + filter ──────────────────────────────────────
# Revenue and margin for a specific country
dbt sl query --metrics total_net_revenue,gross_margin_pct --group-by store__country_name,metric_time__quarter --where "{{ Dimension('store__country_name') }} = 'United States'"
```

### Option B: SQL in Databricks (after dbt exports)

Once the semantic manifest is deployed, you can also query via **dbt Semantic Layer SQL** from connected BI tools (Tableau, Hex, Google Sheets, etc.) or export saved queries using `dbt sl export`.

---

## Databricks ↔ dbt Mapping Reference

| Databricks Metric View Concept | dbt Semantic Layer Equivalent |
|---|---|
| `source` (fact table) | `sources` → staging model → `semantic_model.model: ref(...)` |
| `joins` (star schema) | `entities` (primary + foreign keys across semantic models) |
| `dimensions` | `dimensions` (categorical or time) |
| `measures` (SUM, COUNT) | `measures` in semantic model + `type: simple` metrics |
| `MEASURE()` composability | `type: derived` metrics with `expr` |
| `FILTER (WHERE ...)` | `filter:` on simple metric using Jinja `{{ Dimension(...) }}` |
| `window: trailing N day` | `type: cumulative` with `window: N days` |
| `window: cumulative` | `type: cumulative` (no window = all time) |
| `window: current + range` (YTD) | `type: cumulative` with `grain_to_date: year` |
| Period-over-period (DoD) | `type: derived` with `offset_window` on input metrics |
| `display_name` | `label` on metric |
| `synonyms` | Not natively supported; document in `description` |
| `format` (currency, %) | Applied in BI tool layer; document expected format in `description` |

---

## Troubleshooting

| Issue | Resolution |
|---|---|
| `Schema creation failed` | Verify the `generate_schema_name` macro is present and target schema is `dev_cf_ebi_semantic_poc` |
| `Duplicate model name` | All model names are unique with `stg_` prefix for staging |
| `Time spine not found` | Confirm `mf_time_spine_day` is built and `_staging_models.yml` has the `time_spine` config |
| `Semantic manifest not found` | Run `dbt parse` or `dbt build` first to generate the manifest |
| `Metric not queryable` | Ensure a deployment job has run successfully; Semantic Layer reads from the deployed manifest |
| `Entity join not working` | Check that entity names match across semantic models (e.g., `store` in both fact and dim) |
