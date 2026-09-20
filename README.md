# Agri-Finance Analytics

Two analytics products built on public Ghanaian agricultural data, aimed at
agri-lenders, agricultural insurers, aggregators and agri-SME funds.

> **Status: Phase 0 (setup) complete — environment verified, repository published.**
> **No data has been acquired yet.**
> This README is a skeleton. Each section is filled in at the phase that
> produces the material for it, not before — a README written in advance is a
> plan, and plans describe what was intended rather than what happened.

---

## The question

<!-- Filled in at Phase 1, once the data that can actually answer it is known. -->

**Project A — Smallholder repayment capacity.** Given crop, region, planting
calendar and price seasonality: when does a smallholder actually have cash, and
does a lender's repayment schedule line up with it?

**Project B — Agricultural market price intelligence.** Buying windows, the
price gap between producing and consuming markets, and flags for abnormal
movement.

Both are built on one shared data spine — same crops, same markets, same
calendar, same warehouse.

## Data sources

<!-- Filled in at Phase 1 from docs/SOURCES.md. Every source with URL,
     access date, licence and row count at acquisition. -->

All data is public and freely reusable. Raw files are not committed to this
repository — see `.gitignore` section 1 for why, and `docs/SOURCES.md` for
where each file comes from.

## Method

<!-- Filled in across Phases 2-5. -->

## Findings

<!-- Filled in at Phases 5A and 5B. Nothing goes here until it has passed an
     independent verification check. -->

## Limitations

<!-- Filled in at Phase 6, honestly and at length. -->

---

## Running this project

### Prerequisites

- Python 3.10 or later
- Git
- SQL Server (Developer Edition) and SQL Server Management Studio
- Microsoft ODBC Driver 17 or 18 for SQL Server

### Setup

```powershell
git clone https://github.com/Hardy999/agri-finance-analytics.git
cd agri-finance-analytics
.\setup.ps1
```

That is the whole thing. `setup.ps1` creates the virtual environment, installs
the exact versions recorded in `requirements.lock.txt`, detects your SQL Server
instance and ODBC driver and writes `config.ini`, then runs a connection test.
It is safe to run more than once — an existing `.venv` is reused rather than
rebuilt. Pass `-Force` to rebuild it from scratch.

**If PowerShell refuses to run it**, you will see
*"cannot be loaded because running scripts is disabled on this system"*.
Windows blocks `.ps1` files by default and the script cannot exempt itself.
Either run it this way:

```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

or allow locally-written scripts for your account, once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

<details>
<summary>Doing it by hand instead</summary>

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.lock.txt
copy config.example.ini config.ini   # then edit it for your machine
python src\db.py                     # connection test
```
</details>

### What is deliberately not in this repository

Three things are missing on purpose, each for a different reason:

- **The data.** Excluded for size, because some source licences permit use but
  not redistribution, and — the real reason — because if the data is not
  committed then getting it requires running the ingestion scripts, which
  keeps those scripts continuously proven. See `docs/SOURCES.md`.
- **`config.ini`.** Machine-specific, and the file where a password would live
  if one were ever added. `setup.ps1` generates it; `config.example.ini` is the
  committed template that documents what each setting means.
- **`.venv/`.** Thousands of files, rebuildable from `requirements.lock.txt` in
  one command.

<!-- Full end-to-end run instructions are added at Phase 7 and verified by
     cloning into a fresh folder and following them literally. -->

---

## Repository layout

```
data/raw/          source files as downloaded — immutable, never edited, gitignored
data/interim/      intermediate output while cleaning — gitignored
data/clean/        the analysable dataset — gitignored, rebuilt by running the pipeline
notebooks/         profiling and exploration
src/               ingestion, cleaning and load scripts
sql/               T-SQL: schema definitions, load procedures, analysis queries
powerbi/           the .pbix report
docs/              SOURCES.md, cleaning log, decision memo
phases/            one folder per phase, each with a Word document explaining
                   what was done in that phase and why
setup.ps1          one-command environment setup for a fresh clone
README.md
```

### Why `phases/` exists

The code shows what was done. It does not show what was rejected, what went
wrong, or why a rule was set one way rather than another — and that is the part
that matters when reconstructing this work months later, or defending it in an
interview.

Each phase folder contains a Word document written at the phase gate, while the
detail is still fresh, covering: what the phase was for, what was done step by
step, every judgement call with its rejected alternative, what went wrong, and
what the phase leaves unresolved for later phases to handle.

They are written to be read on their own, by someone who has not seen the code.

---

## Licence

<!-- Added at Phase 7. -->
