# group-project

# Part 2
# Data Warehouse Design — Project Documentation
**Project:** AI Company Adoption Analytics
**Role:** Data Warehouse Designer (Phase 2)
**Dataset:** `ntu-big-data.AI_Company_Adoption.AI_company_adoption_dataset`
**Warehouse:** `ntu-data-science-488111.dw`
**Tooling:** BigQuery + dbt

---

## Table of Contents
1. [Business Questions — What Are We Trying to Answer?](#1-business-questions)
2. [Data Source](#2-data-source)
3. [Why Star Schema Was Selected](#3-why-star-schema)
4. [Schema Design — Tables and Relationships](#4-schema-design)
5. [How the Code Was Created](#5-how-the-code-was-created)
6. [How Each Table Answers the Business Questions](#6-how-each-table-answers-the-business-questions)
7. [Sample SQL Queries for Each Business Question](#7-sample-sql-queries)
8. [Assumptions and Design Decisions](#8-assumptions-and-design-decisions)
9. [Limitations](#9-limitations)
10. [Handoff Checklist for ELT Engineer (Phase 3)](#10-handoff-checklist)

---

## 1. Business Questions

The entire data warehouse was designed to answer these three questions:

### Q1 — Economic Impact: Did AI help companies earn more revenue?

> *"What is the average revenue growth of companies that adopted AI, broken down by industry, company size, and AI adoption stage?"*

**How the schema answers it:**
- `FactAISurvey.revenue_growth_percent` — the direct measure of revenue growth
- `FactAISurvey.cost_reduction_percent` — supporting economic measure
- `FactAISurvey.ai_roi_index` — derived: (revenue growth + cost reduction) / AI budget spent
- Join to `DimCompany` → filter/group by **industry**, **company size**, **region**
- Join to `DimAIAdoptionStage` → compare **pilot vs partial vs full** deployment
- Join to `DimDate` → track growth **year over year**

**Example insight this enables:**
> "Finance companies in Full Deployment stage averaged 18% revenue growth vs 6% for companies still in Pilot stage."

---

### Q2 — Productivity Change: Did AI make employees more productive?

> *"How has employee productivity changed after AI adoption, and which AI tools or use cases drive the biggest improvement?"*

**How the schema answers it:**
- `FactAISurvey.productivity_change_percent` — direct productivity measure
- `FactAISurvey.task_automation_rate` — % of tasks now automated by AI
- `FactAISurvey.time_saved_per_week` — hours saved per employee per week
- `FactAISurvey.productivity_efficiency_score` — derived: productivity × automation / 100
- Join to `DimAITool` → compare **which AI tool** gave the best results
- Join to `DimAIUseCase` → compare **which use case** (Customer Support, HR, etc.)
- Join to `DimDate` → see if productivity **improved over time**

**Example insight this enables:**
> "Companies using GitHub Copilot for Software Development saved an average of 12 hours per employee per week."

---

### Q3 — Jobs Created / Lost: What was the employment impact of AI?

> *"Did AI adoption create new jobs or displace existing ones, and does the answer change by company size or region?"*

**How the schema answers it:**
- `FactAISurvey.jobs_displaced` — jobs lost due to AI automation
- `FactAISurvey.jobs_created` — new jobs created because of AI
- `FactAISurvey.reskilled_employees` — staff retrained for new AI-related roles
- `FactAISurvey.net_jobs_change` — derived: jobs_created − jobs_displaced
- Join to `DimCompany` → break down by **region**, **company size**, **industry**
- Join to `DimAIAdoptionStage` → does job impact increase at Full Deployment?
- Join to `DimDate` → is the employment impact getting better or worse over time?

**Example insight this enables:**
> "Large enterprises displaced 3× more jobs than startups, but also created 2× more new AI-related roles."

---

## 2. Data Source

| Item | Detail |
|---|---|
| **Source project** | `ntu-big-data` (classmate's Google Cloud project) |
| **Dataset** | `AI_Company_Adoption` |
| **Table** | `AI_company_adoption_dataset` |
| **Size** | ~150,000 rows, 42 columns |
| **Coverage** | Survey responses from companies across multiple countries, industries, and years (2023–2026) |
| **Access** | Read-only from `ntu-data-science-488111` via cross-project BigQuery query |

### Key columns in the raw CSV

| Column | Type | Used For |
|---|---|---|
| `response_id` | INT64 | Unique row identifier |
| `company_id` | STRING | Links to DimCompany |
| `survey_year` + `quarter` | INT64 + STRING | Links to DimDate |
| `industry`, `country`, `region` | STRING | Goes into DimCompany |
| `ai_primary_tool` | STRING | Links to DimAITool |
| `ai_use_case` | STRING | Links to DimAIUseCase |
| `ai_adoption_stage` | STRING | Links to DimAIAdoptionStage |
| `survey_source` | STRING | Links to DimSurveySource |
| `revenue_growth_percent` | FLOAT64 | Q1 answer |
| `productivity_change_percent` | FLOAT64 | Q2 answer |
| `jobs_displaced`, `jobs_created` | INT64 | Q3 answer |

---

## 3. Why Star Schema Was Selected

### What is a Star Schema?
A star schema organises data into **one central Fact table** (containing numbers/measures) surrounded by **Dimension tables** (containing descriptive context). When drawn on paper, it looks like a star — hence the name.

```
        DimDate
           |
DimCompany — FactAISurvey — DimAITool
           |
      DimAIUseCase
```

### Why Star Schema and NOT Snowflake Schema?

A **Snowflake Schema** further splits dimension tables into sub-tables (e.g., separating Country out of DimCompany into its own table). This sounds cleaner but adds more JOINs.

| Decision Criteria | Star Schema ✅ | Snowflake Schema ❌ |
|---|---|---|
| **Query simplicity** | 1 JOIN per dimension — easy for analysts | 2–3 JOINs per dimension — harder to write |
| **BigQuery cost** | Fewer bytes scanned = lower cost | More JOINs = more bytes scanned |
| **Dimension size** | All dims < 10,000 rows — no storage saving from splitting | Splitting only saves storage for very large dims |
| **dbt readability** | One model per dimension, small and focused | More models, harder to maintain |
| **BI tool compatibility** | Most BI tools (Looker, Tableau) work best with star | Some BI tools struggle with snowflake JOINs |
| **Analytical flexibility** | One `SELECT … FROM FactAISurvey JOIN …` answers all 3 Qs | Requires nested JOINs to answer the same question |

### Why NOT a Flat (Single) Table?
We could have put everything in one table. We did not because:
- **Repeated data:** Company name, industry, country would repeat in every row → wastes storage
- **Hard to update:** If a company changes industry, you would need to update thousands of rows
- **Slow GROUP BY:** BigQuery scans the whole column — a small DimCompany lookup is much faster

---

## 4. Schema Design — Tables and Relationships

### Overview Diagram

```
                    ┌─────────────────────┐
                    │      DimDate        │
                    │─────────────────────│
                    │ PK date_key         │
                    │    survey_year      │
                    │    quarter          │
                    │    year_quarter     │
                    └──────────┬──────────┘
                               │ 1
                               │
 ┌──────────────────┐          │           ┌────────────────────┐
 │   DimCompany     │          │           │    DimAITool       │
 │──────────────────│    N     │     N     │────────────────────│
 │ PK company_key   ├──────────┤──────────┤ PK ai_tool_key     │
 │    company_id    │          │           │    ai_primary_tool │
 │    industry      │   ┌──────┴───────┐  └────────────────────┘
 │    country       │   │ FactAISurvey │
 │    num_employees │   │──────────────│  ┌────────────────────┐
 │    company_size  │   │ PK survey_key│  │   DimAIUseCase     │
 └──────────────────┘   │ FK company_key──┤ PK usecase_key     │
                        │ FK date_key  │  │    ai_use_case     │
 ┌──────────────────┐   │ FK tool_key  │  └────────────────────┘
 │ DimAIAdoptionStg │   │ FK usecase_k │
 │──────────────────│   │ FK stage_key │  ┌────────────────────┐
 │ PK stage_key     ├───┤ FK source_key│  │  DimSurveySource   │
 │    adoption_stage│   │  ...measures.│  │ PK source_key      │
 │    stage_order   │   └──────────────┘  │    survey_source   │
 └──────────────────┘                     └────────────────────┘
```

### Table Summary

| Table | Type | Rows | Populated By | Purpose |
|---|---|---|---|---|
| `DimDate` | Dimension | 16 | SQL seed | Time — WHEN |
| `DimCompany` | Dimension | ~thousands | dbt | Company profile — WHO |
| `DimAITool` | Dimension | 6 | SQL seed | AI tool — WHAT tool |
| `DimAIUseCase` | Dimension | 6 | SQL seed | Use case — WHAT for |
| `DimAIAdoptionStage` | Dimension | 3 | SQL seed | Adoption level — HOW FAR |
| `DimSurveySource` | Dimension | 4 | SQL seed | Data origin — WHERE FROM |
| `FactAISurvey` | Fact | ~150,000 | dbt | All measures — the numbers |

### Key Design Choices

| Decision | Reason |
|---|---|
| `ai_adoption_stage` is its own dimension table | It has a natural ORDER (pilot → partial → full) captured in `stage_order` column — enables sorted charts |
| `company_age` stored in `DimCompany` AND `company_age_at_survey` derived in fact | Static snapshot in dim; time-accurate calculation in fact |
| Governance scores (compliance, risk) stored in fact | They change every quarter — time-varying, not static company attributes |
| `net_jobs_change`, `ai_roi_index`, `productivity_efficiency_score` as derived columns | Calculated by dbt at load time — avoids repeated calculation in every query |

---

## 5. How the Code Was Created

### Step 1 — Understand the Raw Data
Examined the CSV schema (42 columns) to identify:
- Which columns describe **context** (WHO, WHAT, WHEN) → become Dimension tables
- Which columns are **measurements** (numbers, percentages) → go into the Fact table
- Which columns are **categorical with low cardinality** (few unique values) → good candidates for dimension tables

### Step 2 — Design the Star Schema on Draw.io
Grouped columns into 6 dimensions + 1 fact based on:
- **Grain decision:** One row per survey response (company × quarter)
- **Foreign key mapping:** Each dimension gets a surrogate INT64 key
- **Business question mapping:** Confirmed all 3 questions can be answered with JOINs

### Step 3 — Write the DDL (`create_tables.sql`)
Created BigQuery DDL in this order:
1. `CREATE SCHEMA` — create the `dw` dataset in our own project
2. Dimension tables first (no dependencies between them)
3. `INSERT` seed data for static dimensions (tools, use cases, stages, sources)
4. Fact table last (references all dimension tables via FOREIGN KEY)
5. Verification `SELECT COUNT(*)` query to confirm all tables exist

**BigQuery-specific choices:**
- `PRIMARY KEY … NOT ENFORCED` — declares the key for documentation + query optimisation without enforcement overhead - meaning “BigQuery won’t strictly check it”
- `FOREIGN KEY … NOT ENFORCED` — same reason; BigQuery is analytical, not transactional
- `CREATE TABLE IF NOT EXISTS` — safe to re-run the script without errors
- `FLOAT64` for percentages (not INT64) — survey data can have decimal values

### Step 4 — Execute the Schema in BigQuery

The final step was to run `create_tables.sql` directly in the **BigQuery console** under project `ntu-data-science-488111`.

This created all 7 tables in the `dw` dataset. No additional tools were needed for this phase.

**Execution result:**
- 14 SQL statements processed
- Completed in 25 seconds
- All tables confirmed visible under `ntu-data-science-488111 → dw`

| Table | Rows after execution | How populated |
|---|---|---|
| `DimDate` | 16 rows | `INSERT` values seeded directly in the SQL script |
| `DimAITool` | 6 rows | `INSERT` values seeded directly in the SQL script |
| `DimAIUseCase` | 6 rows | `INSERT` values seeded directly in the SQL script |
| `DimAIAdoptionStage` | 3 rows | `INSERT` values seeded directly in the SQL script |
| `DimSurveySource` | 4 rows | `INSERT` values seeded directly in the SQL script |
| `DimCompany` | 0 rows | Structure created — data loaded by ELT colleague (Phase 3) |
| `FactAISurvey` | 0 rows | Structure created — data loaded by ELT colleague (Phase 3) |

`DimCompany` and `FactAISurvey` are intentionally empty at this stage. They will be populated when the ELT engineer (Phase 3) runs their dbt pipeline to load and transform data from the raw CSV source.

### Files Produced

| File | Purpose |
|---|---|
| `create_tables.sql` | Clean DDL — ready to run in BigQuery |
| `create_tables_explained.sql` | Same DDL with beginner-friendly comments |
| `star_schema.drawio` | Visual diagram — open in draw.io or diagrams.net |
| `DATA_WAREHOUSE_DESIGN.md` | Full technical design document with dbt models |
| `PROJECT_BRIEF.md` | Project overview and phase summary |
| `DOCUMENTATION.md` | This file — summary for presentation and review |

---

## 6. How Each Table Answers the Business Questions

| Table | Q1 Revenue | Q2 Productivity | Q3 Jobs |
|---|---|---|---|
| `FactAISurvey` | `revenue_growth_percent`, `cost_reduction_percent`, `ai_roi_index` | `productivity_change_percent`, `task_automation_rate`, `productivity_efficiency_score` | `jobs_displaced`, `jobs_created`, `net_jobs_change` |
| `DimCompany` | Group by `industry`, `company_size`, `revenue_band` | Group by `country`, `region` | Group by `company_size`, `region` |
| `DimDate` | Year-over-year revenue trend | Productivity change over time | Job trend over time |
| `DimAITool` | Revenue by tool type | Productivity by tool type | — |
| `DimAIUseCase` | Revenue by use case | Productivity by use case | Job impact by use case |
| `DimAIAdoptionStage` | Revenue: pilot vs full | Productivity: pilot vs full | Jobs: does full deployment cut more jobs? |
| `DimSurveySource` | Filter by reliable sources only | Filter by reliable sources only | Filter by reliable sources only |

---

## 7. Sample SQL Queries

### Q1 — Revenue growth by AI adoption stage
```sql
SELECT
    a.stage_label,
    a.stage_order,
    ROUND(AVG(f.revenue_growth_percent), 2)  AS avg_revenue_growth_pct,
    ROUND(AVG(f.cost_reduction_percent), 2)  AS avg_cost_reduction_pct,
    ROUND(AVG(f.ai_roi_index), 2)            AS avg_ai_roi
FROM `ntu-data-science-488111.dw.FactAISurvey` f
JOIN `ntu-data-science-488111.dw.DimAIAdoptionStage` a USING (stage_key)
GROUP BY a.stage_label, a.stage_order
ORDER BY a.stage_order;
```

### Q2 — Productivity change by AI tool
```sql
SELECT
    t.ai_primary_tool,
    t.tool_vendor_category,
    ROUND(AVG(f.productivity_change_percent), 2)  AS avg_productivity_change,
    ROUND(AVG(f.task_automation_rate), 2)          AS avg_automation_rate,
    ROUND(AVG(f.time_saved_per_week), 1)           AS avg_hours_saved_per_week
FROM `ntu-data-science-488111.dw.FactAISurvey` f
JOIN `ntu-data-science-488111.dw.DimAITool` t USING (ai_tool_key)
GROUP BY t.ai_primary_tool, t.tool_vendor_category
ORDER BY avg_productivity_change DESC;
```

### Q3 — Net jobs impact by region and company size
```sql
SELECT
    c.region,
    c.company_size,
    SUM(f.jobs_created)        AS total_jobs_created,
    SUM(f.jobs_displaced)      AS total_jobs_displaced,
    SUM(f.net_jobs_change)     AS net_employment_change,
    SUM(f.reskilled_employees) AS total_reskilled
FROM `ntu-data-science-488111.dw.FactAISurvey` f
JOIN `ntu-data-science-488111.dw.DimCompany` c USING (company_key)
GROUP BY c.region, c.company_size
ORDER BY net_employment_change DESC;
```

### Bonus — All 3 questions in one query
```sql
SELECT
    c.industry,
    a.stage_label,
    d.survey_year,
    ROUND(AVG(f.revenue_growth_percent), 2)      AS avg_revenue_growth,
    ROUND(AVG(f.productivity_change_percent), 2) AS avg_productivity,
    SUM(f.net_jobs_change)                        AS net_jobs
FROM `ntu-data-science-488111.dw.FactAISurvey` f
JOIN `ntu-data-science-488111.dw.DimCompany`        c USING (company_key)
JOIN `ntu-data-science-488111.dw.DimDate`           d USING (date_key)
JOIN `ntu-data-science-488111.dw.DimAIAdoptionStage` a USING (stage_key)
GROUP BY c.industry, a.stage_label, d.survey_year
ORDER BY c.industry, d.survey_year, a.stage_order;
```

---

## 8. Assumptions and Design Decisions

| Assumption | Reasoning |
|---|---|
| One row per company per quarter = the grain | Preserves maximum flexibility; analysts can always aggregate up |
| `company_age` in `DimCompany` is a snapshot from the first survey record | Company age changes every year; the snapshot gives a baseline. `company_age_at_survey` in fact gives the time-accurate value |
| `ai_adoption_stage` is its own dimension, NOT inside `DimCompany` | A company can change stage over time — putting it in DimCompany would be wrong |
| Governance scores stay in the Fact table | They are time-varying quarterly measurements, not static company attributes |
| Surrogate keys (INT64) used instead of natural keys (STRING) | Faster JOIN performance in BigQuery; insulates the schema from source system changes |
| `NOT ENFORCED` on all PK/FK constraints | BigQuery is an analytical warehouse — enforcement is done by dbt tests, not the database |

---

## 9. Limitations

| Limitation | Impact | Mitigation |
|---|---|---|
| Read-only access to raw data in classmate's project (`ntu-big-data`) | Cannot modify or re-load raw data | dbt reads cross-project; schema is fully in our own project |
| CSV has no true date column — only `survey_year` + `quarter` | Cannot do day-level analysis | `date_key` constructed as `YYYYMMDD` of quarter start; sufficient for quarterly analysis |
| `DimCompany` has no slowly-changing dimension (SCD) logic | If a company changes industry or size, history is overwritten | Acceptable for this dataset — full SCD would require Type 2 history tracking |
| Survey data is self-reported | Companies may over-report positive outcomes | `DimSurveySource` allows filtering to more reliable sources |

---

## 10. Handoff Checklist

### For ELT Engineer (Phase 3 — dbt)

- [ ] Confirm read access to `ntu-big-data.AI_Company_Adoption.AI_company_adoption_dataset`
- [ ] Confirm write access to `ntu-data-science-488111.dw`
- [ ] Run verification query in `create_tables.sql` — confirm 5 seeded tables have rows
- [ ] Set up dbt project with BigQuery adapter (`dbt init`, location = US)
- [ ] Create `sources.yml` pointing to `ntu-big-data.AI_Company_Adoption.AI_company_adoption_dataset`
- [ ] Build staging model first: `stg_ai_company_adoption.sql`
- [ ] Build dimension models (no dependencies between them): `dim_company`, `dim_date`, `dim_ai_tool`, `dim_ai_usecase`, `dim_ai_adoption_stage`, `dim_survey_source`
- [ ] Build fact model last (depends on all dims): `fact_ai_survey.sql`
- [ ] Run `dbt test` — all tests must pass before proceeding to Phase 4
- [ ] Run verification query again — `DimCompany` and `FactAISurvey` should now have rows
- [ ] Share `dbt docs generate` lineage graph with team

### For Data Analyst (Phase 5 — Python / BI)

- [ ] Connect to `ntu-data-science-488111.dw` via SQLAlchemy or BigQuery Python client
- [ ] Use sample queries in Section 7 above as starting points
- [ ] All 3 business questions can be answered with `FactAISurvey` + the relevant dimension JOINs
- [ ] Derived columns (`net_jobs_change`, `ai_roi_index`, `productivity_efficiency_score`) are pre-computed — use them directly
