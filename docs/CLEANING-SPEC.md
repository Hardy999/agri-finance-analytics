# Phase 3 - Cleaning specification

Status: AGREED, 17 October 2026. Hardy picked Rule 0 (flag) and P8 (mark all 473 suspect)
individually, with reasons in his words, and accepted every other recommendation as a batch.
`src/clean.py` is written to these rules, section by section.

Built from the findings table in section 6.1 of the Phase 2 document (MD5
`11232b99d9ad70ce8d15334a7a6769a4`). Every count below was re-measured from the raw files on
17 October; all six raw MD5s matched SOURCES.md before measuring. Where a count is new (not in
the Phase 2 table) it says so.

---

## What Phase 3 has to produce

**Objective.** One script, `src/clean.py`, that reads the six raw files and writes clean
files, with no manual step anywhere, and a log that explains every row that went in and
every row that came out.

**Outputs, if every recommended rule is picked:**

| File | Rows | From |
|---|---|---|
| `data/clean/prices.csv` | 37,676 | 37,765 raw minus 89 (rule P1) |
| `data/clean/markets.csv` | 20 | 93 raw minus 73 (rule P2) |
| `data/clean/crop_calendar.csv` | 38 | 34 Ghana rows observed + 4 borrowed (rule C3) |
| `data/clean/faostat_qcl.csv` | 1,536 | 1,536 raw, none removed |
| `data/clean/bog_policy_rate.csv` | 130 | 130 raw, none removed |
| `data/clean/price_coverage.csv` | derived | months present per series per year (rule P10) |
| `docs/cleaning_log.csv` | one line per rule | written by `clean.py` on every run: rule, file, rows in, rows affected, rows out |
| `docs/CLEANING-LOG.md` | - | the prose log, written from the csv after the run |

**Checks `clean.py` runs on itself (it stops if any fails):**

1. Raw MD5s match SOURCES.md before anything is read. Proves raw was not touched.
2. Reconciliation, per file: raw rows = clean rows + excluded rows, and the excluded rows
   broken down by reason re-sum to the excluded total.
3. A second, independent count of rule P1: the 24 markets' rows counted straight from the raw
   file must equal what the drop removed (89).
4. Keys are unique: prices on month + market + commodity + unit + price type; calendar on
   region + crop; Bank of Ghana on effective date.
5. Hand-computed spot check: Kumasi cassava, January 2006, 10.31 cedis per 91 KG bag
   -> price_per_kg 0.1133.
6. For every kept price row, `price` is identical to raw. Cleaning adds columns; it does not
   edit prices.
7. Run twice, the clean files have identical MD5s. Proves the script is deterministic.

**Done looks like:** one command takes raw to clean; all seven checks pass; the log is
complete; and you can explain every difference between raw and clean row counts without
opening the code.

---

## How to read each rule

Each rule names the defect (with its Phase 2 count), the recommended rule, the main rejected
alternative, and what the data loses under each. "Loses" means rows, columns or the ability
to answer a question later. Rules marked **Already decided** were settled in an earlier phase
and are here so the log is complete; confirm them, don't re-decide them.

---

## Rule 0 - The principle: flag, don't drop

Every rule below follows from this one, so pick it first.

- **Recommended: keep defective rows and add a flag column saying what is wrong.** Drop a row
  only when it can't be used by any analysis in either project. Under this principle only one
  rule drops rows (P1, the 2014-only markets).
- **Rejected: drop rows that fail a check** (outliers, units with no weight, suspect series).
- **Lost under recommended:** nothing is lost; the cost is that every later query must filter
  on the flags, and forgetting to is a real risk.
- **Lost under rejected:** 7,079 price rows, 19% of the file (2,005 outlier flags, 4,946
  non-weight rows and 473 suspect cassava rows, with overlaps counted once), including genuine
  lean-season spikes, and the evidence for why each was removed. A dropped row can't be
  re-examined in Phase 5.
- **Your pick:** Flag (17 Oct). See the picks table for the reason in your words.

---

## Prices

### P1 - Markets present only in 2014 (24 markets, 89 rows) - Already decided
Rule A from Scope-Decisions: exclude. The only rows dropped anywhere in Phase 3.
- **Your pick:** Confirmed (17 Oct).

### P2 - Markets file: 93 markets, 44 with prices, 20 after P1
- **Recommended:** `markets.csv` keeps the 20 markets that have prices after P1, with a
  `short_panel` flag on the five 3-8-year markets (Kintampo, Hohoe, Garu, Yendi, Nkwanta).
- **Rejected:** keep all 93.
- **Lost under recommended:** 73 market rows: 49 never priced, 24 removed by P1. None carry
  a price.
- **Lost under rejected:** nothing in data, but every Power BI market filter lists 73 markets
  with no prices.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### P3 - Every date is the 15th (37,765 of 37,765)
- **Recommended:** replace `date` with `month`, the first day of the month (2006-01-15 ->
  2006-01-01). The 15th is a stamp, not a survey day.
- **Rejected:** keep the 15th as published.
- **Lost under recommended:** nothing; the day carried no information.
- **Lost under rejected:** any join to a month table on an exact date returns no rows, with
  no error.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### P4 - 18 units; 4,946 rows in units with no weight
Non-weight rows: Bunch 2,753 (plantains), 100 Tubers 1,713 (yam), 30 pcs 480 (eggs).
- **Recommended:** add `unit_kg` (read from the unit: "91 KG" -> 91, "KG" -> 1) and
  `price_per_kg` = price / unit_kg. Non-weight rows are kept with both left empty.
- **Rejected:** drop the non-weight rows.
- **Lost under recommended:** nothing. Per-kg comparisons simply can't include those rows.
- **Lost under rejected:** 4,946 rows, including yam per tuber, which is Project B's main yam
  series (Scope-Decisions section 3), and every plantain and egg price.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### P5 - 41 cases of one market, month and commodity priced in two units (82 rows)
40 yam (100 Tubers and 250 KG), 1 rice (Kintampo, March 2020: 100 KG = 2.88/kg,
50 KG = 2.26/kg). All 2019-2020.
- **Recommended:** keep both rows. A price series is market + commodity + unit + price type,
  as in Phase 2, so these are two series, not a duplicate. Consequence for Phase 4: unit and
  price type must be in `fact_price`'s key. The Build Outline's "one row per market,
  commodity, month" is not enough and must be revisited at the Phase 4 grain decision.
- **Rejected:** keep one row per case (the commodity's main unit).
- **Lost under recommended:** nothing; the cost is a wider key in Phase 4.
- **Lost under rejected:** 41 rows, and a forced choice between yam per kg and yam per tuber
  for the 40 yam months.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### P6 - `usdprice` wrong in 92 rows (82 by 10x, 10 by 100x)
- **Recommended:** drop the column from the clean file.
- **Rejected:** keep it, with a flag on the 92 rows.
- **Lost under recommended:** nothing. Raw keeps it, and neither project uses dollars. If
  dollars are ever needed they are recalculated from `price` and a sourced exchange rate.
- **Lost under rejected:** nothing in data, but a column known to be wrong stays one click
  from a dashboard.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### P7 - 2,005 outlier flags (0.8% before 2019, 7.4% from 2019)
Method from Phase 2: price / median of the 7 months around it in its own series; flag above
2x or below 0.5x. 38 rows can't be tested (fewer than 3 prices in the window).
- **Recommended:** add `outlier_ratio` and `outlier_flag`; keep every row. The 7 Project A
  wholesale flags outside cassava are listed one by one in the log (largest: Ho maize,
  February 2023, 556.74 against a median of 155.54).
- **Rejected:** drop flagged rows.
- **Lost under recommended:** nothing; Phase 5 decides per analysis whether flagged rows count.
- **Lost under rejected:** 2,005 rows, including real price spikes. And the flag is not proof
  of error: in the Kumasi onions case from Phase 2 the flagged price was the right one and
  its neighbours were wrong.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### P8 - Cassava wholesale from 2019 (473 rows) - the separate cassava decision
Phase 2 found 70 of 77 Project A wholesale flags are cassava. Measured on 17 October, two
independent ways:
- Flag rate: cassava wholesale 0.9% before 2019, **11.6%** from 2019. Maize, millet, sorghum
  and rice stay at 0.2% or below in both periods.
- Wholesale per kg above retail per kg, same market and month: cassava 147 of 371 months,
  more than double retail in 55. The other four crops: 0 months above double. (Wholesale
  should be below retail; for all five crops the median is 0.87-0.89 of retail.)
- The series is erratic between flags too. Sekondi/Takoradi, 2020: 104.93, 309.44, 371.48,
  222.76 per 91 KG bag in consecutive months. A 7-month median of a noisy series is itself
  noisy, so the row flag misses most of it.

- **Recommended:** add a series-level flag `series_suspect` = true on all 473 cassava
  wholesale rows from 2019. Keep the rows. Project A's cassava seasonality uses wholesale
  2006-2018 (1,712 rows, 18 markets).
- **Rejected:** rely on the row-level outlier flag only (55 rows from 2019).
- **Lost under recommended:** Project A's cassava wholesale series ends in 2018. Seasonality
  needs repeated years, not recent ones, and 13 years remain.
- **Lost under rejected:** the cassava seasonal pattern absorbs 2019-2023 noise the flag
  doesn't catch, and Project A's cassava cash months come out wrong with no error anywhere.
- **Your pick:** A (17 Oct). Considered and rejected in discussion: filling the 55 flagged
  rows from the other 418. Under Rule 0 nothing is removed, so there is no gap to fill, and a
  filled value would be invented from rows already judged not normal.

### P9 - Per-kg prices stored under bag units (15 rows - new count)
Phase 2 found the pattern in one case (Kumasi onions). Measured on 17 October: 15 bag-unit
rows priced at roughly series median / bag weight - chicken 7, eggplants 5, onions 2, dried
peppers 1. None in the six scope crops.
- **Recommended:** no correction. Add `unit_suspect` = true on the 15 and list them in the log.
- **Rejected:** multiply each by its bag weight.
- **Lost under recommended:** nothing for Projects A or B.
- **Lost under rejected:** the clean file holds 15 prices nobody observed, built on a guess
  about how the error happened.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### P10 - Gappy series (millet and sorghum 6 markets a year to 2017, 5 in 2018; Tamale millet 0 months in 2018; Wa 1, 0, 3 months 2018-20)
- **Recommended:** no filling, no rows created. Write `price_coverage.csv`: months present per
  market, commodity, unit, price type and year, so Phase 5 can filter on coverage.
- **Rejected:** fill missing months (carry the last price forward, or interpolate).
- **Lost under recommended:** Upper West millet 2018-20 rests on 4 months of data, and that
  stays visible.
- **Lost under rejected:** nothing visible, which is the problem. Filled months are prices
  nobody recorded (non-negotiable rule 2), and they make thin series look complete.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### P11 - Redenomination - Already decided by measurement
Prices are already in new cedis (implied rate 0.92 in 2006). No conversion; logged as checked.
- **Your pick:** Confirmed (17 Oct).

---

## Crop calendar

### C1 - Reading the file - no real alternative
Semicolon-delimited; header ends in a comma, so the last column reads as `eos_e,` and all
3,068 of its values are text.
- **Rule:** read with `sep=";"`; rename `eos_e,` to `eos_e`; strip the trailing comma from
  every value; convert to a whole number. Keep the 34 Ghana rows (3,034 other-country rows out
  of scope, logged). Same for the national file: 7 Ghana rows of 287.
- Both the rename and the strip are needed, and they fix different things. Why each one is
  needed on its own is a Phase 3 gate question, so it is not spelled out here.
- **Your pick:** Confirmed (17 Oct).

### C2 - Region names ("West" vs "WESTERN"; 9 of 10 match after upper-casing)
- **Rule:** upper-case, then map WEST -> WESTERN. Without it, Western's market silently drops
  out of every calendar-price join.
- **Your pick:** Confirmed (17 Oct).

### C3 - Missing maize calendar rows
Main-season maize exists for Central, Eastern, Greater Accra, Volta and Western only.
Northern has one maize row (labelled "Second", planting August, harvest late November to
December). Upper East and Upper West have none, yet Bolga, Garu and Wa have 408 wholesale
maize rows between them.

**(a) Ashanti and Brong Ahafo main-season maize - Already decided** (Scope-Decisions
section 1): borrow the national main-maize row. Confirm.

**(b) Upper East and Upper West maize - your decision.**
- **Recommended:** borrow Northern region's maize row (same crop, adjacent region, same
  single-rainy-season zone): harvest dekads 33-36, late November to December.
- **Rejected 1:** borrow the national main-maize row. Its harvest is dekads 20-24, July to
  August: the southern main season. In the north that is the lean season, so it would put
  maize cash in the months farmers have least of it - the kind of error Project A exists to
  catch.
- **Rejected 2:** use the same region's millet/sorghum window (harvest November to early
  December). Similar months, but a different crop.
- **Lost under recommended:** a calendar row Upper East and Upper West never had, flagged as
  borrowed everywhere it appears. Northern's row is labelled "Second" in a one-season region;
  that label oddity is a limitation for the memo.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

**How borrowing is recorded (applies to (a) and (b)):** every calendar row gets
`calendar_source` = `observed` or `borrowed: <where from>`. 4 borrowed rows, 34 observed.

**Not filled, on purpose:** Upper East and Upper West cassava (140 wholesale rows) - not raised
in Phase 2, small series, left outside Project A unless you want them in. And millet, sorghum
and rice priced in southern markets (3,381 wholesale rows) are not gaps: those are consuming
markets with no farmers of that crop to model. They stay in `prices.csv` for Project B.

### C4 - Harvests that cross New Year (7 second-season maize rows, e.g. dekad 35 -> 1)
- **Recommended:** keep the dekads exactly as published; add `harvest_crosses_year` = true on
  the 7 rows.
- **Rejected:** "unwrap" by adding 36 to the end dekad (1 -> 37), so a window always counts
  upward.
- **Lost under recommended:** nothing; the cost is that every window calculation in Phase 5
  must check the flag.
- **Lost under rejected:** the clean file holds dekad numbers (37, 38) that don't exist in the
  source or on any calendar.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

---

## FAOSTAT

### F1 - Reading and columns
- **Rule:** item code read as text (01520.01 keeps its zero). Drop five columns that carry no
  information: Domain Code, Domain, Area Code (M49) and Area (one value each in all 1,536
  rows) and Year Code (identical to Year in every row). **Keep Note**: it is not constant -
  34 rows say "Unofficial figure" (new count).
- **Rejected:** keep all 15 columns.
- **Lost under recommended:** nothing; the dropped values are in raw and are the same on
  every row.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

### F2 - 150 blank values (cowpeas 1961-2010) and the Flag column
- **Recommended:** keep all 1,536 rows; blanks stay empty, not zero; keep Flag and Flag
  Description. All eight items stay, not only the Project A ones.
- **Rejected:** keep only the Project A and B crops (drops cowpeas and groundnuts, and with
  them the blanks).
- **Lost under recommended:** nothing.
- **Lost under rejected:** nothing for A or B today, but a lead-specific demo on cowpeas or
  groundnuts (the reusability constraint) would need the pipeline changed.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

---

## Bank of Ghana

### B1 - Key (Meeting No. 107 appears twice; Effective Date unique and ordered)
- **Rule:** parse Effective Date as a date and use it as the key. Keep Meeting No. as a plain
  attribute and MPC Dates as text. 130 rows kept.
- **Your pick:** Confirmed (17 Oct).

### B2 - Turning decisions into a monthly rate
- **Recommended:** don't do it in Phase 3. The clean file stays one row per decision. The
  monthly series is built in Phase 4, when `fact_rate`'s grain is agreed.
- **Rejected:** forward-fill to monthly in `clean.py`.
- **Why:** the monthly series is a modelling choice with a real alternative inside it. A rate
  effective 24 January: is January's rate the old one or the new one? That belongs with the
  grain decision, not inside a cleaning script.
- **Lost under recommended:** nothing; Phase 4 has one more step.
- **Lost under rejected:** the month-boundary choice gets made in passing and is hard to see
  later.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

---

## Across files

### X1 - Column names
Clean files use lower-case snake_case ASCII names (`Meeting No.` -> `meeting_no`,
`Item Code (CPC)` -> `item_code`, `BOG Policy Rate` -> `policy_rate`). SQL Server accepts the
originals only in square brackets in every query. No alternative worth taking.
- **Your pick:** Confirmed (17 Oct).

### X2 - Crop names differ across files (new - not checked in Phase 2)
| crop | prices | calendar | FAOSTAT |
|---|---|---|---|
| maize | Maize | Maize (South/Main), Maize (Second) | Maize (corn) |
| millet | Millet | Millet | Millet |
| sorghum | Sorghum | Sorghum | Sorghum |
| rice | Rice (local) | Rice (North) | Rice |
| cassava | Cassava | Cassava (Year1, year2) | Cassava, fresh |
| yam | Yam | Yams | Yams |

- **Recommended:** add a `crop` column to each clean file from this mapping, written once in
  `clean.py`. Other commodities (Rice (imported), Yam (puna), Maize (yellow), ...) get no crop
  value. Checked by asserting every scope crop maps to rows in all three files.
- **Rejected:** leave names as published and build the mapping in Phase 4's `dim_commodity`.
- **Lost under recommended:** nothing. One judgement to state: FAOSTAT "Rice" covers all rice
  produced; the price series is local rice specifically. Treating them as one crop is fine
  for production context and is noted.
- **Lost under rejected:** the calendar-price join can't be tested until Phase 4, so a
  mismatch would surface late.
- **Your pick:** Recommended rule (17 Oct, accepted in the batch).

---

## Found while preparing this spec - not in the Phase 2 findings table

Two of these become flags or columns above (P9, X2). The other two get no rule, because
Phase 3 doesn't clean what Phase 2 didn't profile:

1. **`priceflag` has a third value, `actual,aggregate`** - 410 rows, all wholesale, 2019 (258)
   and 2020 (152). Phase 2 recorded the switch from actual to aggregate, not this mixed value.
   Recommended: keep as published; no rule.
2. **Repeated prices.** 8,757 rows equal the previous month's price in the same series. Project
   A wholesale: 19.1% before 2019, 28.0% from 2019. Some will be real (prices that didn't move),
   some may be carried forward by the publisher; the file can't tell which. Recommended: no
   rule; a limitation for the memo. If you want it profiled first, that's a short Phase 2
   addendum before `clean.py`.

---

## Not cleaning rules - carried to later phases

- Seasonality measured against the local trend, never raw cross-year averages - Phase 5.
- Separating period and price type before any aggregate - Phase 5.
- Labelling FAOSTAT 2022-23 outputs as mostly non-official - Phase 6.
- `fact_price` key must include unit and price type (from P5) - Phase 4.
- Monthly policy rate (from B2) - Phase 4.
- FAOSTAT BOM in the SQL Server load - Phase 4.
- Bank of Ghana licence - before Phase 7.

---

## Hardy's picks

| Rule | Pick | One line why (required for 0, P8, C3b, P5) |
|---|---|---|
| 0 Flag, don't drop | Flag (17 Oct) | "with rule 0 we can still filter down to a smaller dataset, where as with drop here we will not have that set of data to consider when checking for answers" |
| P1 2014-only markets | Confirmed (17 Oct) |  |
| P2 Markets file | Recommended (17 Oct) |  |
| P3 Date to month | Recommended (17 Oct) |  |
| P4 Units / price per kg | Recommended (17 Oct) |  |
| P5 Two-unit cases | Recommended (17 Oct) | Accepted in the batch; reason not given. Gate question. |
| P6 usdprice | Recommended (17 Oct) |  |
| P7 Outlier flags | Recommended (17 Oct) |  |
| P8 Cassava wholesale 2019+ | A: mark all 473 suspect (17 Oct) | "these rows are not normal because wholesale prices are above the retail prices for the same market and month" |
| P9 Per-kg under bag units | Recommended (17 Oct) |  |
| P10 Gaps | Recommended (17 Oct) |  |
| P11 Redenomination | Confirmed (17 Oct) |  |
| C1 Reading the calendar | Confirmed (17 Oct) |  |
| C2 Region names | Confirmed (17 Oct) |  |
| C3a Ashanti / Brong Ahafo maize | Confirmed (17 Oct) |  |
| C3b Upper East / Upper West maize | Recommended (17 Oct) | Accepted in the batch; reason not given. Gate question. |
| C4 Year wrap | Recommended (17 Oct) |  |
| F1 FAOSTAT columns | Recommended (17 Oct) |  |
| F2 FAOSTAT blanks and items | Recommended (17 Oct) |  |
| B1 BoG key | Confirmed (17 Oct) |  |
| B2 Monthly rate | Recommended (17 Oct) |  |
| X1 Column names | Confirmed (17 Oct) |  |
| X2 Crop crosswalk | Recommended (17 Oct) |  |
| New 1 priceflag mixed value | Recommended (17 Oct) |  |
| New 2 Repeated prices | Recommended (17 Oct) |  |
