{{
  config(
    materialized='view',
    schema='dev_cf_ebi_semantic_poc'
  )
}}

/*
  SCD-aware fact model: joins sales transactions to the correct
  *version* of the product dimension based on effective/expiry dates.

  MetricFlow cannot natively resolve time-versioned joins, so we
  handle it here in the dbt model layer and expose a flattened
  result to the semantic model.
*/

with sales as (
    select *
    from {{ ref('stg_fact_sales') }}
),

product_scd as (
    select *
    from {{ ref('stg_dim_product') }}
    where effective_date is not null
)

select
    s.transaction_sk,
    s.transaction_id,
    s.line_number,
    s.transaction_date,
    s.transaction_year,
    s.customer_sk,
    s.store_sk,
    s.quantity_sold,
    s.unit_retail_price,
    s.unit_cost_price,
    s.gross_revenue,
    s.discount_amount,
    s.net_revenue,
    s.net_revenue_usd,
    s.cost_of_goods_sold,
    s.return_flag,
    s.currency_code,
    s.revenue_tier,

    -- Product attributes as-of transaction date (SCD Type 2 resolved)
    p.product_sk        as product_sk,
    p.product_nk        as product_version_nk,
    p.product_name      as product_name_at_sale,
    p.division_name     as division_name_at_sale,
    p.category_name     as category_name_at_sale,
    p.subcategory_name  as subcategory_name_at_sale,
    p.standard_cost     as standard_cost_at_sale,
    p.standard_retail_price as standard_retail_price_at_sale,
    p.gender_target     as gender_target_at_sale,
    p.sport_occasion    as sport_occasion_at_sale,
    p.is_current_flag   as product_is_current

from sales s
inner join product_scd p
    on  s.product_sk = p.product_sk
    and s.transaction_date >= p.effective_date
    and (s.transaction_date < p.expiry_date or p.expiry_date is null)
