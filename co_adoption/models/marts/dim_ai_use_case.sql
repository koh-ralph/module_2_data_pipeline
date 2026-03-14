with staging as (
    select * from {{ ref('stg_ai_adoption') }}
)

select distinct
    {{ dbt_utils.generate_surrogate_key(['ai_use_case']) }} as use_case_key,
    ai_use_case as use_case_name
from staging
where ai_use_case is not null