-- models/staging/stg_ai_adoption.sql
with raw_data as (
    select * from {{ ref('ai_company_adoption') }}
)

select
    -- Primary Key
    cast(response_id as INT64) as response_id,
    
    -- Company Info
    upper(company_id) as company_id,
    country,
    region,
    industry,
    company_size,
    cast(num_employees as INT64) as num_employees,
    cast(annual_revenue_usd_millions as FLOAT64) as annual_revenue_usd_millions,
    
    -- AI Details
    ai_adoption_stage,
    ai_primary_tool,
    ai_use_case,
    cast(ai_budget_percentage as FLOAT64) as ai_budget_percentage,
    
    -- Survey Metadata
    survey_year,
    quarter,
    survey_source,
    data_collection_method,

    -- Metrics for Fact Table
    cast(jobs_displaced as INT64) as jobs_displaced,
    cast(jobs_created as INT64) as jobs_created,
    cast(revenue_growth_percent as FLOAT64) as revenue_growth_percent

from raw_data