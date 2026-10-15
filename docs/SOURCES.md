# SOURCES

Every dataset in `data/raw/` has a block here. No dataset enters the project without one.

Row counts and MD5 hashes were measured from the files on disk on the access date, not
copied from the source pages. Where a source page states a figure and the file disagrees,
the file wins and the disagreement is recorded.

Files were renamed after download. Renaming does not alter content: every hash below was
measured before the rename and re-measured after, and all six matched.

---

## 1. WFP food prices, Ghana

- **File:** `data/raw/wfp_food_prices_gha.csv`
- **URL:** https://data.humdata.org/dataset/wfp-food-prices-for-ghana
- **Accessed:** 2026-09-20
- **Publisher:** WFP, via HDX. Dataset ID `626e809c-c4fc-467b-a60c-129acb5e9320`
- **Upstream source chain:** FPMA, MoFA Marketing Services Unit, SRID (MoFA), via FAO GIEWS
- **Licence:** Creative Commons Attribution for Intergovernmental Organisations (CC BY-IGO)
- **Records:** 37,766 lines = 1 header + 37,765 data rows
- **MD5:** `1e3aed1c5551f38375b744852baabb4f`
- **Bytes:** 5,041,494
- **Delimiter:** comma. **Encoding:** UTF-8, LF. **Header:** line 1
- **Coverage:** 2006-01-15 to 2023-07-15, measured from the file
- **Currency:** GHS, with a parallel `usdprice` column

**Note on the update frequency.** The HDX page states an expected update frequency of
every month and a "Modified" date of 2026-09-20. The data stops at 2023-07-15. The
modified date reflects metadata activity, not new observations. Taking the page at its
word would have produced a pipeline built for current prices that silently returns
nothing after mid-2023.

**Fields contain commas inside quoted values** (for example the category
`"meat, fish and eggs"`). Any reader that splits on commas without honouring quoting will
misalign those rows. Use a real CSV parser.

## 2. WFP markets, Ghana

- **File:** `data/raw/wfp_markets_gha.csv`
- **URL:** same dataset page as source 1
- **Accessed:** 2026-09-20
- **Licence:** CC BY-IGO
- **Records:** 94 lines = 1 header + 93 markets
- **MD5:** `e234287b980bf36fc165dcfdba914825`
- **Bytes:** 4,818
- **Delimiter:** comma. **Encoding:** UTF-8, LF
- **Contents:** market_id, market, countryiso3, admin1, admin2, latitude, longitude

## 3. Crop calendar for Africa — national

- **File:** `data/raw/crop_calendar_gaul0.csv`
- **URL:** https://datacatalog.worldbank.org/search/dataset/0066842/crop-calendar-for-africa
- **Direct file:** https://datacatalogfiles.worldbank.org/ddh-published/0066842/DR0095318/crop_calendar_gaul0.csv
- **Accessed:** 2026-09-20
- **Publisher:** World Bank Data Catalog, compiled for Gascoigne et al. (2024) from
  Dimou (2018), European Commission Joint Research Centre
- **Underlying dataset:** http://data.europa.eu/89h/jrc-10112-10003
- **Licence:** Creative Commons Attribution 4.0
- **Records:** 288 lines = 1 header + 287 data rows
- **MD5:** `4430991cb6c58b82cea25cf5af503047`
- **Bytes:** 10,342
- **Delimiter:** SEMICOLON. **Encoding:** UTF-8, CRLF. **Header:** line 1
- **Temporal coverage:** 2019, single vintage. Not a time series.
- **Units:** dekads. 36 per year, each roughly 10 days. Columns `sos_s`, `sos_e` bound
  the planting window; `eos_s`, `eos_e` bound the harvest window.
- **Ghana rows:** 7 — Cassava (Year1, year2), Maize (Second), Maize (South/Main),
  Millet, Rice (North), Sorghum, Yams

## 4. Crop calendar for Africa — subnational

- **File:** `data/raw/crop_calendar_gaul1.csv`
- **Direct file:** https://datacatalogfiles.worldbank.org/ddh-published/0066842/DR0095319/crop_calendar_gaul1.csv
- **Accessed:** 2026-09-20
- Publisher, licence, units and vintage as source 3.
- **Records:** 3,069 lines = 1 header + 3,068 data rows
- **MD5:** `86e9b947093c790f1af5949e79b8cb7e`
- **Bytes:** 159,373
- **Delimiter:** SEMICOLON. **Encoding:** UTF-8, CRLF
- **Ghana rows:** 34, across 10 regions on the pre-2019 boundaries
- **Geography:** ASAP/GAUL level 1 ids, not Ghana's post-2018 16-region structure

**Known defect, present at acquisition.** 3,036 of 3,069 lines end in a trailing comma
before the line terminator, *including the header*. The other 33 lines are all data lines,
8 of them Ghana. Because the header ends in a comma, pandas names the last column `eos_e,`.
Separately, 3,035 of its values end in a comma and cannot be read as numbers; a pandas
column holds one type, so the whole column reads as text — all 3,068 values, including the
33 clean ones. Phase 3 must rename the column, strip the comma and convert it to a whole
number. (Corrected after Phase 2 — see the corrections log at the end.)

## 5. FAOSTAT — crops and livestock products, Ghana

- **File:** `data/raw/faostat_qcl_ghana.csv`
- **URL:** https://www.fao.org/faostat/en/#data/QCL
- **Accessed:** 2026-09-20
- **Publisher:** FAO. Domain QCL.
- **Licence:** Creative Commons Attribution 4.0
- **Source last updated:** 2025-12-31, as stated on the domain page
- **Records:** 1,537 lines = 1 header + 1,536 data rows
- **MD5:** `e42769d1b60bcabe8dc8d42d2ef712b0`
- **Bytes:** 221,657
- **Delimiter:** comma. **Encoding:** UTF-8 with BOM. pandas strips the BOM itself. Python's
  `csv` module, read as plain `utf-8`, keeps it as `\ufeff` at the start of the first column
  name; whether the SQL Server load strips it is checked at Phase 4. **The pandas trap is
  different:** `Item Code (CPC)` reads as a number and loses its leading zeros — read it with
  `dtype={"Item Code (CPC)": "str"}`. (Corrected after Phase 2.)
- **Coverage:** 1961 to 2024, 64 distinct years
- **Elements:** Area harvested (ha), Production (t), Yield (kg/ha)
- **Items:** Cassava fresh; Cow peas dry; Groundnuts excluding shelled; Maize (corn);
  Millet; Rice; Sorghum; Yams

**Provenance flags, as distributed:** Official value 1,155 · Estimated value 160 ·
blank 150 · Value from external organization 44 · Value imputed by a receiving agency 27.
Roughly one value in four is not an official reported figure. The `Flag` column must
survive cleaning and must reach any output that presents these numbers.

## 6. Bank of Ghana — historical policy rate decisions

- **File:** `data/raw/bog_policy_rate.csv`
- **URL:** https://www.bog.gov.gh/monetary-policy/policy-rate-trends/
- **Accessed:** 2026-09-20
- **Publisher:** Bank of Ghana
- **Licence: NOT YET VERIFIED.** No licence or terms-of-use statement has been
  confirmed for this file. Must be resolved before Phase 7, where the repository
  licence has to be compatible with every source licence.
- **Records:** 131 records = 1 header + 130 decisions
- **MD5:** `dc7fa3634497158e9aa730643c204e95`
- **Bytes:** 6,852
- **Delimiter:** comma, all fields quoted. **No terminating newline on the final line.**
- **Columns:** Meeting No., MPC Dates, Effective Date, BOG Policy Rate
- **Coverage:** from meeting 1, effective 21 Nov 2002
- **Grain:** one row per MPC decision, not a monthly series. Converting it to a monthly
  series requires forward-filling each rate to the next decision. That is a modelling
  step and is logged as one, not treated as raw data.

`MPC Dates` is free text holding a date range with a non-ASCII dash, for example
"November 20 – 21, 2002". `Effective Date` is the parseable column.

---

## Verification method

For each file: byte size, MD5, record count, terminating newline, encoding and
delimiter were read from the file itself. Coverage, category values and flag
distributions were computed from the file rather than read off the source page.
Every hash was re-measured after renaming and matched.

---

## Corrections after Phase 2 profiling (15 Oct 2026)

Phase 1 measured these files as bytes and lines. Phase 2 read them with pandas and found two
statements above were wrong. Both are corrected in place; the original claims are kept here.

1. **Source 4.** Phase 1 said the header was one of the 33 lines without a trailing comma,
   and that `eos_e` would read as text on most rows and as a number on the rest. Wrong: the
   header does end in a comma (so the column is named `eos_e,`), and every value reads as
   text, because a pandas column holds one type.
2. **Source 5.** Phase 1 gave reading the file as `utf-8-sig` as the fix for the BOM. In
   pandas the BOM causes no problem; the real trap is the item code losing its leading zeros.
