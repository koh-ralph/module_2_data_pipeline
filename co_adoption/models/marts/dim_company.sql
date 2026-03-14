with staging as (
    select * from {{ ref('stg_ai_adoption') }}
)

select distinct
    {{ dbt_utils.generate_surrogate_key(['company_id']) }} as company_key,
    company_id,
    industry,
    company_size,
    country,
    region
from staging