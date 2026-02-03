-- Tables used:
-- 1. engine_health: historical sensor data with true RUL
-- 2. engine_rul_predictions: ML-predicted RUL for decision analytics

-- engine_health → historical + sensor + true RUL

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

-- engine_rul_predictions → ML-predicted RUL for decisions
SELECT COUNT(*) FROM engine_rul_predictions;

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

-- Failure Risk Ranking (WINDOW FUNCTION)
-- Rank engines by failure risk
SELECT engine_id,
       AVG(predicted_rul) AS avg_rul,
       RANK() OVER (ORDER BY AVG(predicted_rul)) AS risk_rank
FROM engine_rul_predictions
GROUP BY engine_id;

-- 6. High-Risk Engines per Cycle
-- Monitor high-risk engines over operational cycles
SELECT cycle,
       COUNT(*) AS high_risk_engines
FROM engine_rul_predictions
WHERE predicted_rul < 30
GROUP BY cycle
ORDER BY cycle;

-- 7. Maintenance Load Forecasting
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


