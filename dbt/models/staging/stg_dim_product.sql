select * from {{ source('semantic_poc', 'sem_poc_dim_product') }}
