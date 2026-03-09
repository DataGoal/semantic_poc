with source as (
    select * from {{ source('semantic_poc', 'sem_poc_fact_sales_transactions') }}
    where transaction_date_sk is not null
)

select
    transaction_sk,
    transaction_id,
    line_number,
    transaction_date_sk,
    customer_sk,
    product_sk,
    store_sk,
    channel_sk,
    promotion_sk,
    employee_sk,
    quantity_sold,
    unit_retail_price,
    unit_cost_price,
    gross_revenue,
    discount_amount,
    net_revenue,
    tax_amount,
    total_transaction_amount,
    cost_of_goods_sold,
    gross_margin,
    gross_margin_pct,
    return_flag,
    currency_code,
    exchange_rate,
    net_revenue_usd,
    -- Derived date columns for semantic layer
    to_date(cast(transaction_date_sk as string), 'yyyyMMdd') as transaction_date,
    date_trunc('year', to_date(cast(transaction_date_sk as string), 'yyyyMMdd')) as transaction_year,
    -- Revenue tier classification
    case
        when net_revenue_usd > 500 then 'High-Value'
        when net_revenue_usd > 100 then 'Mid-Value'
        else 'Low-Value'
    end as revenue_tier,
    load_timestamp,
    source_system
from source
