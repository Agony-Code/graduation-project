# 📑 UK National Railway Operations & Analytics
### **Digital Egypt Pioneers Initiative (DEPI) Graduation Project — 2026**

---

## 1. Project Overview
This project addresses a critical gap in UK rail intelligence by transforming raw operational logistics logs and fragmented transaction data into actionable, strategic insights. Moving beyond standalone visualization, the project implements a complete end-to-end data pipeline. By standardizing and cross-validating a complex transportation dataset of **19,871 distinct trips** and **31.7K ticket transactions** across **65 unique routes**, this platform uncovers core driving patterns behind revenue, passenger demand, and operational punctuality.

---

## 2. Project Objectives
The analytics framework was built to fulfill four main operational goals:
* **Optimize Rail Operations:** Pinpoint scheduling bottlenecks, track capacity strain points, and isolate operational inefficiencies across different train operators.
* **Understand Passenger Behavior:** Map traffic demand spikes and travel timing to optimize capacity planning and provide seamless scheduling based on actual customer choices.
* **Evaluate Revenue Streams:** Analyze ticket classes (Standard vs. First Class) and purchase behavioral channels to maximize yield management and establish dynamic pricing strategies.
* **Improve On-Time Performance:** Diagnose the underlying root causes of train delays (Weather, Signals, Technical Faults) to target preventive strategies and infrastructure upgrades.

---

## 3. Technical Foundation
To deliver robust, production-grade outputs, the project utilizes a scalable data analytics stack:
* **SQL:** Deployed as the backbone pipeline architecture for core transformations, data structural relations, and targeted cleaning.
* **Python:** Utilized for deep Exploratory Data Analysis (EDA), advanced data mining, and programmatic cleaning scripts.
* **Power Query & Excel:** Used for initial profile checks, lightweight transactional modeling, and source data validation checkups.
* **Tableau:** Chosen to engineer an interactive, high-fidelity business intelligence dashboard system.

---

## 4. Data Engineering Pipeline (ETL)
The custom-engineered pre-processing workflow cleanses, structures, and normalizes raw logistics logs through four key stages:

1. **Ingestion & Schema Check:** Mapping and casting over 31.7K dirty transaction records into their strictly enforced target database datatypes.
2. **Text Standardization:** Cleaning irregular text inputs, fixing mixed-case statuses, and unifying train operator naming conventions.
3. **Feature Engineering:** Programmatically generating Peak/Off-Peak classifications, deriving explicit delay intervals, and setting dynamic financial refund flags.
4. **System Multi-Validation:** Auditing missing null patterns, edge cases, and statistical outliers across both Python and SQL validation layers.

### 💡 Key Pre-Processing Challenges & Solutions:
* **Fixing Operational Status Errors:** The raw dataset contained 18 trips incorrectly marked as 'Delayed' or 'Cancelled' despite their actual arrival time matching the scheduled time perfectly. This was resolved using a target SQL query that overwritten their statuses back to 'On Time' and flushed out the erroneous delay reasons.
* **Standardizing Casing & Text Categories:** Inconsistencies plagued text fields, where identical delay reasons were treated as distinct groups due to shifting terms (e.g., `Signal failure` vs. `Signal Failure` or `Staffing` vs. `Staff Shortage`). All categories were mapped and unified to enable clean, aggregated chart groupings.
* **Reconstructing Hidden Refunds & True Net Profit:** Raw data displayed fixed ticket face values without accounting for capital loss from travel disruptions. Applying UK rail delay compensation logic, a dynamic calculation rule was built to estimate partial-to-full refunds (ranging from 5% to 100% back based on exact delay minutes), exposing the actual net profit margins.
* **Handling Midnight & Overnight Trips:** For trains running across midnight, subtracting the departure time from the arrival time generated broken, negative duration values (e.g., `-1400` minutes). This was resolved by implementing an algorithmic condition that adds `+1440` minutes to correct journey durations for all overnight schedules.
* **Reversing Ticket Discounts:** Ticket sales lacked a clear breakdown of how marketing promotions affected incoming revenue. Custom fields were reverse-engineered to reconstruct the original ticket base price and separate specific discount streams (30% for Railcards, 50% for Advance bookings, and 25% for Off-Peak pricing).

---

## 5. Passenger & Traffic Analytics
A detailed exploration of travel volumes revealed clear, actionable demand patterns across the rail network:
* **Morning Peak (06:00 – 08:00):** Comprises a sharp passenger surge accounting for **~31%** of all weekday journeys.
* **Evening Peak (16:00 – 18:00):** Generates a secondary return-commute spike, capturing **~27%** of total daily volume.
* **Off-Peak Dominance:** Represents the vast majority of network traffic at **77.39%** of total trips, identifying it as the core landscape for revenue yield optimization and promotional targeting.

---

## 6. Interactive Dashboard Architecture
The core analytical deliverable consists of a comprehensive, production-grade **6-page Tableau dashboard** tailored to provide deep operational insights to rail executives:

1. **Operations Performance** — High-level overview of scheduling efficiency, trip completions, and network health.
2. **Tickets Analysis** — Detailed evaluation of passenger buying types, ticket distribution, and payment method choices.
3. **Routes Performance** — Deep dive into individual transit lines, identifying top-performing and underperforming routes.
4. **Revenue** — Financial monitoring tracking gross sales, discount impacts, and net profitability.
5. **Refunds** — Audit view tracking total capital lost to customer refunds from service failures.
6. **Delays** — Diagnostic space visualizing the frequencies, volumes, and severity distributions of delayed trains.

---

## 7. Delays & Punctuality Diagnostics
An in-depth root-cause investigation successfully mapped **40,066 cumulative delay minutes** directly to specific technical, environmental, and operator faults:

### Core Performance Metrics:
* **Delayed Runs:** 1,048 trips
* **Cancelled Runs:** 789 trips
* **Average Delay Time:** 38.2 minutes per delayed train

### Root Cause Breakdown:
* **Weather Issues:** The leading cause of disruption, triggering **26.3%** of all delays (~10.5K minutes).
* **Signal Failure:** Responsible for **23.1%** of network downtime (~9.2K minutes).
* **Technical Faults:** Accounting for **19.5%** of recorded delay intervals (~7.8K minutes).

### Delay Severity Distribution:
* **Minor Delays (< 15 mins):** 42.4%
* **Medium Delays (15 – 60 mins):** 38.1%
* **Severe Delays (> 60 mins):** 19.5%

### Top Delay-Prone Operators:
1. **CrossCountry:** Highest disruptions with a **15.4%** overall Delay Rate.
2. **GWR (Great Western Railway):** Follows with an **11.8%** Delay Rate.
3. **TransPennine Express:** Experiences a **9.2%** Delay Rate.

---

## 8. Strategic Business Tactic Interventions
Based on the data patterns uncovered, four strategic recommendations are proposed for UK Rail operators to reduce operational friction and maximize yield:

1. **Dynamic Pricing Strategy:** Deploy tactical off-peak discounts to redistribute intense peak commute volumes, flattening demand spikes while increasing seating occupancy throughout the day.
2. **Targeted Infrastructure Reinforcement:** Direct infrastructure and capital maintenance funds specifically toward upgrading signaling systems and weather-proofing high-risk lines, addressing the root sources of over 50% of delay instances.
3. **Automated Delay Claims:** Integrate automated, frictionless delay-repayment systems directly into passenger ticketing portals to dramatically lower user friction and restore brand satisfaction.
4. **Centralized Data Infrastructure:** Establish a streaming ETL data warehouse that continuously fuses live operational timetables with accounting records for real-time analytics.
---

## 9. Future Scope
To scale and expand the capabilities of this platform, the next phases will introduce:
* **Predictive ML Models:** Train and deploy Random Forest and ensemble algorithms to project potential train delays in real time based on incoming weather alerts and historic station loads.
* **Sentiment Mining Engine:** Scrape and process passenger reviews and social media mentions to correlate scheduling delays with public customer dissatisfaction scores.
* **Automated Data Pipelines:** Transition local scripts into cloud-scheduled orchestration tools (e.g., Apache Airflow or cloud cron) to update active databases on a seamless daily routine.

---

## 👥 DEPI Project Board & Strategy Team
This project was developed by the following data professionals:
* **Mohamed Fathy**
* **Wameed Alaa El-Dein**
* **Mohamed Mohiy**
* **Assem Mohamed**

> *"Data is the new infrastructure. For UK rail to thrive in the 21st century, investment in analytics capability must match investment in tracks and trains."*
