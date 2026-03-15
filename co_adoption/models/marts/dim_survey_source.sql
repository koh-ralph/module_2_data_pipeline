with staging as (
    select * from {{ ref('stg_ai_adoption') }}
)

select distinct
    {{ dbt_utils.generate_surrogate_key(['survey_source', 'data_collection_method']) }} as survey_source_key,
    survey_source,
    data_collection_method
from staging