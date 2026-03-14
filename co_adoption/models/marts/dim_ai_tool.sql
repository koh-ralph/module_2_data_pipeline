with staging as (
    select * from {{ ref('stg_ai_adoption') }}
)

select distinct
    {{ dbt_utils.generate_surrogate_key(['ai_primary_tool']) }} as tool_key,
    ai_primary_tool as tool_name
from staging
where ai_primary_tool is not null