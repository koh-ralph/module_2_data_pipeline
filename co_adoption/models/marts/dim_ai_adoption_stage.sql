with staging as (
    select * from {{ ref('stg_ai_adoption') }}
)

select distinct
    {{ dbt_utils.generate_surrogate_key(['ai_adoption_stage']) }} as adoption_stage_key,
    ai_adoption_stage as adoption_stage_name
from staging
where ai_adoption_stage is not null