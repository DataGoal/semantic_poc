{{
  config(
    materialized='view',
    schema='dev_cf_ebi_semantic_poc'
  )
}}

select *
from {{ source('semantic_poc', 'sem_poc_dim_customer') }}
