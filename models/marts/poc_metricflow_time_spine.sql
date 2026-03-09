{{
    config(
        materialized = 'view'
    )
}}

select
    full_date as date_day
from {{ source('semantic_poc', 'sem_poc_dim_date') }}