"""
clean.py - Phase 3 cleaning for the Agri-Finance build.

Reads the six raw files in data/raw/, applies the rules agreed in
docs/CLEANING-SPEC.md, and writes clean files to data/clean/.

Run from the project folder in PowerShell:
    .venv/Scripts/python.exe src/clean.py
"""

import hashlib
from pathlib import Path

import pandas as pd


# ---------------------------------------------------------------
# SECTION 1 - Paths, raw-file check, and the log
# ---------------------------------------------------------------

# Find the project folder from where THIS FILE lives, not from where
# the command was typed. src/clean.py -> parent is src/ -> parent is
# the project folder. In Phase 2 the notebook used Path(".."), which
# depends on the current folder, and it broke when the notebook moved.
ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
CLEAN = ROOT / "data" / "clean"
DOCS = ROOT / "docs"

# Recorded in docs/SOURCES.md at acquisition. If any raw file has
# changed by even one byte, cleaning must not run on it.
EXPECTED_MD5 = {
    "wfp_food_prices_gha.csv": "1e3aed1c5551f38375b744852baabb4f",
    "wfp_markets_gha.csv":     "e234287b980bf36fc165dcfdba914825",
    "crop_calendar_gaul0.csv": "4430991cb6c58b82cea25cf5af503047",
    "crop_calendar_gaul1.csv": "86e9b947093c790f1af5949e79b8cb7e",
    "faostat_qcl_ghana.csv":   "e42769d1b60bcabe8dc8d42d2ef712b0",
    "bog_policy_rate.csv":     "dc7fa3634497158e9aa730643c204e95",
}

# Every rule adds one entry here. At the end this becomes
# docs/cleaning_log.csv - the counts the prose log is written from.
LOG = []


def log(rule, file, rows_in, rows_affected, rows_out, action):
    """Record what one rule did, with counts, and print it."""
    LOG.append({
        "rule": rule,
        "file": file,
        "rows_in": rows_in,
        "rows_affected": rows_affected,
        "rows_out": rows_out,
        "action": action,
    })
    print(f"[{rule}] {file}: in {rows_in:,} | affected {rows_affected:,} "
          f"| out {rows_out:,} | {action}")


def check_raw():
    """Stop the script if any raw file differs from SOURCES.md."""
    for name, expected in EXPECTED_MD5.items():
        actual = hashlib.md5((RAW / name).read_bytes()).hexdigest()
        print(f"{name:26s} {'OK' if actual == expected else 'CHANGED'}")
        assert actual == expected, f"{name} has changed since acquisition"

# ---------------------------------------------------------------
# SECTION 2 - Prices: read, date to month (P3), drop 2014-only markets (P1)
# ---------------------------------------------------------------

def read_prices():
    """Read the raw price file and confirm it is the shape SOURCES.md recorded."""
    p = pd.read_csv(RAW / "wfp_food_prices_gha.csv")
    assert p.shape == (37_765, 16), f"unexpected shape {p.shape}"
    return p


def p3_date_to_month(p):
    """P3: every date is the 15th, a stamp rather than a survey day.
    Replace it with the first day of its month so later joins to a
    month table match."""
    rows_in = len(p)
    # An explicit format makes pandas stop on any odd date instead of guessing.
    d = pd.to_datetime(p["date"], format="%Y-%m-%d")
    # The rule is only safe if Phase 2's finding still holds: all on the 15th.
    assert (d.dt.day == 15).all(), "a date is not on the 15th - re-check P3"
    month = d.dt.to_period("M").dt.to_timestamp()   # 2006-01-15 -> 2006-01-01
    p = p.drop(columns="date")
    p.insert(0, "month", month)                      # put it back as the first column
    log("P3", "prices", rows_in, rows_in, len(p),
        "date replaced by month (first day); every date was the 15th")
    return p


def p1_drop_2014_only_markets(p):
    """P1 (Rule A, decided in Phase 1): drop markets whose only year is 2014.
    The only rule in Phase 3 that removes rows."""
    rows_in = len(p)
    year = p["month"].dt.year

    # Method 1: a market whose first AND last year are both 2014.
    span = year.groupby(p["market_id"]).agg(["min", "max"])
    only_2014 = span[(span["min"] == 2014) & (span["max"] == 2014)].index
    drop = p["market_id"].isin(only_2014)

    # Method 2 (check 3 in the spec), written a different way on purpose:
    # keep any market seen in a year other than 2014; count the rest.
    seen_outside_2014 = set(p.loc[year != 2014, "market_id"])
    independent = int((~p["market_id"].isin(seen_outside_2014)).sum())

    # Both methods must agree with each other and with Phase 1's count.
    assert len(only_2014) == 24, f"expected 24 markets, found {len(only_2014)}"
    assert int(drop.sum()) == independent == 89, "P1 counts disagree"

    # Never drop silently: keep the removed rows in interim so
    # raw = clean + excluded can be checked at the end.
    p[drop].assign(excluded_by="P1").to_csv(
        ROOT / "data" / "interim" / "excluded_prices.csv", index=False)

    p = p[~drop].reset_index(drop=True)
    log("P1", "prices", rows_in, int(drop.sum()), len(p),
        f"dropped {len(only_2014)} markets present only in 2014; "
        f"{p['market_id'].nunique()} markets remain")
    return p

# ---------------------------------------------------------------
# SECTION 3 - Prices: price per kg (P4), remove usdprice (P6)
# ---------------------------------------------------------------

def p4_price_per_kg(p):
    """P4: units mix bag sizes ("91 KG"), single kilos ("KG") and units with
    no weight ("Bunch", "100 Tubers", "30 pcs"). Add the bag weight and a
    price per kg. Rows with no weight are kept with both left empty."""
    rows_in = len(p)

    # Read the number out of units like "91 KG". Units that don't match
    # the pattern (Bunch, Tubers, pcs, and plain "KG") come back empty.
    unit_kg = p["unit"].str.extract(r"^(\d+) KG$")[0].astype(float)
    unit_kg[p["unit"] == "KG"] = 1.0          # retail "KG" means one kilo
    p["unit_kg"] = unit_kg
    p["price_per_kg"] = p["price"] / p["unit_kg"]   # empty stays empty

    # The only units allowed to have no weight are the three Phase 2 found.
    no_weight = p["unit_kg"].isna()
    assert set(p.loc[no_weight, "unit"]) == {"Bunch", "100 Tubers", "30 pcs"}
    assert int(no_weight.sum()) == 4_946, f"{int(no_weight.sum())} rows with no weight"

    # Check 5 in the spec: one value worked out by hand beforehand.
    # Kumasi cassava, wholesale, January 2006: 10.31 cedis per 91 KG bag.
    one = p[(p["market"] == "Kumasi") & (p["commodity"] == "Cassava")
            & (p["pricetype"] == "Wholesale") & (p["month"] == "2006-01-01")]
    assert len(one) == 1 and round(one["price_per_kg"].iloc[0], 4) == 0.1133

    log("P4", "prices", rows_in, int(no_weight.sum()), len(p),
        "added unit_kg and price_per_kg; rows with no weight kept, per-kg left empty")
    return p


def p6_remove_usdprice(p):
    """P6: usdprice is wrong in 92 rows (10x or 100x, Phase 2). Nothing in
    either project uses dollars, and raw still has the column."""
    rows_in = len(p)
    p = p.drop(columns="usdprice")
    log("P6", "prices", rows_in, rows_in, len(p),
        "usdprice column removed; 92 values were wrong by 10x or 100x")
    return p


# ---------------------------------------------------------------
# SECTION 4 - Prices: flags for outliers (P7), suspect cassava
#             series (P8) and per-kg prices under bag units (P9)
# ---------------------------------------------------------------

# One price series = one market, one commodity, one unit, one price type.
# Every comparison in this section is made inside a series, never across.
SERIES = ["market_id", "commodity_id", "unit", "pricetype"]


def p7_outlier_flags(p):
    """P7: compare each price with the median of the 7 prices around it
    in its own series. Flag above 2x or below 0.5x. Flag, never drop."""
    rows_in = len(p)

    # Rolling windows need the rows in time order inside each series.
    # The clean file keeps this order: series by series, month by month.
    p = p.sort_values(SERIES + ["month"]).reset_index(drop=True)

    # 7 prices centred on this one (3 before, itself, 3 after). Where months
    # are missing, the 7 prices span more than 7 months - same as Phase 2.
    # min_periods=3: with fewer than 3 prices the median means little.
    median7 = p.groupby(SERIES)["price"].transform(
        lambda s: s.rolling(7, center=True, min_periods=3).median())
    p["outlier_ratio"] = p["price"] / median7

    # True / False where the ratio exists; empty (NA) where it couldn't be
    # tested. "Not tested" is different from "tested and fine".
    p["outlier_flag"] = ((p["outlier_ratio"] > 2) | (p["outlier_ratio"] < 0.5)).astype("boolean")
    p.loc[p["outlier_ratio"].isna(), "outlier_flag"] = pd.NA

    flagged = int(p["outlier_flag"].sum())
    untested = int(p["outlier_flag"].isna().sum())
    assert flagged == 2_005 and untested == 38, (flagged, untested)

    # The spec promised to list the Project A wholesale flags outside cassava.
    a_crops = ["Maize", "Millet", "Sorghum", "Rice (local)"]
    listed = p[(p["outlier_flag"] == True) & (p["pricetype"] == "Wholesale")
               & p["commodity"].isin(a_crops)]
    print("   Project A wholesale flags outside cassava:")
    print(listed[["month", "market", "commodity", "unit", "price", "outlier_ratio"]]
          .round({"outlier_ratio": 2}).to_string(index=False))
    


    
    log("P7", "prices", rows_in, flagged, len(p),
        f"outlier_flag added; {flagged} flagged, {untested} could not be tested; none dropped")
    return p


def p8_suspect_cassava(p):
    """P8 (Hardy's pick): mark every cassava wholesale price from 2019 as a
    suspect series. Wholesale above retail per kg, 11.6% flag rate."""
    rows_in = len(p)
    p["series_suspect"] = ((p["commodity"] == "Cassava")
                           & (p["pricetype"] == "Wholesale")
                           & (p["month"].dt.year >= 2019))
    n = int(p["series_suspect"].sum())
    assert n == 473, n
    log("P8", "prices", rows_in, n, len(p),
        "series_suspect added: cassava wholesale from 2019; rows kept")
    return p


def p9_unit_suspect(p):
    """P9: a few bag-unit rows look like per-kg prices: the series median
    divided by the price comes out close to the bag weight. Flag, don't fix."""
    rows_in = len(p)
    series_median = p.groupby(SERIES)["price"].transform("median")
    times_off = series_median / p["price"]          # how many times below normal
    is_bag = p["unit_kg"] > 1
    # within 15% of the bag weight, e.g. a 73 KG bag priced ~73x too low
    p["unit_suspect"] = is_bag & (times_off / p["unit_kg"]).between(0.85, 1.15)
    n = int(p["unit_suspect"].sum())
    assert n == 15, n
    log("P9", "prices", rows_in, n, len(p),
        "unit_suspect added: bag-unit prices that look per-kg; not corrected")
    return p

# ---------------------------------------------------------------
# SECTION 5 - Prices: crop names (X2), coverage table (P10), write files
# ---------------------------------------------------------------

# X2: the same crop has a different name in each file. Written once here,
# used for prices now and for the calendar and FAOSTAT later.
# Anything not listed (Rice (imported), Yam (puna), ...) gets no crop.
CROPS = {
    "maize":   {"prices": ["Maize"],        "calendar": ["Maize (South/Main)", "Maize (Second)"], "faostat": ["Maize (corn)"]},
    "millet":  {"prices": ["Millet"],       "calendar": ["Millet"],                 "faostat": ["Millet"]},
    "sorghum": {"prices": ["Sorghum"],      "calendar": ["Sorghum"],                "faostat": ["Sorghum"]},
    "rice":    {"prices": ["Rice (local)"], "calendar": ["Rice (North)"],           "faostat": ["Rice"]},
    "cassava": {"prices": ["Cassava"],      "calendar": ["Cassava (Year1, year2)"], "faostat": ["Cassava, fresh"]},
    "yam":     {"prices": ["Yam"],          "calendar": ["Yams"],                   "faostat": ["Yams"]},
}


def crop_names(source):
    """Turn CROPS into a lookup for one file: {name in that file: crop}."""
    return {name: crop for crop, files in CROPS.items() for name in files[source]}


def x2_add_crop(p):
    """X2: add a standard crop column so prices, calendar and FAOSTAT can be joined."""
    rows_in = len(p)
    p["crop"] = p["commodity"].map(crop_names("prices"))
    # Every crop must actually be found - a typo in CROPS would otherwise
    # just leave that crop empty, silently (the isin() lesson from Phase 2).
    assert set(p["crop"].dropna()) == set(CROPS), set(CROPS) - set(p["crop"].dropna())
    n = int(p["crop"].notna().sum())
    log("X2", "prices", rows_in, n, len(p),
        f"crop column added for the 6 scope crops; {rows_in - n:,} other rows left empty")
    return p


def p10_coverage(p):
    """P10: no filling of missing months. Instead, record how many months
    each series actually has in each year, so Phase 5 can filter on it.
    Years with NO prices are listed too, as 0 - a coverage table that only
    shows what is present would hide exactly the gaps it exists to show."""
    keys = ["market_id", "market", "commodity", "unit", "pricetype"]
    p = p.assign(year=p["month"].dt.year)

    # Months present in each year that has at least one price.
    counts = (p.groupby(keys + ["year"])["month"].nunique()
                .rename("months_present").reset_index())

    # Every year from each series' first year to its last, with or without prices.
    spans = counts.groupby(keys)["year"].agg(["min", "max"]).reset_index()
    spans["year"] = [list(range(a, b + 1)) for a, b in zip(spans["min"], spans["max"])]
    grid = spans.drop(columns=["min", "max"]).explode("year")
    grid["year"] = grid["year"].astype(int)

    # Years in the grid with no prices get 0, not a missing value.
    cov = grid.merge(counts, on=keys + ["year"], how="left")
    cov["months_present"] = cov["months_present"].fillna(0).astype(int)

    # Checks: each price row is one series-month, so the months must add
    # back up to the row count; and Phase 2's hand-found gap must show as 0.
    assert cov["months_present"].sum() == len(p)
    wa = cov[(cov["market"] == "Wa") & (cov["commodity"] == "Millet")
             & (cov["pricetype"] == "Wholesale") & (cov["year"] == 2019)]
    assert wa["months_present"].tolist() == [0], wa

    cov.to_csv(CLEAN / "price_coverage.csv", index=False)
    empty = int((cov["months_present"] == 0).sum())
    log("P10", "price_coverage", len(p), empty, len(cov),
        f"no months filled; {len(cov):,} series-years written, {empty} of them with 0 months")
    return cov


def write_prices(p):
    p.to_csv(CLEAN / "prices.csv", index=False, date_format="%Y-%m-%d")
    print(f"   wrote data/clean/prices.csv: {len(p):,} rows x {p.shape[1]} columns")

# ---------------------------------------------------------------
# SECTION 6 - Markets file (P2)
# ---------------------------------------------------------------

def p2_markets(prices):
    """P2: keep only markets that still have prices after P1, and flag the
    short-panel markets. Works from the clean prices, so the two files
    can never disagree about which markets exist."""
    m = pd.read_csv(RAW / "wfp_markets_gha.csv")
    assert m.shape == (93, 7), m.shape
    rows_in = len(m)

    years = prices.groupby("market_id")["month"].agg(lambda s: s.dt.year.nunique())
    priced = set(years.index)
    keep = m["market_id"].isin(priced)

    # Why each removed market goes, recorded rather than just counted.
    p1_ids = set(pd.read_csv(ROOT / "data" / "interim" / "excluded_prices.csv")["market_id"])
    removed = m[~keep].copy()
    removed["excluded_by"] = ["P1: only in 2014" if i in p1_ids else "P2: no prices"
                              for i in removed["market_id"]]
    removed.to_csv(ROOT / "data" / "interim" / "excluded_markets.csv", index=False)
    print("   removed markets by reason:", removed["excluded_by"].value_counts().to_dict())

    m = m[keep].reset_index(drop=True)
    # Short panel: 8 or fewer years with prices. Phase 1 found no market
    # with 9-14 years, so any cutoff from 9 to 15 gives the same five.
    m["short_panel"] = m["market_id"].map(years) <= 8
    short = set(m.loc[m["short_panel"], "market"])
    assert short == {"Kintampo", "Hohoe", "Garu", "Yendi", "Nkwanta"}, short
    assert len(m) == 20

    m.to_csv(CLEAN / "markets.csv", index=False)
    log("P2", "markets", rows_in, rows_in - len(m), len(m),
        "kept markets with prices; short_panel flag on 5")
    return m

# ---------------------------------------------------------------
# SECTION 7 - Crop calendar (C1 read, C2 regions, C3 borrowed rows,
#             C4 New-Year harvests)
# ---------------------------------------------------------------

def c1_read_calendar():
    """C1: semicolon file whose header ends in a comma. Keep Ghana only."""
    cal = pd.read_csv(RAW / "crop_calendar_gaul1.csv", sep=";")
    assert cal.shape == (3_068, 9), cal.shape
    rows_in = len(cal)

    # C1a: rename the last column.
    cal = cal.rename(columns={"eos_e,": "eos_e"})
    # C1b: strip the trailing comma from every value, then make it a whole number.
    cal["eos_e"] = cal["eos_e"].astype(str).str.rstrip(",").astype(int)

    cal = cal[cal["name0_shr"] == "Ghana"].reset_index(drop=True)
    assert len(cal) == 34
    log("C1", "calendar", rows_in, rows_in - len(cal), len(cal),
        "read with sep=';'; eos_e renamed, comma stripped, made whole numbers; Ghana rows kept")
    return cal


def c2_regions(cal, prices):
    """C2: upper-case the region names and map WEST -> WESTERN so they match prices."""
    rows_in = len(cal)
    cal["region"] = cal["name1_shr"].str.upper().replace({"WEST": "WESTERN"})
    # Every calendar region must exist in the prices, and the other way round.
    assert set(cal["region"]) == set(prices["admin1"]), set(cal["region"]) ^ set(prices["admin1"])
    log("C2", "calendar", rows_in, int((cal["name1_shr"] == "West").sum()), len(cal),
        "regions upper-cased; West -> WESTERN; all 10 match prices")
    return cal


def c3_borrowed_maize(cal):
    """C3: add the 4 maize rows the calendar lacks, each labelled with where it
    was borrowed from. a) Ashanti, Brong Ahafo: national main-season row.
    b) Upper East, Upper West: Northern region's maize row (Hardy's batch pick)."""
    rows_in = len(cal)
    cal["calendar_source"] = "observed"

    national = pd.read_csv(RAW / "crop_calendar_gaul0.csv", sep=";")
    nat_main = national[(national["name0_shr"] == "Ghana")
                        & (national["crop_name"] == "Maize (South/Main)")]
    north = cal[(cal["region"] == "NORTHERN") & cal["crop_name"].str.startswith("Maize")]
    assert len(nat_main) == 1 and len(north) == 1

    dekads = ["crop_name", "sos_s", "sos_e", "eos_s", "eos_e"]
    borrowed = []
    for region in ["ASHANTI", "BRONG AHAFO"]:
        borrowed.append(nat_main[dekads].assign(region=region,
                        calendar_source="borrowed: national main-season maize"))
    for region in ["UPPER EAST", "UPPER WEST"]:
        borrowed.append(north[dekads].assign(region=region,
                        calendar_source="borrowed: Northern region maize"))

    cal = pd.concat([cal] + borrowed, ignore_index=True)
    assert len(cal) == 38
    log("C3", "calendar", rows_in, len(cal) - rows_in, len(cal),
        "4 maize rows borrowed and labelled in calendar_source; 34 observed")
    return cal


def c4_year_wrap(cal):
    """C4: keep dekads as published; flag harvests that end in the next year."""
    rows_in = len(cal)
    cal["harvest_crosses_year"] = cal["eos_e"] < cal["eos_s"]
    n = int(cal["harvest_crosses_year"].sum())
    assert n == 7, n
    log("C4", "calendar", rows_in, n, len(cal),
        "harvest_crosses_year added; dekads left as published")
    return cal


def write_calendar(cal):
    cal["crop"] = cal["crop_name"].map(crop_names("calendar"))     # X2
    assert set(cal["crop"].dropna()) == set(CROPS)
    cal = cal.rename(columns={"name1_shr": "region_published"})
    cols = ["region", "region_published", "crop", "crop_name", "sos_s", "sos_e",
            "eos_s", "eos_e", "harvest_crosses_year", "calendar_source"]
    cal = cal[cols]
    assert not cal.duplicated(["region", "crop_name"]).any()       # check 4: key unique
    cal.to_csv(CLEAN / "crop_calendar.csv", index=False)
    print(f"   wrote data/clean/crop_calendar.csv: {len(cal)} rows")
    return cal

# ---------------------------------------------------------------
# SECTION 8 - FAOSTAT (F1, F2) and Bank of Ghana (B1)
# ---------------------------------------------------------------

def f1_f2_faostat():
    """F1: item code read as text; drop columns that carry no information;
    snake_case names (X1). F2: keep every row - blanks stay blank, Flag kept."""
    # dtype=str for the item code: read as a number, 01520.01 becomes 1520.01.
    f = pd.read_csv(RAW / "faostat_qcl_ghana.csv", dtype={"Item Code (CPC)": "str"})
    assert f.shape == (1_536, 15), f.shape
    rows_in = len(f)
    assert f["Item Code (CPC)"].str.startswith("0").any()     # the zeros survived

    # F1: only drop a column while it is still true that it carries nothing.
    single = ["Domain Code", "Domain", "Area Code (M49)", "Area"]
    assert all(f[c].nunique() == 1 for c in single)
    assert (f["Year Code"] == f["Year"]).all()
    f = f.drop(columns=single + ["Year Code"])

    # X1: names SQL Server can use without square brackets.
    f = f.rename(columns={
        "Element Code": "element_code", "Element": "element",
        "Item Code (CPC)": "item_code", "Item": "item", "Year": "year",
        "Unit": "unit", "Value": "value", "Flag": "flag",
        "Flag Description": "flag_description", "Note": "note"})
    log("F1", "faostat", rows_in, rows_in, len(f),
        "item code kept as text; 5 single-value columns dropped; Note kept")

    # F2: the 150 blanks are cowpeas 1961-2010 with no flag. Keep them blank.
    blank = f["value"].isna()
    assert int(blank.sum()) == 150
    assert set(f.loc[blank, "item"]) == {"Cow peas, dry"} and f.loc[blank, "flag"].isna().all()
    log("F2", "faostat", len(f), int(blank.sum()), len(f),
        "all 8 items kept; 150 blank values left blank (not zero); flag kept")

    f["crop"] = f["item"].map(crop_names("faostat"))              # X2
    assert set(f["crop"].dropna()) == set(CROPS)
    assert not f.duplicated(["item_code", "element", "year"]).any()   # check 4
    f.to_csv(CLEAN / "faostat_qcl.csv", index=False)
    print(f"   wrote data/clean/faostat_qcl.csv: {len(f):,} rows")
    return f


def b1_bog():
    """B1: Effective Date is the key (Meeting No. 107 appears twice).
    One row per decision; the monthly series is built in Phase 4 (B2)."""
    b = pd.read_csv(RAW / "bog_policy_rate.csv")
    assert b.shape == (130, 4), b.shape
    b = b.rename(columns={"Meeting No.": "meeting_no", "MPC Dates": "mpc_dates",
                          "Effective Date": "effective_date", "BOG Policy Rate": "policy_rate"})
    b["effective_date"] = pd.to_datetime(b["effective_date"], format="%d %b %Y")
    assert b["effective_date"].is_unique and b["effective_date"].is_monotonic_increasing
    b = b[["effective_date", "policy_rate", "meeting_no", "mpc_dates"]]   # key first
    b.to_csv(CLEAN / "bog_policy_rate.csv", index=False, date_format="%Y-%m-%d")
    log("B1", "bog", len(b), 0, len(b),
        "effective_date parsed and used as key; one row per decision; no monthly fill")
    return b

# ---------------------------------------------------------------
# SECTION 9 - Final checks and the cleaning log
# ---------------------------------------------------------------
# Every check here reads the files back FROM DISK. Checking the variables
# in memory would only prove the code agrees with itself; reading the
# written files proves what a later phase will actually receive.

def check_reconciliation():
    """Check 2: raw rows = clean rows + excluded rows, per file, and the
    excluded rows broken down by reason re-sum to the excluded total."""
    raw_prices = len(pd.read_csv(RAW / "wfp_food_prices_gha.csv"))
    clean_prices = len(pd.read_csv(CLEAN / "prices.csv"))
    ex = pd.read_csv(ROOT / "data" / "interim" / "excluded_prices.csv")
    assert raw_prices == clean_prices + len(ex), "prices do not reconcile"
    assert ex["excluded_by"].value_counts().sum() == len(ex)
    print(f"   prices:   {raw_prices:,} raw = {clean_prices:,} clean + {len(ex)} excluded "
          f"{ex['excluded_by'].value_counts().to_dict()}")

    raw_m = len(pd.read_csv(RAW / "wfp_markets_gha.csv"))
    clean_m = len(pd.read_csv(CLEAN / "markets.csv"))
    exm = pd.read_csv(ROOT / "data" / "interim" / "excluded_markets.csv")
    by_reason = exm["excluded_by"].value_counts()
    assert raw_m == clean_m + len(exm) and by_reason.sum() == len(exm)
    print(f"   markets:  {raw_m} raw = {clean_m} clean + {len(exm)} excluded {by_reason.to_dict()}")

    raw_c = pd.read_csv(RAW / "crop_calendar_gaul1.csv", sep=";")
    clean_c = pd.read_csv(CLEAN / "crop_calendar.csv")
    ghana = int((raw_c["name0_shr"] == "Ghana").sum())
    observed = int((clean_c["calendar_source"] == "observed").sum())
    borrowed = int(clean_c["calendar_source"].str.startswith("borrowed").sum())
    # Every observed row must be a Ghana raw row, and the rest must be the 4 borrowed.
    assert observed == ghana and borrowed == 4 and len(clean_c) == observed + borrowed
    print(f"   calendar: {len(raw_c):,} raw = {ghana} Ghana + {len(raw_c) - ghana:,} other countries; "
          f"clean {len(clean_c)} = {observed} observed + {borrowed} borrowed")

    for raw_name, clean_name in [("faostat_qcl_ghana.csv", "faostat_qcl.csv"),
                                 ("bog_policy_rate.csv", "bog_policy_rate.csv")]:
        r, c = len(pd.read_csv(RAW / raw_name)), len(pd.read_csv(CLEAN / clean_name))
        assert r == c, (raw_name, r, c)
        print(f"   {clean_name}: {r:,} raw = {c:,} clean, none removed")


def check_prices_unchanged():
    """Check 6: for every kept row, price in the clean file equals price in raw.
    Cleaning added columns; it must not have edited a single price."""
    raw = pd.read_csv(RAW / "wfp_food_prices_gha.csv")
    raw["month"] = pd.to_datetime(raw["date"]).dt.to_period("M").dt.to_timestamp()
    clean = pd.read_csv(CLEAN / "prices.csv", parse_dates=["month"])
    key = ["month", "market_id", "commodity_id", "unit", "pricetype"]
    both = clean[key + ["price"]].merge(raw[key + ["price"]], on=key,
                                        how="left", suffixes=("_clean", "_raw"))
    assert len(both) == len(clean), "a key matched more than one raw row"
    assert both["price_raw"].notna().all(), "a clean row has no raw row"
    changed = int((both["price_clean"] != both["price_raw"]).sum())
    assert changed == 0, f"{changed} prices differ from raw"
    print(f"   prices unchanged: {len(both):,} rows compared with raw, 0 differ")


def write_log_and_hashes():
    """Write docs/cleaning_log.csv, and print an MD5 for every clean file.
    Check 7: run the script twice - the hashes must be identical."""
    pd.DataFrame(LOG).to_csv(DOCS / "cleaning_log.csv", index=False)
    print(f"   wrote docs/cleaning_log.csv: {len(LOG)} entries")
    for path in sorted(CLEAN.glob("*.csv")):
        print(f"   {path.name:22s} {hashlib.md5(path.read_bytes()).hexdigest()}")

def main():
    print("pandas", pd.__version__)
    print("project folder:", ROOT)
    check_raw()

    prices = read_prices()
    prices = p3_date_to_month(prices)
    prices = p1_drop_2014_only_markets(prices)

    prices = p4_price_per_kg(prices)
    prices = p6_remove_usdprice(prices)

    prices = p7_outlier_flags(prices)
    prices = p8_suspect_cassava(prices)
    prices = p9_unit_suspect(prices)

    prices = x2_add_crop(prices)
    p10_coverage(prices)
    write_prices(prices)
    p2_markets(prices)

    
    cal = c1_read_calendar()
    cal = c2_regions(cal, prices)
    cal = c3_borrowed_maize(cal)
    cal = c4_year_wrap(cal)
    write_calendar(cal)

    
    f1_f2_faostat()
    b1_bog()

    
    print("FINAL CHECKS")
    check_reconciliation()
    check_prices_unchanged()
    write_log_and_hashes()
    print("ALL CHECKS PASSED")

    


# Runs main() only when the file is run as a script, not when
# another file imports it (Phase 4's load script may import it).
if __name__ == "__main__":
    main()

