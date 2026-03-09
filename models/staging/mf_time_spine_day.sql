{{
  config(
    materialized='view',
    schema='dev_cf_ebi_semantic_poc'
  )
}}

select
  date_day
from {{ source('semantic_poc', 'metricflow_time_spine') }}
