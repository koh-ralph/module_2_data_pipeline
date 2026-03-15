with staging as (
    select * from {{ ref('stg_ai_adoption') }}
)

select distinct
    {{ dbt_utils.generate_surrogate_key(['survey_year', 'quarter']) }} as date_key,
    survey_year,
    quarter,
    -- Simple concatenation for a readable label (e.g., "2023-Q1")
    concat(cast(survey_year as string), '-', quarter) as year_quarter_label
from staging