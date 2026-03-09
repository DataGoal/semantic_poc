# dbt Semantic Layer POC — Retail Sales Metrics

Replicates the Databricks Metric View (Retail Sales) using the **dbt Semantic Layer** powered by MetricFlow.

---

## Project Structure

```
dbt_semantic_poc/
├── dbt_project.yml                     # Project config
├── packages.yml                        # dbt packages (dbt_utils)
├── macros/
│   └── generate_schema_name.sql        # Forces models into existing schema
├── models/
│   ├── staging/
│   │   ├── _sources.yml                # Source definitions for all tables
│   │   ├── stg_fact_sales.sql          # Fact staging (filter + derived cols)
│   │   ├── stg_dim_store.sql           # Store dimension staging
│   │   ├── stg_dim_product.sql         # Product dimension staging
│   │   └── stg_dim_customer.sql        # Customer dimension staging
│   ├── marts/
│   │   ├── _marts_models.yml           # Time spine config
│   │   └── metricflow_time_spine.sql   # Time spine for cumulative metrics
│   └── semantic_layer/
│       ├── sem_fact_sales.yml          # Semantic model: fact + measures
│       ├── sem_dim_store.yml           # Semantic model: store dimension
│       ├── sem_dim_product.yml         # Semantic model: product dimension
│       ├── sem_dim_customer.yml        # Semantic model: customer dimension
│       ├── sem_metrics_sales.yml       # All metric definitions
│       └── sem_saved_queries.yml       # Pre-built saved queries
└── README.md
```

---

## Databricks → dbt Semantic Layer Mapping

| Databricks Concept         | dbt Semantic Layer Equivalent            |
|---------------------------|------------------------------------------|
| `source` + `filter`       | dbt source + staging model with WHERE    |
| `joins` (star schema)     | Entities with foreign keys (MetricFlow auto-joins) |
| `dimensions`              | Dimensions in semantic model             |
| `measures` (atomic)       | Measures with `create_metric: true`      |
| `MEASURE()` composition   | Derived metrics (`type: derived`)        |
| `FILTER (WHERE ...)`      | Simple metric with `filter` clause       |
| `window: trailing N day`  | Cumulative metric with `window: N days`  |
| `window: cumulative`      | Cumulative metric (no window = all time) |
| `window: current/YTD`     | Cumulative metric with `grain_to_date`   |
| Period-over-period         | Derived metric with `offset_window`      |
| Ratio measures             | Ratio metrics (`type: ratio`)            |

---

## Prerequisites

- **dbt Cloud** account (Starter, Team, or Enterprise)
- **Databricks** connection configured in dbt Cloud
- Existing schema: `development.dev_cf_ebi_semantic_poc` with all `sem_poc_*` tables populated
- dbt Core **v1.6+** (semantic layer supported); recommend **v1.8+** for `create_metric` and `offset_window`

---

## Deployment Steps

### 1. Clone into dbt Cloud

Push this project to a GitHub repo, then connect it in dbt Cloud:

1. Create a new GitHub repository and push this folder as the root
2. In dbt Cloud → **Settings** → **Repository** → connect your GitHub repo
3. Set the **Project subdirectory** to `/` (or wherever `dbt_project.yml` lives)

### 2. Configure Connection Profile

In dbt Cloud → **Settings** → **Connection**, ensure your Databricks profile has:

- **Catalog**: `development`
- **Schema**: `dev_cf_ebi_semantic_poc`

This ensures models and views are created in the existing schema.

### 3. Install Packages

In the dbt Cloud IDE terminal:

```bash
dbt deps
```

### 4. Build Models

```bash
# Parse and validate all YAML
dbt parse

# Build staging views and time spine
dbt build
```

### 5. Validate Semantic Layer

```bash
# Validate all semantic models and metrics
dbt sl validate

# List all available metrics
dbt sl list metrics

# List all available dimensions
dbt sl list dimensions --metrics total_net_revenue

# List all available entities
dbt sl list entities
```

### 6. Query Metrics

Use the `dbt sl query` command in the dbt Cloud IDE:

```bash
# ── Basic: Total net revenue by month ──
dbt sl query \
  --metrics total_net_revenue \
  --group-by "TimeDimension('transaction__transaction_date', 'month')"

# ── By region and category ──
dbt sl query \
  --metrics total_net_revenue,transaction_count,avg_order_value \
  --group-by "TimeDimension('transaction__transaction_date', 'month')" \
  --group-by "Dimension('store__region_name')" \
  --group-by "Dimension('product__category_name')"

# ── Gross margin % by division ──
dbt sl query \
  --metrics gross_margin,gross_margin_pct \
  --group-by "TimeDimension('transaction__transaction_date', 'quarter')" \
  --group-by "Dimension('product__division_name')"

# ── Discount rate and return rate ──
dbt sl query \
  --metrics discount_rate,return_rate \
  --group-by "TimeDimension('transaction__transaction_date', 'month')"

# ── Trailing 7-day revenue ──
dbt sl query \
  --metrics trailing_7d_revenue \
  --group-by "TimeDimension('transaction__transaction_date', 'day')"

# ── Cumulative (running total) revenue ──
dbt sl query \
  --metrics cumulative_revenue \
  --group-by "TimeDimension('transaction__transaction_date', 'day')"

# ── Year-to-date revenue by month ──
dbt sl query \
  --metrics ytd_revenue \
  --group-by "TimeDimension('transaction__transaction_date', 'month')"

# ── Day-over-day growth ──
dbt sl query \
  --metrics day_over_day_revenue_growth \
  --group-by "TimeDimension('transaction__transaction_date', 'day')"

# ── Revenue by customer segment (cross-model join) ──
dbt sl query \
  --metrics total_net_revenue,unique_customers \
  --group-by "Dimension('customer__customer_segment')" \
  --group-by "Dimension('customer__loyalty_tier')"

# ── Revenue by revenue tier (fact-level dimension) ──
dbt sl query \
  --metrics total_net_revenue,transaction_count \
  --group-by "Dimension('transaction__revenue_tier')"

# ── Execute a saved query ──
dbt sl query --saved-query daily_sales_summary
```

---

## Metrics Reference

### Simple Metrics (auto-created from measures)

| Metric               | Aggregation      | Description                    |
|----------------------|------------------|--------------------------------|
| total_net_revenue    | SUM              | Net revenue in USD             |
| total_gross_revenue  | SUM              | Gross revenue before discounts |
| total_cogs           | SUM              | Cost of goods sold             |
| total_discount       | SUM              | Discount amount                |
| total_quantity        | SUM              | Units sold                     |
| transaction_count    | COUNT_DISTINCT   | Distinct transactions          |
| unique_customers     | COUNT_DISTINCT   | Distinct customers             |

### Filtered Metric

| Metric               | Type   | Description                          |
|----------------------|--------|--------------------------------------|
| return_transactions  | simple | Transactions where return_flag = 'Y' |

### Derived / Ratio Metrics

| Metric               | Type    | Expression                           |
|----------------------|---------|--------------------------------------|
| gross_margin         | derived | revenue - cogs                       |
| gross_margin_pct     | derived | (revenue - cogs) / revenue * 100     |
| avg_order_value      | derived | revenue / transaction_count          |
| avg_selling_price    | derived | revenue / total_quantity             |
| discount_rate        | ratio   | total_discount / total_gross_revenue |
| return_rate          | ratio   | return_transactions / transaction_count |
| day_over_day_revenue_growth | derived | (current - prior_day) / prior_day * 100 |

### Cumulative / Window Metrics

| Metric                | Window         | Description                    |
|-----------------------|----------------|--------------------------------|
| trailing_7d_revenue   | 7 days         | Rolling 7-day net revenue      |
| trailing_7d_customers | 7 days         | Rolling 7-day unique customers |
| cumulative_revenue    | all time       | Running total net revenue      |
| ytd_revenue           | grain_to_date: year | Year-to-date net revenue  |

---

## Available Dimensions for Slicing

Dimensions are accessible across joined semantic models:

- **From Fact**: `transaction_date`, `revenue_tier`, `return_flag`, `currency_code`
- **From Store**: `store_name`, `store_format`, `region_name`, `country_name`, `state_province_name`, `city`
- **From Product**: `division_name`, `category_name`, `subcategory_name`, `product_name`, `gender_target`, `age_group`, `sport_occasion`
- **From Customer**: `gender_code`, `loyalty_tier`, `customer_segment`, `preferred_sport`, `lifetime_value_band`, `acquisition_channel`

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Schema does not exist` | Verify `generate_schema_name` macro is present and returns the existing schema |
| `Semantic manifest empty` | Ensure all YAML files are under `models/` path |
| `No time spine found` | Check `metricflow_time_spine` model and its YAML config in `_marts_models.yml` |
| `Entity join not found` | Verify entity names match exactly across fact and dimension semantic models |
| `dbt sl` commands not available | Ensure you are on dbt Cloud (not Core free) with Semantic Layer enabled |
| Duplicate model names | Each `.sql` file must have a unique name; staging prefix `stg_` avoids conflicts |

---

## Notes

- The `generate_schema_name` macro overrides the default dbt behavior to use the schema specified in `dbt_project.yml` directly, avoiding `CREATE SCHEMA` calls.
- `create_metric: true` on measures auto-generates simple metrics, reducing boilerplate.
- Cross-model joins are handled automatically by MetricFlow based on matching entity names (e.g., `store`, `product`, `customer`).
- The time spine model (`metricflow_time_spine`) is required for cumulative and window-based metrics to function.
