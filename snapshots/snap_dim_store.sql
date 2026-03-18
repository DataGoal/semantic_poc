{% snapshot snap_dim_store %}

{{
  config(
    target_schema='dev_cf_ebi_semantic_poc',
    unique_key='store_sk',
    strategy='check',
    check_cols=['store_name', 'store_format', 'region_name', 'country_name',
                'state_province_name', 'city', 'is_active'],
    invalidate_hard_deletes=True
  )
}}

select
  store_sk,
  store_nk,
  store_name,
  store_type,
  region_code,
  region_name,
  country_code,
  country_name,
  state_province_code,
  state_province_name,
  metro_market,
  city,
  store_address,
  postal_code,
  latitude,
  longitude,
  square_footage,
  num_floors,
  store_format,
  channel_type,
  is_digital,
  open_date_sk,
  close_date_sk,
  is_active,
  store_manager_employee_sk,
  ownership_model,
  partner_account_id,
  created_timestamp
from {{ source('semantic_poc', 'sem_poc_dim_store') }}

{% endsnapshot %}
