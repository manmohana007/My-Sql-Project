-- Avg Transit Time, Avg Delay & Efficiency Ratio per Route
SELECT
    s.Route_ID, r.Source_City, r.Destination_City, r.Distance_KM,
    r.Avg_Transit_Time_Hours AS Expected_Transit_Hrs,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 2) AS Avg_Actual_Transit_Hrs,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    ROUND(r.Distance_KM / NULLIF(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 0), 2) AS Efficiency_Ratio
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City,
         r.Distance_KM, r.Avg_Transit_Time_Hours
ORDER BY Efficiency_Ratio DESC;

-- 3 Routes with Worst Efficiency Ratio
SELECT
    s.Route_ID, r.Source_City, r.Destination_City, r.Distance_KM,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 2) AS Avg_Actual_Transit_Hrs,
    ROUND(r.Distance_KM / NULLIF(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 0), 2) AS Efficiency_Ratio
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City, r.Distance_KM
ORDER BY Efficiency_Ratio ASC
LIMIT 3;

-- Routes Where >20% Shipments Exceeded Expected Transit Time
SELECT
    s.Route_ID, r.Source_City, r.Destination_City, r.Avg_Transit_Time_Hours AS Expected_Hrs,
    COUNT(*) AS Total_Shipments,
    SUM(CASE WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date) > r.Avg_Transit_Time_Hours
        THEN 1 ELSE 0 END) AS Delayed_Beyond_Expected,
    ROUND(SUM(CASE WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date) > r.Avg_Transit_Time_Hours
        THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Pct_Delayed
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City, r.Avg_Transit_Time_Hours
HAVING Pct_Delayed > 20
ORDER BY Pct_Delayed DESC;

-- Routes Recommended for Optimization
SELECT
    s.Route_ID, r.Source_City, r.Destination_City, r.Distance_KM,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 2) AS Avg_Transit_Hrs,
    ROUND(r.Distance_KM / NULLIF(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 0), 2) AS Efficiency_Ratio,
    'Review & Optimize' AS Recommendation
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City, r.Distance_KM
ORDER BY Avg_Delay_Hours DESC, Efficiency_Ratio ASC
LIMIT 10;
