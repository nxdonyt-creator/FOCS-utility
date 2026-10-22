# Benchmark analysis and A/B/A specification

**Proposed design; 22 October 2026.** This is not a claim that the feature has been implemented or validated. Baseline: source/FrameAnalysis.cs and source/BenchmarkPage.cs in KKxtti 3.3.0.

## 1. What the current analyzer gets right

It bounds file/row/group input, groups by application/process/swap chain, rejects invalid intervals, uses invariant numeric parsing, distinguishes p99 milliseconds from low-FPS metrics, and warns against overinterpreting a single A/B comparison. Mean FPS is 1000 divided by the mean interval, not the arithmetic mean of instantaneous FPS. Nearest-rank p99 and a slowest-tail mean are valid descriptive choices when named explicitly.

Gaps: generic FrameTime has no proven unit/producer contract; timestamps and missing spans are not retained; sum of valid intervals can be mislabeled as capture duration; warm-up, scene changes, dropped/generated frames, capture loss, repeated-run uncertainty and experiment state are not represented.

## 2. Import contract

Support named adapters, initially PresentMon console 1.x, 2.x legacy mode and 2.6.0 default mode. Each adapter must ship real, redistributable sample headers/fixtures from that exact version and preserve producer version, arguments and SHA-256. Do not auto-map arbitrary FrameTime columns. Unknown input opens a column-mapping preview requiring explicit milliseconds/seconds and metric meaning, with no automatic verdict.

PresentMon documentation defines different clocks and stages. Brief mapping:

| Input | Interpretation for this utility |
|---|---|
| MsBetweenPresents | Application presentation cadence; not input latency |
| MsBetweenDisplayChange | Display-change interval associated with successive displayed presents |
| MsInPresentAPI | Time within Present; never label as frame cadence |
| MsUntilDisplayed | Present-to-display delay; not full system input latency |
| CPUStartTime variants | Timestamp; interpret using the pinned producer/options |
| MsCPUBusy / MsCPUWait / MsBetweenAppStart | CPU work/wait/start-cadence family; preserve each meaning |
| GPU fields | GPU activity/latency, not interchangeable with frame interval |
| DisplayedTime / FrameType / display identifiers | Keep for dropped/generated/display-layer classification |
| PC/input-latency fields | Display the documented measurement boundaries and availability |

Source: [PresentMon console documentation](https://github.com/GameTechDev/PresentMon/blob/v2.6.0/README-ConsoleApplication.md), accessed 2026-10-22. The v2.6.0 tag and exact column names were also checked; implementation must retain this producer-version binding. [PresentMon 2.6.0 release](https://github.com/GameTechDev/PresentMon/releases/tag/v2.6.0), published 2026-09-21, adds display attribution and capability reporting. Console output and the service/overlay interfaces are separate contracts; their switches are not interchangeable.

Store application, PID, swap-chain, adapter/display identity, frame class, present mode and all raw timestamp fields. Never silently pool swap chains, launchers, displays, game restarts or generated and application frames. A user can select a group; comparisons must use equivalent groups.

Parse incrementally with bounded field length, columns, line length, groups, rows and total bytes. Reject duplicate ambiguous headers, malformed quoting, locale-ambiguous numerals and mixed units. Preserve NA as unavailable rather than zero. Reject NaN, infinity and nonpositive cadence. Count every excluded row and state why. A missing span is not repaired by inventing frames.

## 3. Formulas

For n valid positive intervals x in milliseconds:

- Mean interval: sum(x)/n.
- Mean cadence FPS: 1000 / mean(x).
- p50/p95/p99: sort ascending; use index ceil(p*n)-1, clamped to 0..n-1. Store method name “nearest-rank.”
- “1% low FPS — tail mean”: k=max(1,ceil(0.01*n)); 1000 divided by the mean of the k largest intervals.
- “0.1% low FPS — tail mean”: same with 0.001, but suppress ranking if the tail contains fewer than a predeclared minimum sample count.
- “FPS at p99 interval”: 1000/p99(x), separately named. Never relabel it as the above 1% low.
- Stutter reports: counts and rates exceeding user-declared absolute thresholds and multiples of a declared target frame budget. Preserve both definitions.
- Duration: timestamp end minus timestamp start for wall duration; show sum(valid intervals) separately. Explain first/last interval convention and missing coverage.

Do not silently winsorize or remove the slowest frames: stutters are often the outcome being studied. Exclude only predeclared scene/warm-up windows, invalid measurements or documented capture errors. Keep original data and an exclusion log. Repeat the analysis with declared sensitivity windows; never choose the best-looking window after seeing the result.

Example: sorted intervals [1,2,3,4,5] have nearest-rank p99=5 ms, mean FPS=333.333..., tail-mean 1% low=200 FPS. This tiny example validates definitions, not a meaningful gaming estimate.

## 4. Experiment protocol

The MVP supports only reversible, non-security-reducing controls with a known refresh/reboot requirement.

1. **Plan:** choose one control, one game/build, one map/replay, fixed scene length, graphics settings, resolution, cap, synchronization state and primary outcome. Define minimum practical effect before capture, for example a user-chosen 2% p99 improvement. That number is an example, not a scientific universal threshold.
2. **Snapshot:** record Windows edition/build/UBR, servicing branch, driver version, adapter LUID/device, displays and refresh/HDR/VRR if detectable, power plan hash, game/config hash, tool and PresentMon version, selected control state, relevant security-state observations, temperature/power/load if available. Unknown remains unknown. Do not disable security for comparability.
3. **Stabilize:** same warm-up routine, shader-cache policy and cooling period. Avoid online-match variability where a repeatable local benchmark/replay is available. Treat shader compilation as a separately defined workload if it is the subject.
4. **A1:** capture baseline after warm-up.
5. **B:** close the game; apply one control; verify configured state and any required restart; relaunch and run identical warm-up/capture.
6. **A2:** close game; Undo; verify all resources and refresh requirements; repeat the baseline.
7. **Repeat:** one A/B/A block is exploratory. Collect independent blocks across launches; a proposed initial minimum is eight usable blocks, with more required if uncertainty remains. This is a product threshold, not proof of statistical power. Estimate sample size from a pilot.
8. **Counterbalance:** across sessions use randomized predeclared ABBA/BAAB or balanced treatment orders where restore semantics permit; maintain baseline recapture. A/B/A alone can confound treatment with time or thermal drift.
9. **Stop safely:** cancellation stops before the next write and preserves the latest journal. A failed restore invalidates the performance verdict and takes the user to recovery. Never continue collecting while silently leaving a different state.
10. **Report:** include raw files, machine context, every run, exclusions, state diffs, seed/method, uncertainty, practical threshold and restoration status.

No experiment may decrypt BitLocker, delete Recall snapshots, remove apps with unrecoverable local data, change boot debugging flags to chase FPS, or disable security/updates/mitigations. Those are excluded because the experiment requires a meaningful return to baseline.

## 5. Inferential analysis

Frames from one game run are correlated and the workload is nonstationary. Treating tens of thousands of frames as independent trials creates false precision. [NIST autocorrelation](https://www.itl.nist.gov/div898/handbook/eda/section3/eda35c.htm), handbook page, publication/update date not displayed; accessed 2026-10-22.

**Primary unit:** an independent matched block, not a frame. Compute the selected metric per run first. For lower-is-better metric m and each A1/B/A2 block:

~~~text
d_i = log(m_B) - 0.5 * (log(m_A1) + log(m_A2))
effect_percent = 100 * (exp(mean(d_i)) - 1)
~~~

Negative means improved interval/latency. This uses a geometric baseline, stated explicitly. Never combine reciprocal-FPS effects and interval effects under the same sign convention.

**Confidence interval:** resample whole independent blocks with replacement, 10,000 replicates, fixed recorded seed; recompute mean log difference; percentile bounds 2.5% and 97.5%, transformed back to percent. This is a proposed paired cluster bootstrap. If runs are nested in days/machines, resample at the independent outer level. Eight blocks can still give an unstable interval; display count and a small-sample caution, and compare with a paired run-level permutation/sensitivity analysis. Do not present the interval as exact finite-sample coverage.

**Within-run uncertainty:** optional contiguous-block bootstrap only after an explicit time-series stationarity/segment choice; it cannot replace independent reruns. Choose block length using observed correlation and sensitivity checks, not a fixed single-frame resampling assumption.

**Mann–Whitney:** optional for genuinely independent unmatched run summaries; it is not automatically a test of equal means or medians, and not appropriate for paired A/B/A frames. Use paired block analysis as primary. If testing many controls/outcomes, preselect one primary endpoint; mark secondary analyses exploratory or apply a declared multiplicity procedure.

**Minimum detectable effect:** use pilot run-level log-difference variability and the intended interval/test to simulate required block count for the chosen effect and power. A normal approximation n≈((z_alpha/2+z_power)*s_d/delta_log)^2 may be displayed as a rough planning estimate only, then checked by resampling/simulation. Pilot noise, drift and unrepresentative scenes can invalidate it.

**Verdicts for lower-is-better outcomes:**

- “Meaningful improvement observed”: upper CI is below -delta, required quality gates pass, and no predeclared secondary regression threshold is exceeded.
- “Meaningful regression observed”: lower CI is above +delta.
- “Within chosen equivalence margin”: the complete CI lies inside [-delta,+delta], under the declared interval/equivalence procedure.
- “Inconclusive”: everything else, including too few runs, unstable baseline, incomplete metadata, failed restore or capture quality failure.

“Not statistically significant” is not “no effect.” “Better average FPS” is not “lower input latency.” Software PC-latency fields do not include the complete physical mouse-to-photon path. Use an instrumented compatible game and/or external hardware for that claim. [NVIDIA PC-latency explanation](https://developer.nvidia.com/blog/understanding-and-measuring-pc-latency/), 2023-05-05.

## 6. Quality gates and developer acceptance

Proposed gates: equivalent game/process/scene/settings; stable power and display mode; no capture loss beyond declared tolerance; all clock fields understood; no unexplained missing spans; minimum number of valid blocks; A1/A2 drift assessed against a predeclared margin; valid treatment/Undo journal; no driver/OS update during a block.

Required test fixtures in the future implementation:

- Identical data yields zero effect; deterministic seed yields repeatable CI.
- Arithmetic mean of per-frame FPS differs from reciprocal mean interval; output uses the latter.
- Known nearest-rank vectors and noninteger tail sizes.
- Dropped/generated frames do not contaminate selected cadence.
- Locale, quoted CSV, huge field, duplicate header, NaN/Infinity, truncation, interleaved swap chains, zero duration and PID reuse.
- A2 drift, failed Undo, missing metadata and too few blocks produce “inconclusive.”
- Synthetic independent block shifts and strongly autocorrelated frames do not create artificial sample-size inflation.
- Importing a newer unsupported producer version requests mapping rather than silently comparing it.

These are acceptance specifications; no new test suite or runtime capture was executed as part of writing this document.
