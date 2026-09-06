# Raw CBK pulls — why there is more than one vintage

## The problem

CBK publishes its time series as Excel files at fixed URLs under
`bqk-kos.org/repository/docs/time_series/`. When a series is revised, **the file
at the same URL is replaced**. There is no archive, no version parameter, and no
way to request a previous release. A re-pull overwrites the previous data
irreversibly.

That matters for this piece more than it usually would, because CBK has
announced a revision to the single most important non-remittance component of
the diaspora account.

## The announced revision

From the note at the bottom of the `BOP` sheet in
`26 Balance of payments - main components.xls` (row 259), reproduced verbatim:

> The Balance of Payments statistics for the services component, particularly
> travel services, have been revised following the integration of:
> • data from three surveys of non-residents conducted in 2025, including two
> during the summer season and one during the winter season; and
> • additional information on travel expenditures obtained from counterpart
> banks and relevant institutions in neighboring countries through electronic
> communication and official publications, in which Kosovo appears as a
> counterpart country.
>
> It is also important to highlight that, in addition to the regular revisions
> for 2025, **revised services statistics for the years 2021–2024 will be
> published in September 2026**. These revisions are carried out in accordance
> with Article 4 of the Statistical Revisions Policy. Such revisions are
> necessary because the newly acquired information from non-resident surveys and
> comparative data from neighboring countries also affect the time series of
> earlier periods.

The same note appears in Albanian in `27 Services.xls`
(sheet `BiP - Services`, row 256) and `26a Current account.xls` (row 256).

Travel services is the component the IMF's consolidated diaspora estimate
applies its 92% diaspora share to. A revision to it moves the headline figure
directly.

## Layout

```
data/raw/
  README.md                  this file
  reference/                 IMF CR 21/41 — documentation, not a CBK vintage
  vintage_2026-08/           pulled 2026-08-13 — 13 files + _download_log.csv
  vintage_2026-09/           pulled 2026-09-05 — 13 files + _download_log.csv
  ask/                       ASK PxWeb pulls (not vintaged; see below)
  <13 loose files>           first pull, before vintaging was introduced
```

Each `vintage_YYYY-MM/` holds the twelve CBK Excel workbooks, the CBK BOP/IIP
compilation methodology PDF, and a `_download_log.csv` recording for every file:
source URL, download timestamp, the server's `Last-Modified` header, byte size
and MD5.

`R/02_pull_cbk.R` writes only inside the active vintage and asserts before
exiting that no sibling vintage was modified. Pass a vintage explicitly with
`Rscript R/02_pull_cbk.R 2026-09`; it defaults to the current month.

The loose files at the top level are the original pull, made before vintaging
was introduced. They are byte-identical to `vintage_2026-08/` (verified by MD5
against the download-time checksums). They are kept because the house rule is
that a raw file is never deleted; `vintage_2026-08/` is the canonical copy.

## What changed between the vintages

**vintage_2026-08** — pulled 2026-08-13, 12 workbooks plus the methodology PDF.
Server `Last-Modified` dates run 2026-07-30 to 2026-08-11, except
`27.1 Services by country and activity.xls` (2025-10-01, an annual publication
covering 2018–2024 only) and the methodology PDF (2025-07-11).

**vintage_2026-09** — pulled 2026-09-05, 12 workbooks plus the methodology PDF.
Server `Last-Modified` dates run 2026-08-28 to 2026-08-31 for ten of the twelve
workbooks; `27.1` (2025-10-01) and `34a` (2026-06-29) were not republished, and
neither was the methodology PDF.

### Nothing in any annual series changed

Ten of the twelve workbooks differ from the August vintage by MD5, and every
sheet grew by exactly two rows. **No annual value moved.**

| Comparison | Compared | Moved |
|---|---|---|
| Annual cells, all columns, six workbooks | 3,109 | **0** |
| Annual component-years, the seven mapped series | 143 | **0** |
| Sub-annual observations overlapping both vintages | 1,466 | **0** |

The cell sweep covered every column of `26`, `27`, `28`, `29`, `30` and `33.1`
over their full annual blocks — not only the columns this piece reads — so the
result is not an artefact of looking in the wrong place.

**The only difference between the two vintages is 12 new sub-annual
observations**: June 2026 monthly and 2026-Q2 quarterly, across six series. That
is the routine monthly update. The files were rewritten; the history was not.

### The announced 2021–2024 services revision has not been applied

Travel services credits are unchanged to the last decimal:

```
2021  1490.095 -> 1490.095      2023  2206.985 -> 2206.985
2022  1875.274 -> 1875.274      2024  2425.249 -> 2425.249
```

The revision note in `26 Balance of payments - main components.xls` is
**identical between the two vintages** and still reads in the future tense —
"revised services statistics for the years 2021–2024 **will be published in
September 2026**". The tail rows of `27` and `29` differ only in the trailing
period label advancing from `Maj` to `Qershor` as June was appended; their note
text is unchanged. No new note appears in any of the three.

Every 2021–2024 figure therefore remains **provisional**, on the September
vintage exactly as on the August one, and the pipeline continues to flag it as
such. Next check scheduled for 20 October 2026.

### Guard behaviour across the vintage change

Every structural guard held on the new vintage: identical annual block bounds,
identical BPM6 codes, identical period-label conventions, and cross-file
deviations identical to four decimal places — including the 2.000 EUR million
services discrepancy between `26` and `27` in 2025, which reproduced itself with
both files now timestamped 31 August but 1h25m apart. The sub-annual discrepancy
registry is unchanged: all three entries remain active with deviations identical
to six decimals, so none is stale.

## Consequence for the analysis

- The IMF benchmark years (2018–2020) sit **outside** the announced revision
  window, so the replication check against the published ~37% / ~29% of GDP
  figures can be built on `vintage_2026-08` and is not expected to move.
- Everything **2021–2024 is provisional** pending the revision, and is labelled
  as such in intermediate outputs so it cannot silently reach a figure.
- **Publication does not wait for the revision.** The piece is built on
  `vintage_2026-09` and truncated at 2020, which is outside the revision window
  and has now been shown stable across two vintages. The 2021–2024 years stay
  out of every figure until the revision lands and the vintages are compared.
