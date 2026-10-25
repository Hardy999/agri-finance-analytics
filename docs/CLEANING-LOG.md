# Cleaning log - Phase 3

What `src/clean.py` did to each raw file, with counts, reasons and what each rule costs.
The counts come from `docs/cleaning_log.csv`, which the script writes on every run; this
file explains them. The rules themselves, and the alternatives rejected, are in
`docs/CLEANING-SPEC.md`.

Run: 24 October 2026, pandas 3.0.6, project `.venv`. All six raw files matched the MD5s in
`docs/SOURCES.md` before anything was read. All final checks passed.

DRAFT by Claude from the run output. Hardy reviews before the Phase 3 gate.

---

## The principle

**Flag, don't drop** (Rule 0, Hardy's pick: "with rule 0 we can still filter down to a smaller
dataset, where as with drop here we will not have that set of data to consider when checking
for answers"). Defective rows stay in the clean files with a column saying what is wrong. One
rule removes price rows: P1. A drop-everything-flagged rule would have removed 7,079 price
rows, 19% of the file, most of them correct prices.

---

## Reconciliation

Checked by the script itself, reading the written files back from disk.

| File | Raw | Removed | Added | Clean | Removed rows, by reason |
|---|---|---|---|---|---|
| Prices | 37,765 | 89 | 0 | 37,676 | P1: 89 |
| Markets | 93 | 73 | 0 | 20 | P2, no prices: 49; P1, only in 2014: 24 |
| Calendar (subnational) | 3,068 | 3,034 | 4 | 38 | other countries: 3,034. Added: 4 borrowed maize rows |
| FAOSTAT | 1,536 | 0 | 0 | 1,536 | - |
| Bank of Ghana | 130 | 0 | 0 | 130 | - |

Removed price and market rows are kept, with their reason, in
`data/interim/excluded_prices.csv` and `data/interim/excluded_markets.csv`.

Also checked: every one of the 37,676 clean prices is identical to its raw value
(cleaning added columns, it did not edit a price); keys are unique in every clean file; Kumasi
cassava, January 2006, comes out at 0.1133 cedis per kg, as worked out by hand
(10.31 / 91).

---

## Prices (`data/clean/prices.csv`, 37,676 rows, 22 columns)

**P3 - date to month. 37,765 rows.** Every date was the 15th (checked again before changing
it): a stamp, not a survey day. Replaced by `month`, the first day of the month, so joins to
a month table match. Nothing lost.

**P1 - 2014-only markets. 89 rows removed, 24 markets.** A one-year survey expansion; kept in,
they would make any 2014 cross-market average compare a different set of markets. Counted two
different ways in the script; both gave 89. 20 markets remain: 15 long-panel, 5 short-panel.

**P4 - price per kg. 4,946 rows have no weight and are kept with `price_per_kg` empty.**
Units: Bunch 2,753 (plantains), 100 Tubers 1,713 (yam), 30 pcs 480 (eggs). They are correct
prices that cannot be put in kg without inventing a weight. Yam per tuber is Project B's main
yam series. Cost: these rows can't enter any per-kg comparison.

**P5 - two units in one month. 41 cases, both rows kept.** 40 yam (100 Tubers and 250 KG),
1 rice (Kintampo, March 2020). A series is market + commodity + unit + price type, so these
are two series, not duplicates. Consequence: Phase 4's price table must have unit and price
type in its key. No code needed in Phase 3.

**P6 - `usdprice` removed.** Wrong in 92 rows (82 by 10x, 10 by 100x), measured in Phase 2.
Neither project uses dollars; raw keeps the column.

**P7 - outlier flags. 2,005 flagged, 38 untestable, none removed.** Each price against the
median of the 7 prices around it in its own series; flagged above 2x or below 0.5x.
`outlier_flag` is empty, not False, for the 38 that have too few neighbours: not tested is
different from tested and fine. A flag means unusual, not wrong. The Project A wholesale flags
outside cassava, listed as the spec promised:

| Month | Market | Crop | Unit | Price | x local median |
|---|---|---|---|---|---|
| 2017-09 | Sekondi/Takoradi | Rice (local) | 50 KG | 476.00 | 2.48 |
| 2008-09 | Mankessim | Maize | 100 KG | 32.00 | 0.47 |
| 2023-02 | Ho | Maize | 100 KG | 556.74 | 3.58 |
| 2009-09 | Ejura | Maize | 100 KG | 20.00 | 0.47 |
| 2020-06 | Ejura | Sorghum | 109 KG | 545.00 | 2.08 |
| 2014-10 | Nkwanta | Maize | 100 KG | 120.00 | 0.40 |
| 2023-04 | Hohoe | Rice (local) | 50 KG | 727.27 | 2.82 |

**P8 - cassava wholesale from 2019. 473 rows marked `series_suspect`, kept.** Hardy's pick:
"these rows are not normal because wholesale prices are above the retail prices for the same
market and month." Evidence: flag rate 11.6% from 2019 against 0.9% before; wholesale per kg
above retail in 147 of 371 matched months, above double in 55 (no other Project A crop is
ever above double). Project A's cassava seasonality uses 2006-2018 wholesale: 1,712 rows, 18
markets. Filling the 55 flagged rows from the other 418 was considered and rejected: nothing
was removed, so there is no gap, and a fill would invent values from rows already judged not
normal.

**P9 - per-kg prices under bag units. 15 rows marked `unit_suspect`, not corrected.** Priced
about one bag-weight below their series' normal level: chicken 7, eggplants 5, onions 2,
dried peppers 1. None in the six scope crops. Correcting them would mean guessing how the
error happened.

**X2 - crop names. 16,456 rows get a `crop` value; 21,220 others left empty.** One table in
the script maps each file's names to six crops (for example Rice (local) / Rice (North) /
Rice -> rice). Other commodities, including Rice (imported) and Yam (puna), get no crop by
design. Judgement noted: FAOSTAT "Rice" is all rice produced, the price series is local rice.

**P10 - gaps. No months filled.** `data/clean/price_coverage.csv`: 5,089 series-years, each
with the months present, **229 of them with 0 months**. Every year inside a series' span is
listed, including empty ones (for example Wa millet wholesale 2018-2020: 1, 0, 3; Tamale
millet 2018: 0). Phase 5 filters on this table instead of on filled-in prices.

**P11 - redenomination. No conversion.** Checked in Phase 2: already new cedis (implied rate
0.92 in 2006).

**priceflag `actual,aggregate` (410 rows, 2019-2020 wholesale).** Kept as published; no rule.

---

## Markets (`data/clean/markets.csv`, 20 rows)

**P2. 73 markets removed: 49 never priced, 24 removed by P1.** Built from the clean prices,
so the two files can't disagree about which markets exist. `short_panel` is True for the five
markets with 8 or fewer years of prices (Kintampo, Hohoe, Garu, Yendi, Nkwanta), worked out
from the data and checked against Phase 1's list.

---

## Crop calendar (`data/clean/crop_calendar.csv`, 38 rows)

**C1 - reading.** Semicolon-delimited. The last column, published as `eos_e,`, was renamed
`eos_e`, and the trailing comma stripped from its values before converting them to whole
numbers. Two separate fixes: one to the column's name, one to its values. 3,034 other-country
rows left out; 34 Ghana rows kept.

**C2 - regions. 4 rows changed.** Upper-cased, and West mapped to WESTERN. All 10 calendar
regions match the 10 price regions exactly.

**C3 - borrowed maize. 4 rows added, each labelled in `calendar_source`.**
- Ashanti, Brong Ahafo: the national main-season maize row (decided in Phase 1).
- Upper East, Upper West: Northern region's maize row - harvest dekads 33-36, late November to
  December. The national row (harvest July-August, the southern main season) was rejected: in
  the north that is the lean season.
- Borrowed rows have an empty `region_published`: no source published them.
- Limitation for the memo: Northern's row is labelled "Maize (Second)" in a one-season region.

**C4 - harvests crossing New Year. 7 rows flagged `harvest_crosses_year`.** All second-season
maize in the south. Dekads left as published; any window calculation must check the flag.

Not filled, on purpose: Upper East and Upper West cassava; millet, sorghum and rice in southern
markets (consuming markets, used by Project B).

---

## FAOSTAT (`data/clean/faostat_qcl.csv`, 1,536 rows)

**F1.** Item code read as text, so 01520.01 keeps its leading zero. **The CSV does not
remember that: every later read, including the Phase 4 load, must read `item_code` as text
again.** Dropped five columns holding one value each (Domain Code, Domain, Area Code, Area)
or duplicating another (Year Code = Year), each checked before dropping. Note kept: 34 rows
say "Unofficial figure". Names changed to snake_case.

**F2. 150 blank values kept blank.** All cowpeas, 1961-2010, with no flag. All eight items
kept. The Flag column survives; 2022-2023 values for the Project A crops are mostly not
official and must be labelled where they are used.

---

## Bank of Ghana (`data/clean/bog_policy_rate.csv`, 130 rows)

**B1.** `effective_date` parsed and used as the key: unique and in order. Meeting No. 107
appears twice - a July meeting and an August emergency meeting, different dates and rates.
Both kept, nothing flagged: a repeated value in a column that isn't the key is not a duplicate.

**B2. No monthly series here.** One row per decision. Building a monthly rate is a modelling
choice (which rate applies in a month with a mid-month decision) and is made in Phase 4 with
`fact_rate`'s grain.

---

## Not acted on

**Repeated prices.** 8,757 rows equal the previous month's price in the same series (Project
A wholesale: 19.1% before 2019, 28.0% from 2019). Some are real, some may be carried forward
by the publisher; the file can't say which. No rule; a limitation for the memo.

---

## What went wrong during cleaning

- **The coverage table first hid the gaps it was built to show.** The first version listed
  only years that had prices, so Wa millet 2019 (0 months) was absent rather than 0. Caught by
  checking the output against Phase 2's Wa counts before the code was handed over; fixed by
  listing every year in each series' span. 229 empty series-years would otherwise be missing.
- **A tautological check.** The first calendar reconciliation compared a total with itself
  and could never fail. Replaced before hand-over with a check that observed rows equal the
  Ghana raw rows and borrowed rows equal 4.
- **A backslash in the script's opening comment** raised a Python warning. Caught by running
  with warnings treated as errors; the run command in the comment now uses forward slashes.

---

## Carried to Phase 4

- `fact_price` key: market, commodity, unit, price type, month (P5).
- Read `item_code` as text in the load (F1).
- FAOSTAT's BOM is in the raw file only. The clean file has none (checked: it starts with the
  bytes of "element_code"), so the Phase 4 load, which reads the clean file, does not meet it.
- Monthly policy rate (B2).
