# V1 ROI Modeling Application — Strategic Plan

**Purpose:** Guide the design and build of a post-experiment ROI modeling tool for a CRO agency and its clients.
**Audience:** Engineers, product stakeholders, agency leadership.
**Status:** Pre-build strategic blueprint. No code.

---

## 1. Product Scope & V1 Definition

### Problem Statement

After a winning experiment is called, the CRO team faces a recurring gap: translating a statistically significant lift into a business-legible dollar figure that accounts for real-world conditions. Today this is done in spreadsheets, inconsistently, with no standardized decay modeling or revenue-attribution flexibility. The result is either inflated projections that erode client trust, or undervalued wins that make the program look expendable.

### What V1 Solves

- **Standardized post-test ROI projection.** One canonical way to go from "we saw X% lift" to "this is worth $Y over the next 12 months."
- **Revenue-model flexibility.** Different clients monetize differently (ecommerce AOV, SaaS ARR, lead-gen close rates). The tool adapts to each without separate spreadsheets.
- **Decay-aware forecasting.** Projections that acknowledge lift degrades over time, with adjustable assumptions rather than a single naive extrapolation.
- **Client-ready output.** Numbers, charts, and plain-language explanations that can go directly into a client report or QBR deck without manual reformatting.

### Explicitly In Scope (V1)

- Single-experiment ROI modeling (one test, one winner vs. control)
- Toggleable revenue attribution model (AOV, ARPA/ARR, revenue-per-conversion, LTV)
- Optional decay rate input with sensible defaults
- Optional sales qualification / close-rate layer (for lead-gen and SaaS funnels)
- Time-based projections: daily, monthly, quarterly, annual
- Output dashboard with headline metrics, time-series table, and at least one chart (cumulative revenue over time with decay overlay)
- Inline explanatory copy on every assumption

### Explicitly Out of Scope (Future Versions)

- Multi-experiment rollups or portfolio-level views
- Statistical confidence intervals or Bayesian projections
- Cost modeling (agency fees, dev costs, opportunity cost)
- Scenario comparison (best / expected / conservative side-by-side)
- Saved experiments, user accounts, or persistent storage
- PDF/export functionality beyond copy-paste-friendly layouts
- Real-time data integrations (analytics platforms, testing tools)

---

## 2. User Inputs (Data Model)

Inputs are organized into four groups. The UI should present them in this order, with groups visually separated.

### Group A — Experiment Metadata

| Field | Type | Required | Notes |
|---|---|---|---|
| Experiment name | Text | Optional | For labeling output only |
| Test duration | Integer (days) | Yes | How many days the experiment ran |
| Total traffic (sessions or visitors) | Integer | Yes | Total traffic across all variations during the test |
| Number of variations (including control) | Integer | Yes, default 2 | Used to calculate per-variation traffic share |

**Derived value:** Daily traffic per variation = Total traffic / Test duration / Number of variations. This is the baseline for scaling to 100% traffic.

### Group B — Conversion Performance

| Field | Type | Required | Notes |
|---|---|---|---|
| Control conversion rate | Percentage | Yes | e.g., 3.2% |
| Winning variation conversion rate | Percentage | Yes | e.g., 3.8% |
| Total conversions (winner) | Integer | Optional | Useful for sanity-checking; not strictly needed if CRs and traffic are provided |

**Derived values:**
- Absolute lift = Variation CR - Control CR
- Relative lift = (Variation CR - Control CR) / Control CR
- These are displayed back to the user for confirmation, not manually entered.

### Group C — Revenue Attribution (Toggleable)

The user selects one revenue model. The toggle changes what fields appear and how downstream revenue is calculated.

**Toggle options:**

| Mode | Fields shown | Revenue-per-incremental-conversion logic |
|---|---|---|
| **Ecommerce AOV** | Average Order Value ($) | Incremental revenue = Incremental conversions x AOV |
| **SaaS ARPA / ARR** | Average Revenue Per Account ($), Billing period (monthly/annual) | Incremental revenue = Incremental conversions x ARPA, annualized if needed |
| **Revenue per Conversion** | Flat dollar value per conversion ($) | Incremental revenue = Incremental conversions x Value |
| **Lifetime Value (LTV)** | Customer Lifetime Value ($) | Incremental revenue = Incremental conversions x LTV. Note: projections represent total lifetime value of acquired customers, not revenue realized within the projection window. The output should make this distinction explicit. |

**How the toggle affects downstream logic:** Only the revenue-per-conversion multiplier changes. The rest of the model (incremental conversions, decay, time extrapolation) stays the same. This keeps the architecture simple: the toggle selects a single scalar multiplier applied after the conversion math.

### Group D — Advanced / Optional Inputs

| Field | Type | Default | Notes |
|---|---|---|---|
| Annual decay rate | Percentage | 0% (no decay) | The percentage of lift expected to erode over 365 days. See Section 4 for decay mechanics. |
| Sales qualification rate | Percentage | 100% (every conversion = a sale) | For lead-gen or SaaS where a "conversion" is an MQL/SQL, not a closed deal. Multiplied into the revenue chain. |

**How sales qualification rate layers in:**
- Effective incremental revenue per day = Incremental conversions/day x Qualification rate x Revenue-per-conversion
- This single multiplier sits between the conversion math and the revenue math. It does not affect conversion counts, only revenue.

---

## 3. Core Calculation Logic

All logic below is conceptual. No code.

### Step 1 — Normalize to Daily Full-Traffic Baseline

The experiment ran on a fraction of total traffic (1/N variations). To project what happens when the winner gets 100% of traffic:

- **Daily total traffic** = Total traffic / Test duration
- **Daily traffic at 100%** = Daily total traffic (all traffic now goes to the winner)

This is the traffic volume the winner would see if deployed site-wide, per day.

### Step 2 — Compute Daily Conversions (Baseline vs. Winner)

- **Daily baseline conversions** = Daily traffic at 100% x Control CR
  - This is what would happen daily if nothing changed.
- **Daily winner conversions** = Daily traffic at 100% x Winning variation CR
  - This is what happens daily with the winner deployed.

### Step 3 — Compute Daily Incremental Conversions

- **Incremental conversions per day** = Daily winner conversions - Daily baseline conversions

This is the net new conversions attributable to the winning variation, per day.

### Step 4 — Compute Daily Incremental Revenue

- **Incremental revenue per day** = Incremental conversions per day x Sales qualification rate x Revenue-per-conversion (from the selected toggle)

### Step 5 — Extrapolate Over Time (Without Decay)

If decay = 0%:

| Period | Formula |
|---|---|
| Monthly (30 days) | Daily incremental revenue x 30 |
| Quarterly (90 days) | Daily incremental revenue x 90 |
| Annual (365 days) | Daily incremental revenue x 365 |

Cumulative values are simple sums over each period.

### Step 6 — Apply Decay (If Enabled)

When decay > 0%, the daily incremental value diminishes over time. See Section 4 for the decay model. The extrapolation becomes a summation of decayed daily values rather than a flat multiplication.

- **Monthly revenue** = Sum of decayed daily incremental revenue for days 1–30
- **Quarterly revenue** = Sum of decayed daily incremental revenue for days 1–90
- **Annual revenue** = Sum of decayed daily incremental revenue for days 1–365

### Step 7 — Produce Summary Outputs

The model produces:

- Total incremental conversions (per period, with and without qualification rate)
- Total incremental revenue (per period)
- Average daily incremental revenue (per period, useful for showing the decay effect)
- Relative lift held at end of each period (if decay is on)

---

## 4. Time-Based Modeling & Decay

### How Decay Works

Decay represents the empirical reality that a winning variation's lift erodes over time due to competitive shifts, audience fatigue, seasonal changes, and site-wide evolution. V1 uses a **compounding daily decay model** rather than linear decay.

**Why compounding (not linear):**
- Linear decay (lose X percentage points of lift per day) creates an abrupt cliff where lift hits zero on a specific day, which is unrealistic.
- Compounding decay (retain a fixed fraction of remaining lift each day) creates a smooth exponential curve that asymptotically approaches zero, which better matches observed CRO performance degradation. Lift fades quickly at first and slowly later.

**Mechanics:**

Given an annual decay rate of D% (e.g., 50%):

- The **annual retention factor** = 1 - D (e.g., 0.50)
- The **daily retention factor** = (1 - D)^(1/365)
- On day *t*, the effective lift = Original lift x (Daily retention factor)^t
- Incremental conversions on day *t* = Daily traffic at 100% x (Original absolute lift x (Daily retention factor)^t)
- Incremental revenue on day *t* = Incremental conversions on day *t* x Qualification rate x Revenue-per-conversion

**Example:** With 50% annual decay, the daily retention factor is approximately 0.9981. After 90 days, roughly 84% of the original lift remains. After 180 days, roughly 71%. After 365 days, exactly 50%.

### User Interaction with Decay

- **Default:** 0% decay (naive extrapolation). This is the simplest case and what most agencies use today in spreadsheets.
- **Slider or numeric input:** The user can set any value from 0% to 95%. Values above 95% produce near-zero projections and are unlikely to be useful.
- **Preset suggestions:** Offer labeled presets alongside the slider:
  - Conservative: 50% annual decay
  - Moderate: 30% annual decay
  - Optimistic: 10% annual decay
  - None: 0%
- **Projections update instantly** when the decay value changes. No "recalculate" button.

### Communicating Decay to Users

The UI should include a short educational note near the decay input, something to the effect of:

> "Experiment lift typically degrades over time as markets shift, competitors adapt, and audiences change. Industry experience suggests many experiments lose 30–50% of their original lift within 12 months. Adjusting this slider lets you model more realistic projections. A 0% decay rate assumes the lift persists indefinitely — useful as an upper bound, but rarely accurate long-term."

This is guidance, not prescription. The user retains full control.

---

## 5. UX / UI Strategy

### Overall Structure

The application is a **single-page tool** with two visually distinct zones:

1. **Input zone** (left or top): Where the user configures the model.
2. **Output zone** (right or bottom): Where results appear, updating in real time as inputs change.

There is no multi-step wizard. All inputs are visible on one screen with clear grouping. Rationale: the total number of inputs is small (8–12 fields), and CRO practitioners benefit from seeing all assumptions at once rather than navigating through steps. A wizard obscures relationships between inputs.

### Input Zone Design

- **Group A (Experiment Metadata)** at the top, collapsed or minimal since these are entered once and rarely changed.
- **Group B (Conversion Performance)** prominently placed, with derived lift values shown inline immediately below the CR inputs.
- **Group C (Revenue Model)** as a clear toggle (tabs or radio group) that swaps the relevant fields in place. The toggle label should clearly name the selected model (e.g., "Revenue Model: Ecommerce AOV").
- **Group D (Advanced)** in an expandable section labeled "Advanced assumptions" or similar. Decay slider and sales qualification rate live here.
- Every input should have a short tooltip or inline helper explaining what it is and how it affects the output. No field should be ambiguous.

### Output Zone Design

The output zone has three layers, presented vertically:

**Layer 1 — Headline Metrics (top of output)**

Four large, prominent numbers:

- Incremental conversions per day
- Incremental revenue per day
- Projected annual incremental revenue (with decay applied if set)
- Relative lift (displayed for reference)

If a sales qualification rate < 100% is set, show both "raw" incremental conversions and "qualified" conversions so the user understands the funnel step.

**Layer 2 — Time-Based Summary Table**

A compact table with rows for each time horizon:

| Period | Incremental Conversions | Incremental Revenue | Avg. Daily Revenue | Lift Remaining (if decay > 0) |
|---|---|---|---|---|
| 30 days | ... | ... | ... | ...% |
| 90 days | ... | ... | ... | ...% |
| 180 days | ... | ... | ... | ...% |
| 365 days | ... | ... | ... | ...% |

This table is the core deliverable most agencies will screenshot or copy into reports.

**Layer 3 — Visualization**

One primary chart: **Cumulative incremental revenue over 365 days.**

- X-axis: Days (0–365)
- Y-axis: Cumulative incremental revenue ($)
- Two lines:
  - Solid line: Projection with current decay setting
  - Dashed line: Projection with 0% decay (the naive upper bound)
- The gap between the lines visually communicates the cost of not accounting for decay. This is pedagogically powerful — it teaches the user why decay matters without lecturing.

Optional secondary chart (if space permits): **Daily incremental revenue over 365 days**, showing the decay curve directly. This is a declining curve from the initial daily value toward the decayed daily value at day 365.

### Inline Educational Copy

Throughout the output, short plain-language sentences explain what the numbers mean. Examples:

- Below the headline: *"If this winning variation is deployed to 100% of traffic, the model projects [X] additional conversions per day compared to the original experience."*
- Below the annual projection: *"Over 12 months, accounting for [Y]% annual decay, this experiment is projected to generate [$Z] in incremental revenue."*
- Near the chart: *"The dashed line shows revenue if lift never decays. The solid line reflects your decay assumption of [Y]%. The difference represents the projected impact of lift erosion."*

This copy should be templated with dynamic values, not static. It should read naturally enough to paste directly into a client report.

---

## 6. Outputs & Communication Layer

### Numeric Outputs (Full List)

The model should produce and display:

| Output | Granularity |
|---|---|
| Incremental conversions | Per day, 30d, 90d, 180d, 365d |
| Qualified incremental conversions (if qual rate < 100%) | Same |
| Incremental revenue | Per day, 30d, 90d, 180d, 365d |
| Cumulative incremental revenue | Running total, surfaced in chart |
| Relative lift | Single value (from inputs) |
| Absolute lift | Single value (from inputs) |
| Remaining lift at period end | 30d, 90d, 180d, 365d (only shown if decay > 0) |

### Visual Outputs

- **Primary chart:** Cumulative revenue over time (with and without decay)
- **Secondary chart (optional):** Daily revenue over time (showing the decay curve)
- Charts should be clean, minimal, and use at most two colors. They must be legible when screenshotted at typical presentation sizes.

### Plain-Language Summary

Below the numeric output, generate a 2–3 sentence summary in natural language that synthesizes the key takeaway. Example:

> "This experiment produced a 18.75% relative lift in conversion rate. Deployed to 100% of traffic, the winning variation is projected to generate approximately 4,380 incremental conversions and $350,400 in incremental revenue over the next 12 months, assuming 30% annual decay and an average order value of $80."

This summary dynamically assembles from the inputs and outputs. It is the most client-facing piece of the tool. It should:

- State the lift
- State the projected revenue and time frame
- Name the key assumptions (decay rate, revenue model, qualification rate if applicable)
- Avoid hedging language that undermines confidence, but also avoid false precision — round to reasonable significant figures

### Transparency Principles

Every output should be traceable to its inputs. The UI should make it trivial for the user to understand: "If I change X, Y happens." Specifically:

- No hidden assumptions. Every number that feeds the model is either user-entered or visibly derived and displayed.
- No black-box calculations. The inline copy explains the logic in plain terms.
- No false precision. Revenue should display with appropriate rounding (nearest dollar for large numbers, nearest cent only if values are small). Conversion counts should be whole numbers.

---

## 7. Extensibility & Future Versions

V1 is deliberately narrow. Here is how the architecture should anticipate growth without over-building now.

### V2 Candidates (High Value, Moderate Effort)

- **Scenario comparison.** Let users create 3 scenarios (conservative / expected / optimistic) by varying decay and qualification rate, displayed side by side. This is the single most requested feature in CRO reporting and should be the first V2 addition.
- **Cost modeling and true ROI.** Add inputs for program cost (agency fees, dev implementation cost, opportunity cost of traffic during the test). Output a true ROI ratio: (Incremental revenue - Cost) / Cost. This transforms the tool from a revenue projector into an ROI calculator.
- **PDF / slide export.** Generate a formatted one-page summary suitable for client QBRs. This requires a rendering layer but no logic changes.

### V3+ Candidates (High Value, Higher Effort)

- **Multi-experiment portfolio rollup.** Enter multiple experiments, see aggregate projected revenue across a program quarter or year. This requires a data persistence layer (saved experiments) and summation logic that handles overlapping traffic.
- **Confidence intervals.** Incorporate statistical uncertainty from the original experiment (sample size, p-value, or Bayesian credible interval) to produce a range of projected outcomes rather than a single point estimate. This would show, e.g., "Projected annual revenue: $280K–$420K (90% CI)."
- **Decay model refinement.** Offer multiple decay curves (exponential, step-function, seasonal) and potentially allow users to input observed post-launch data to calibrate the decay model empirically.
- **Integration with testing platforms.** Pull experiment results directly from Optimizely, VWO, AB Tasty, or Google Optimize (successor) via API, eliminating manual input.

### Architectural Considerations for Extensibility

- **Separate calculation logic from presentation.** The math should live in a pure, stateless calculation layer that takes inputs and returns outputs. The UI renders those outputs. This makes it trivial to add new output views, export formats, or even an API layer later.
- **Design the input model as a serializable object.** Even though V1 has no persistence, structuring inputs as a single JSON-serializable object means saved experiments, URL-shareable configs, and batch processing all become straightforward additions.
- **Keep the revenue model toggle as an enum, not a conditional tree.** Adding a new revenue model in the future should mean adding one new entry to a mapping (label, fields, multiplier logic), not threading conditionals through the codebase.

---

## Appendix: Key Assumptions & Guardrails

These are the modeling assumptions that should be documented in the tool itself (in a collapsible "About this model" section or footer):

1. **Traffic stationarity.** The model assumes future daily traffic equals the average daily traffic observed during the experiment. It does not account for seasonality, growth, or decline in traffic volume.
2. **Lift stationarity (without decay).** At 0% decay, the model assumes the observed lift persists indefinitely at its measured value. This is an optimistic upper bound.
3. **No interaction effects.** The model does not account for interactions between this experiment and other concurrent or future experiments.
4. **Revenue linearity.** Each incremental conversion is worth the same dollar amount (the user-provided AOV, ARPA, etc.). There is no volume discounting, capacity constraint, or diminishing return modeled.
5. **Decay model is an approximation.** Compounding daily decay is a reasonable default but is not derived from this specific experiment's data. Actual degradation patterns vary.

These guardrails protect the agency's credibility. A model that over-promises is worse than no model at all. The tool should make it easy to produce defensible, conservative estimates — and then let the actual results exceed them.

---

*End of strategic plan.*
