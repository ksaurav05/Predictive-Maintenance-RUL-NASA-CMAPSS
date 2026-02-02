 # Predictive Maintenance & Remaining Useful Life (RUL) Prediction 
 # NASA CMAPSS Dataset | Mechanical Engineering × Data Analytics

# Project Overview
Unplanned equipment failures lead to high downtime and maintenance costs in manufacturing and aerospace industries.  
This project presents an end-to-end Predictive Maintenance (PdM) system to estimate the Remaining Useful Life (RUL) of aircraft engines using multivariate time-series sensor data from the **NASA CMAPSS benchmark dataset.
The project is designed from a **mechanical reliability perspective** and implemented using **data analytics, machine learning, and SQL-based decision support**, making it suitable for **Industry 4.0 applications**.


#  Objectives
- Predict Remaining Useful Life (RUL) under progressive degradation
- Capture mechanical wear trends using sensor analytics
- Identify critical degradation-driving sensors
- Translate ML outputs into maintenance decisions using SQL
- Build a reproducible, explainable, and industry-ready workflow

##  Dataset Description
- Source: NASA CMAPSS (FD001 subset)
- Engines: 100
- Sensors: 21
- Operating Conditions: 3
- Failure Mode: Gradual degradation until failure

Each engine starts in a healthy condition and runs until failure. No explicit failure labels are provided; therefore, " RUL is derived mathematically ".


##  Data Understanding
### Engine Life Cycle Variability
Engines operate for different life spans, simulating real-world operating variability.


##  Methodology

### 1️⃣ Data Ingestion & Preprocessing
- Parsed raw `.txt` files using Pandas
- Assigned meaningful column names based on NASA documentation
- Verified engine-wise operational cycles

### 2️⃣ Remaining Useful Life (RUL) Formulation

<!-- RUL = Maximum Cycle - Current Cycle -->

To avoid early-life bias:
- Piece-wise RUL capping applied at 125 cycles
- Reflects minimal degradation during early operational stages

 ![RUL Degradation Curve](images\rul_curve_engine_1.png)



### 3️⃣ Feature Engineering
- Removed " low-variance sensors " that do not contribute to degradation modeling
- Created " rolling mean features " (window size = 5) per engine to:
  - Smooth sensor noise
  - Capture recent degradation trends
- Ensured " no data leakage by grouping operations by engine ID

![Sensor Degradation Trend](images\sensor_degradation_trend.png)

### 4️⃣ Model Development
- Model:Random Forest Regressor
- Justification:
  - Captures non-linear degradation behavior
  - Robust to noisy sensor signals
  - Minimal preprocessing requirements

<!-- - Training Strategy: Engine-wise train–test split to avoid future information leakage -->

### 5️⃣ Model Evaluation
- Metrics Used: Mean Absolute Error (MAE), Root Mean Squared Error (RMSE)
- Model predicts RUL within ±10–15 cycles, suitable for maintenance planning

![Actual vs Predicted RUL](images\actual_vs_predicted_rul.png)

### 6️⃣ Model Explainability
- Extracted feature importance from Random Forest
- Identified temperature- and pressure-related sensors as dominant degradation drivers

![Feature Importance](images\feature_importance.png)


##  SQL-Based Maintenance Insights (Decision-Oriented Analytics)
To operationalize machine learning outputs and enable maintenance decision-making, the predicted and historical engine health data were persisted in a relational database (MySQL). This SQL layer bridges model predictions with actionable insights for fleet-level monitoring and maintenance planning.

<!-- Database Tables Design -->
Two complementary tables were created to maintain traceability between raw data, ground truth, and model predictions:

## 1️⃣ engine_health (Historical & Ground Truth Data)
This table stores historical engine condition data derived from the training dataset.
Key attributes include:
engine_id – Unique engine identifier
cycle – Operational cycle count
sensor_7, sensor_12, sensor_21 – Selected health-indicative sensors
RUL – Actual remaining useful life
RUL_CAPPED – Capped RUL used during model training

Purpose:
Used for sensor degradation analysis, health trend visualization, and understanding true failure behavior.

-- 1.   Engines Requiring Immediate Maintenance**
SELECT engine_id, MIN(RUL) AS min_rul
FROM engine_health
GROUP BY engine_id
HAVING min_rul <= 20
ORDER BY min_rul;

-- 2. Fleet Health Classification**
SELECT CASE
         WHEN RUL <= 30 THEN 'Critical'
         WHEN RUL <= 60 THEN 'Warning'
         ELSE 'Healthy'
       END AS health_status,
       COUNT(*) AS engine_count
FROM engine_health
GROUP BY health_status;

-- 3. Average Remaining Life per Engine**
SELECT engine_id, AVG(RUL) AS avg_remaining_life
FROM engine_health
GROUP BY engine_id
ORDER BY avg_remaining_life;

-- 4. Degradation Span per Engine**
SELECT engine_id, MAX(RUL) - MIN(RUL) AS degradation_span
FROM engine_health
GROUP BY engine_id;

-- 5. Sensor Behavior Near Failure**
SELECT CASE WHEN RUL <= 30 THEN 'Near Failure' ELSE 'Normal' END AS stage,
       AVG(sensor_12) AS avg_sensor_12
FROM engine_health
GROUP BY stage;

-- 6. Fast-Degrading Engines (Anomaly Detection)**
SELECT engine_id, MAX(RUL) - MIN(RUL) AS life_drop
FROM engine_health
GROUP BY engine_id
ORDER BY life_drop DESC
LIMIT 5;

-- 7. Maintenance Window Recommendation**
SELECT engine_id, MIN(RUL) AS next_maintenance_window
FROM engine_health
GROUP BY engine_id;

-- 8. High-Stress Sensor Levels Near Failure**
SELECT engine_id, AVG(sensor_7) AS avg_vibration
FROM engine_health
WHERE RUL < 25
GROUP BY engine_id;

-- 9. Fleet-Level RUL Distribution**
SELECT FLOOR(RUL / 10) * 10 AS rul_bucket, COUNT(*) AS count
FROM engine_health
GROUP BY rul_bucket
ORDER BY rul_bucket;

-- 10. Decision-Maker Summary Query**
SELECT engine_id,
       MIN(RUL) AS critical_rul,
       AVG(sensor_12) AS avg_temperature,
       AVG(sensor_21) AS avg_pressure
FROM engine_health
GROUP BY engine_id
ORDER BY critical_rul;

## 2️⃣ engine_rul_predictions (Decision Support Table)
This table stores machine-learning–generated predictions aligned with engine operational cycles.
Key attributes include:
engine_id – Unique engine identifier
cycle – Operational cycle count
predicted_rul – Model-predicted remaining useful life
Purpose:
Used for maintenance prioritization, risk ranking, and fleet-level decision analytics

-- 1. Engines Approaching Failure :Identify engines with critical Remaining Useful Life (< 20 cycles)
SELECT engine_id,
       MIN(predicted_rul) AS min_rul
FROM engine_rul_predictions
GROUP BY engine_id
HAVING MIN(predicted_rul) < 20
ORDER BY min_rul ASC;

-- 2. Maintenance Window Classification
-- Categorize engines into maintenance urgency levels
SELECT engine_id,
       CASE
           WHEN predicted_rul < 20 THEN 'Critical'
           WHEN predicted_rul BETWEEN 20 AND 50 THEN 'Warning'
           ELSE 'Healthy'
       END AS maintenance_status
FROM engine_rul_predictions;

-- 3. Fleet-level health monitoring
SELECT maintenance_status,
       AVG(predicted_rul) AS avg_rul
FROM (
    SELECT engine_id,
           CASE
               WHEN predicted_rul < 20 THEN 'Critical'
               WHEN predicted_rul BETWEEN 20 AND 50 THEN 'Warning'
               ELSE 'Healthy'
           END AS maintenance_status,
           predicted_rul
    FROM engine_rul_predictions
) t
GROUP BY maintenance_status;

-- 4. Engines with Rapid Degradation
-- Detect engines with steep RUL degradation
SELECT engine_id,
       MAX(predicted_rul) - MIN(predicted_rul) AS degradation_rate
FROM engine_rul_predictions
GROUP BY engine_id
ORDER BY degradation_rate DESC;

-- 5. Remaining Life Distribution (Risk Buckets)
-- RUL distribution for risk assessment
SELECT FLOOR(predicted_rul / 10) * 10 AS rul_bucket,
       COUNT(*) AS engine_count
FROM engine_rul_predictions
GROUP BY rul_bucket
ORDER BY rul_bucket;

-- 6. Failure Risk Ranking (WINDOW FUNCTION)
-- Rank engines by failure risk
SELECT engine_id,
       AVG(predicted_rul) AS avg_rul,
       RANK() OVER (ORDER BY AVG(predicted_rul)) AS risk_rank
FROM engine_rul_predictions
GROUP BY engine_id;

-- 7. High-Risk Engines per Cycle
-- Monitor high-risk engines over operational cycles
SELECT cycle,
       COUNT(*) AS high_risk_engines
FROM engine_rul_predictions
WHERE predicted_rul < 30
GROUP BY cycle
ORDER BY cycle;

-- 8. Maintenance Load Forecasting
-- Predict upcoming maintenance load
SELECT
    CASE
        WHEN predicted_rul < 20 THEN 'Immediate'
        WHEN predicted_rul BETWEEN 20 AND 50 THEN 'Short-Term'
        ELSE 'Long-Term'
    END AS maintenance_window,
    COUNT(*) AS engine_count
FROM engine_rul_predictions
GROUP BY maintenance_window;

##  Tools & Technologies
- Programming:Python
- Libraries: Pandas, NumPy, Scikit-learn, Matplotlib
- Environment: Jupyter Notebook
- Database: MySQL
- Version Control: GitHub

---

## Future Scope
- Real-time sensor streaming and dashboards
- Maintenance scheduling optimization
- Digital twin integration


##  Repository Structure

Predictive-Maintenance-RUL-NASA-CMAPSS/
├── data/
│   └── raw/
├── notebooks/
│   └── Predictive_Maintenance_RUL.ipynb
├── sql/
│   └──  engine_rul_predictions.csv
    └──  maintenance_insights.sql
├── README.md

## ✅ Conclusion
This project demonstrates a professionally structured, explainable, and industry-ready predictive maintenance solution by combining mechanical degradation principles with machine learning and SQL-based decision analytics. The methodology is scalable and directly applicable to manufacturing, aerospace, and reliability engineering domains.

