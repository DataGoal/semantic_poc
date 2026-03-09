{{
    config(
        materialized = 'view'
    )
}}

with spine as (
    select
        full_date as date_day
    from {{ source('semantic_poc', 'sem_poc_dim_date') }}
)

select date_day from spine
