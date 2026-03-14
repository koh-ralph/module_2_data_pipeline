with staging as (
    select * from {{ ref('stg_ai_adoption') }}
)

select
    response_id,
    -- Foreign Keys for the Dimensions
    {{ dbt_utils.generate_surrogate_key(['company_id']) }} as company_key,
    {{ dbt_utils.generate_surrogate_key(['ai_adoption_stage']) }} as adoption_stage_key,
    {{ dbt_utils.generate_surrogate_key(['ai_primary_tool']) }} as tool_key,
    {{ dbt_utils.generate_surrogate_key(['ai_use_case']) }} as use_case_key,
    {{ dbt_utils.generate_surrogate_key(['survey_source', 'data_collection_method']) }} as survey_source_key,
    {{ dbt_utils.generate_surrogate_key(['survey_year', 'quarter']) }} as date_key,
    
    -- Metrics
    num_employees,
    annual_revenue_usd_millions,
    
    -- Derived Columns
    -- 1. Total AI Budget (Revenue * Budget %)
    (annual_revenue_usd_millions * (ai_budget_percentage / 100)) as total_ai_budget_millions,
    
    -- 2. Net Job Impact (Created - Displaced)
    (jobs_created - jobs_displaced) as net_job_impact,
    
    -- 3. Revenue Growth Amount
    (annual_revenue_usd_millions * (revenue_growth_percent / 100)) as revenue_growth_usd_millions

from staging