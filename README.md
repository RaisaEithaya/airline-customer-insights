# Airline Customer Insights: End-to-End CX Analytics Pipeline

An end-to-end customer experience (CX) analytics project for an airline Customer Care team, built with **Python, PostgreSQL and Power BI**.

Raw, messy survey and complaint data is cleaned in Python, modelled in PostgreSQL as a star schema, analysed in SQL, and presented in an interactive Power BI dashboard and a management presentation.

> **Note:** the dataset is **synthetic**, created for practice. It is not real airline or passenger data.

---

## Business Problem

Customer Care management has no single, trusted view of customer experience. The raw data has duplicates, invalid scores, inconsistent spellings and text in numeric columns, so the KPIs reported from it are not reliable.

**Key business question:** *Which routes, cabins and touchpoints drive dissatisfaction and complaints, and where should the airline act first?*

Full details are in `Business Problem Document.pdf`.

---

## Tools & Technologies

- **Python (Pandas, NumPy):** data cleaning and data-quality log
- **PostgreSQL:** star schema, primary/foreign keys, KPI views, SQL analysis
- **SQLAlchemy:** loading Python data into PostgreSQL
- **Power BI (DAX):** interactive dashboard
- **VS Code**

---

## Pipeline

```
Raw Excel (dirty)  →  Python cleaning  →  PostgreSQL (star schema + views)  →  Power BI dashboard
                         ↓
                  Data-quality log
```

### 1. Data cleaning (Python)
| Issue found | Rows | Action |
| --- | --- | --- |
| Duplicate SurveyID / CaseID | 5 | Removed (deduped on record ID, not customer ID) |
| Scores outside valid range (CSAT 1–5, NPS 0–10, CES 1–7) | 7 | Set to null, not guessed |
| Cabin, issue type and resolved spelling variants | 14 | Standardised |
| Routes with extra spaces | 6 | Trimmed |
| Contact count 0 or negative | 4 | Set to null |
| Month spelling variants | 4 | Standardised |
| Negative passengers | 2 | Set to null |
| Passengers blank or text ("unknown") | 5 | Kept as null |

**Cleaning principles:** dedupe on the record ID · invalid values become null, never guessed · every fix is logged.

### 2. Data model (PostgreSQL)
Star schema in the `pipeline` schema:

| Table | Type | Primary key | Foreign key |
| --- | --- | --- | --- |
| `routes` | Dimension | route | |
| `surveys` | Fact | survey_id | route → routes |
| `complaints` | Fact | case_id | route → routes |
| `flights` | Fact | | route → routes |

KPI views: `v_kpi_by_route` and `v_complaints_by_route`.

### 3. SQL analysis
`query.sql` answers 12 business questions using GROUP BY / HAVING, CASE WHEN, CTEs, aggregate-before-join, DATE_TRUNC and window functions (RANK, SUM OVER PARTITION BY).

### 4. Power BI dashboard
`customer_insights_dashboard.pbix` connects to the PostgreSQL tables and views:
- **Overview:** KPI cards and satisfaction by route, cabin and issue
- **Complaints:** volume, resolution, FCR and repeat complainers
- **Drivers:** route scorecard with Route and Cabin slicers

DAX measures are listed in `dax_measures.dax`.

---

## KPI Definitions

| KPI | Definition |
| --- | --- |
| CSAT % | Responses scoring 4–5 ÷ answered responses |
| NPS | % promoters (9–10) − % detractors (0–6) |
| CES | Average effort score (1–7, lower is better) |
| FCR % | Cases solved in 1 contact and resolved ÷ all cases |
| Complaints per 1K pax | Complaints ÷ passengers × 1,000 |

KPIs were reconciled across Python, SQL and Power BI and match in all three.

---

## Results

| CSAT % | NPS | Avg CES | FCR % | Complaints per 1K pax |
| --- | --- | --- | --- | --- |
| **69.8%** | **+5.1** | **3.59** | **63.0%** | **1.00** |

## Key Insights

- **Business Class loyalty gap:** NPS is −6.5 in Business vs +27.3 in First and +7.7 in Economy, despite similar CSAT (69–73%).
- **Weakest touchpoints:** Refund (63.9%) and Check-in (64.2%) have the lowest CSAT.
- **Weakest route:** DOH-CDG has the lowest CSAT (57.4%) and a negative NPS (−5.1).
- **Highest complaint rate:** DOH-JFK has 1.57 complaints per 1,000 passengers, nearly double DOH-LHR (0.81).
- **Hardest to resolve:** Lounge Access has the most cases (60) and the lowest FCR (50%).
- **Service recovery:** 115 customers raised more than one complaint.

## Recommendations

1. **Fix the refund and check-in experience.** Track CSAT % for both and average resolution days.
2. **Win back Business Class loyalty.** Deep-dive comments on CDG, LHR and JFK and benchmark against competitors. Track Business NPS.
3. **Resolve lounge cases at first contact.** Track Lounge FCR % and repeat complainers.
4. **Fix data quality at the source with IT:** dropdowns, score validation, required fields and a data dictionary.

## A lesson from the project

Power BI first showed NPS **3.85** while Python showed **5.1**. The cause: in DAX a blank equals 0 in comparisons, so unanswered surveys were counted as detractors. Filtering blanks out first fixed it, which is why every KPI is reconciled in two tools.

---

## Project Files

| File | Description |
| --- | --- |
| `Business Problem Document.pdf` | Problem statement, questions, data and KPI definitions |
| `airline_cx_dataset_raw.xlsx` | Raw (dirty) synthetic dataset: Surveys, Complaints, Flights |
| `Customer_Insights_Pipeline.ipynb` | Python cleaning, quality log and load into PostgreSQL |
| `query.sql` | KPI views and 12 SQL business questions |
| `dax_measures.dax` | Power BI DAX measures |
| `customer_insights_dashboard.pbix` | Power BI dashboard |
| `Airline Customer Insights Analysis.pptx` / `.pdf` | Findings and recommendations for management |

## How to Run

1. Create a PostgreSQL database (e.g. `qatar_kpi`).
2. Open `Customer_Insights_Pipeline.ipynb`, set your PostgreSQL password in Step 0, and run all cells.
3. Run `query.sql` in pgAdmin to create the views and answer the questions.
4. Open the `.pbix` file and point it to your PostgreSQL server (Transform data → Data source settings).
