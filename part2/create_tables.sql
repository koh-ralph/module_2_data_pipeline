-- ============================================================
-- create_tables.sql
-- BigQuery DDL — AI Company Adoption Star Schema
--
-- YOUR project  : ntu-data-science-488111  (you have full access here)
-- Raw data      : ntu-big-data.AI_Company_Adoption.AI_company_adoption_dataset
--                 (classmate's project — read-only access)
-- DW layer      : ntu-data-science-488111.dw  (created below in YOUR project)
--
-- IMPORTANT: Make sure you are logged in as ntu-data-science-488111
--            in the BigQuery console before running this script.
-- ============================================================


-- ── 0. Create the dw dataset in YOUR project ────────────────
CREATE SCHEMA IF NOT EXISTS `ntu-data-science-488111.dw`
OPTIONS (location = 'US');


-- ============================================================
-- DIMENSION TABLES
-- ============================================================


-- ── DimDate ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ntu-data-science-488111.dw.DimDate` (
    date_key        INT64   NOT NULL,   -- e.g., 20230101
    survey_year     INT64   NOT NULL,   -- 2023, 2024, 2025, 2026
    quarter         STRING  NOT NULL,   -- Q1, Q2, Q3, Q4
    year_quarter    STRING  NOT NULL,   -- "2023-Q1"
    half_year       STRING  NOT NULL,   -- H1 or H2
    is_latest_year  BOOL    NOT NULL,   -- flag for current-year filtering
    PRIMARY KEY (date_key) NOT ENFORCED
);

-- Seed all quarters 2023–2026
INSERT INTO `ntu-data-science-488111.dw.DimDate`
    (date_key, survey_year, quarter, year_quarter, half_year, is_latest_year)
VALUES
    (20230101, 2023, 'Q1', '2023-Q1', 'H1', FALSE),
    (20230401, 2023, 'Q2', '2023-Q2', 'H1', FALSE),
    (20230701, 2023, 'Q3', '2023-Q3', 'H2', FALSE),
    (20231001, 2023, 'Q4', '2023-Q4', 'H2', FALSE),
    (20240101, 2024, 'Q1', '2024-Q1', 'H1', FALSE),
    (20240401, 2024, 'Q2', '2024-Q2', 'H1', FALSE),
    (20240701, 2024, 'Q3', '2024-Q3', 'H2', FALSE),
    (20241001, 2024, 'Q4', '2024-Q4', 'H2', FALSE),
    (20250101, 2025, 'Q1', '2025-Q1', 'H1', FALSE),
    (20250401, 2025, 'Q2', '2025-Q2', 'H1', FALSE),
    (20250701, 2025, 'Q3', '2025-Q3', 'H2', FALSE),
    (20251001, 2025, 'Q4', '2025-Q4', 'H2', FALSE),
    (20260101, 2026, 'Q1', '2026-Q1', 'H1', TRUE),
    (20260401, 2026, 'Q2', '2026-Q2', 'H1', TRUE),
    (20260701, 2026, 'Q3', '2026-Q3', 'H2', TRUE),
    (20261001, 2026, 'Q4', '2026-Q4', 'H2', TRUE);


-- ── DimCompany ──────────────────────────────────────────────
-- Populated by dbt from `ntu-big-data.AI_Company_Adoption.AI_company_adoption_dataset` (one row per company_id)
CREATE TABLE IF NOT EXISTS `ntu-data-science-488111.dw.DimCompany` (
    company_key                 INT64   NOT NULL,
    company_id                  STRING  NOT NULL,   -- "COMP-00001"
    country                     STRING,
    region                      STRING,
    industry                    STRING,
    company_size                STRING,             -- Startup / SME / Enterprise
    num_employees               INT64,
    annual_revenue_usd_millions FLOAT64,
    revenue_band                STRING,             -- "<10M" / "10-100M" / ">100M"
    company_founding_year       INT64,
    company_age                 INT64,              -- snapshot from first survey
    company_age_group           STRING,             -- "6-15 years" / "16-30 years" / "30+ years"
    PRIMARY KEY (company_key) NOT ENFORCED
);


-- ── DimAITool ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ntu-data-science-488111.dw.DimAITool` (
    ai_tool_key          INT64  NOT NULL,
    ai_primary_tool      STRING NOT NULL,
    tool_vendor_category STRING,
    PRIMARY KEY (ai_tool_key) NOT ENFORCED
);

INSERT INTO `ntu-data-science-488111.dw.DimAITool`
    (ai_tool_key, ai_primary_tool, tool_vendor_category)
VALUES
    (1, 'ChatGPT',            'OpenAI'),
    (2, 'GitHub Copilot',     'GitHub/Microsoft'),
    (3, 'Claude',             'Anthropic'),
    (4, 'Gemini',             'Google'),
    (5, 'Custom Internal AI', 'Internal'),
    (6, 'Other',              'Other');


-- ── DimAIUseCase ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ntu-data-science-488111.dw.DimAIUseCase` (
    usecase_key      INT64  NOT NULL,
    ai_use_case      STRING NOT NULL,
    usecase_category STRING,
    PRIMARY KEY (usecase_key) NOT ENFORCED
);

INSERT INTO `ntu-data-science-488111.dw.DimAIUseCase`
    (usecase_key, ai_use_case, usecase_category)
VALUES
    (1, 'Customer Support',       'Customer-Facing'),
    (2, 'Marketing Automation',   'Customer-Facing'),
    (3, 'HR Automation',          'Internal Operations'),
    (4, 'Software Development',   'Engineering'),
    (5, 'Fraud Detection',        'Risk & Compliance'),
    (6, 'Predictive Maintenance', 'Engineering');


-- ── DimAIAdoptionStage ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ntu-data-science-488111.dw.DimAIAdoptionStage` (
    stage_key      INT64  NOT NULL,
    adoption_stage STRING NOT NULL,
    stage_order    INT64,             -- 1=pilot, 2=partial, 3=full
    stage_label    STRING,
    PRIMARY KEY (stage_key) NOT ENFORCED
);

INSERT INTO `ntu-data-science-488111.dw.DimAIAdoptionStage`
    (stage_key, adoption_stage, stage_order, stage_label)
VALUES
    (1, 'pilot',   1, 'Early Pilot'),
    (2, 'partial', 2, 'Partial Rollout'),
    (3, 'full',    3, 'Full Deployment');


-- ── DimSurveySource ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `ntu-data-science-488111.dw.DimSurveySource` (
    source_key             INT64  NOT NULL,
    survey_source          STRING NOT NULL,
    data_collection_method STRING,
    PRIMARY KEY (source_key) NOT ENFORCED
);

INSERT INTO `ntu-data-science-488111.dw.DimSurveySource`
    (source_key, survey_source, data_collection_method)
VALUES
    (1, 'WEF Survey',                'API Scrape'),
    (2, 'McKinsey Report',           'Phone Interview'),
    (3, 'Internal Corporate Survey', 'Online Survey'),
    (4, 'LinkedIn Poll',             'Research Compilation');


-- ============================================================
-- FACT TABLE
-- ============================================================

-- ── FactAISurvey ────────────────────────────────────────────
-- Grain: one row per survey response (company × quarter)
-- Populated by dbt from `ntu-big-data.AI_Company_Adoption.AI_company_adoption_dataset`
CREATE TABLE IF NOT EXISTS `ntu-data-science-488111.dw.FactAISurvey` (

    -- Keys
    survey_key                    INT64   NOT NULL,   -- surrogate key
    response_id                   INT64   NOT NULL,   -- natural key from CSV

    -- Foreign keys → dimension tables
    company_key                   INT64   NOT NULL,   -- → DimCompany
    date_key                      INT64   NOT NULL,   -- → DimDate
    ai_tool_key                   INT64   NOT NULL,   -- → DimAITool
    usecase_key                   INT64   NOT NULL,   -- → DimAIUseCase
    stage_key                     INT64   NOT NULL,   -- → DimAIAdoptionStage
    source_key                    INT64   NOT NULL,   -- → DimSurveySource

    -- AI adoption metrics
    ai_adoption_rate              FLOAT64,            -- % workflows using AI
    years_using_ai                INT64,
    num_ai_tools_used             INT64,              -- Q8
    ai_projects_active            INT64,              -- Q9
    ai_maturity_score             FLOAT64,
    ai_failure_rate               FLOAT64,
    ai_budget_percentage          FLOAT64,
    ai_investment_per_employee    FLOAT64,
    ai_training_hours             FLOAT64,

    -- Governance snapshot (time-varying, stored in fact)
    regulatory_compliance_score   FLOAT64,
    data_privacy_level            STRING,
    ai_ethics_committee           BOOL,
    ai_risk_management_score      FLOAT64,

    -- Workforce
    remote_work_percentage        FLOAT64,
    employee_satisfaction_score   FLOAT64,
    task_automation_rate          FLOAT64,           -- Q10
    time_saved_per_week           FLOAT64,

    -- ── Business outcome measures ────────────────────────────
    -- Q1 Economic Impact
    revenue_growth_percent        FLOAT64,           -- Q12
    cost_reduction_percent        FLOAT64,

    -- Q2 Productivity
    productivity_change_percent   FLOAT64,           -- Q11

    -- Q3 Jobs
    jobs_displaced                INT64,             -- Q13
    jobs_created                  INT64,             -- Q14
    reskilled_employees           INT64,

    -- Supporting metrics
    innovation_score              FLOAT64,
    customer_satisfaction         FLOAT64,

    -- Derived columns (computed by dbt)
    net_jobs_change               INT64,             -- jobs_created - jobs_displaced
    company_age_at_survey         INT64,             -- survey_year - founding_year
    ai_roi_index                  FLOAT64,           -- (revenue_growth + cost_reduction) / ai_budget_pct
    productivity_efficiency_score FLOAT64,           -- (productivity_change * task_automation_rate) / 100

    -- ── Keys & Relationships (NOT ENFORCED — BigQuery analytics warehouse) ──
    -- NOTE: BigQuery does not reject bad data, but these declarations document
    --       the relationships and help the query optimizer.
    PRIMARY KEY (survey_key) NOT ENFORCED,
    FOREIGN KEY (company_key)  REFERENCES `ntu-data-science-488111.dw.DimCompany`       (company_key)  NOT ENFORCED,
    FOREIGN KEY (date_key)     REFERENCES `ntu-data-science-488111.dw.DimDate`           (date_key)     NOT ENFORCED,
    FOREIGN KEY (ai_tool_key)  REFERENCES `ntu-data-science-488111.dw.DimAITool`         (ai_tool_key)  NOT ENFORCED,
    FOREIGN KEY (usecase_key)  REFERENCES `ntu-data-science-488111.dw.DimAIUseCase`      (usecase_key)  NOT ENFORCED,
    FOREIGN KEY (stage_key)    REFERENCES `ntu-data-science-488111.dw.DimAIAdoptionStage`(stage_key)    NOT ENFORCED,
    FOREIGN KEY (source_key)   REFERENCES `ntu-data-science-488111.dw.DimSurveySource`   (source_key)   NOT ENFORCED
);


-- ============================================================
-- VERIFICATION QUERIES
-- Run these after dbt populates the tables to confirm counts
-- ============================================================

-- Check all tables exist and row counts
SELECT 'DimDate'            AS table_name, COUNT(*) AS row_count FROM `ntu-data-science-488111.dw.DimDate`
UNION ALL
SELECT 'DimCompany',                        COUNT(*) FROM `ntu-data-science-488111.dw.DimCompany`
UNION ALL
SELECT 'DimAITool',                         COUNT(*) FROM `ntu-data-science-488111.dw.DimAITool`
UNION ALL
SELECT 'DimAIUseCase',                      COUNT(*) FROM `ntu-data-science-488111.dw.DimAIUseCase`
UNION ALL
SELECT 'DimAIAdoptionStage',                COUNT(*) FROM `ntu-data-science-488111.dw.DimAIAdoptionStage`
UNION ALL
SELECT 'DimSurveySource',                   COUNT(*) FROM `ntu-data-science-488111.dw.DimSurveySource`
UNION ALL
SELECT 'FactAISurvey',                      COUNT(*) FROM `ntu-data-science-488111.dw.FactAISurvey`
ORDER BY table_name;
