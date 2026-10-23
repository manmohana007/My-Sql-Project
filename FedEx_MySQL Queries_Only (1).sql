-- ============================================================
-- FEDEX DELIVERY ANALYTICS — ALL SQL QUERIES
-- ============================================================


-- ============================================================
-- TASK 1: DATA CLEANING
-- ============================================================

-- Identify Duplicate Order_IDs
SELECT Order_ID, COUNT(*) AS duplicate_count
FROM fedex_orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;

-- Delete Duplicate Order_IDs
DELETE FROM fedex_orders
WHERE Order_ID NOT IN (
    SELECT * FROM (
        SELECT MIN(Order_ID)
        FROM fedex_orders
        GROUP BY Order_ID
    ) AS temp
);

-- Identify Duplicate Shipment_IDs
SELECT Shipment_ID, COUNT(*) AS duplicate_count
FROM fedex_shipments
GROUP BY Shipment_ID
HAVING COUNT(*) > 1;

-- Delete Duplicate Shipment_IDs
DELETE FROM fedex_shipments
WHERE Shipment_ID NOT IN (
    SELECT * FROM (
        SELECT MIN(Shipment_ID)
        FROM fedex_shipments
        GROUP BY Shipment_ID
    ) AS temp
);

-- Replace NULL Delay_Hours with Avg Delay per Route_ID
UPDATE fedex_shipments s1
JOIN (
    SELECT Route_ID, AVG(Delay_Hours) AS avg_delay
    FROM fedex_shipments
    WHERE Delay_Hours IS NOT NULL
    GROUP BY Route_ID
) s2 ON s1.Route_ID = s2.Route_ID
SET s1.Delay_Hours = ROUND(s2.avg_delay, 2)
WHERE s1.Delay_Hours IS NULL;

-- Convert Order_Date to YYYY-MM-DD HH:MM:SS
SELECT
    Order_ID,
    DATE_FORMAT(Order_Date, '%Y-%m-%d %H:%i:%s') AS Order_Date
FROM fedex_orders;

-- Convert Pickup_Date and Delivery_Date to YYYY-MM-DD HH:MM:SS
SELECT
    Shipment_ID,
    DATE_FORMAT(Pickup_Date,   '%Y-%m-%d %H:%i:%s') AS Pickup_Date,
    DATE_FORMAT(Delivery_Date, '%Y-%m-%d %H:%i:%s') AS Delivery_Date
FROM fedex_shipments;

-- Alter columns to DATETIME if not already
ALTER TABLE fedex_orders    MODIFY Order_Date    DATETIME;
ALTER TABLE fedex_shipments MODIFY Pickup_Date   DATETIME;
ALTER TABLE fedex_shipments MODIFY Delivery_Date DATETIME;

-- Flag Records Where Delivery_Date < Pickup_Date
SELECT
    Shipment_ID,
    Order_ID,
    Pickup_Date,
    Delivery_Date,
    'Invalid: Delivery before Pickup' AS Flag
FROM fedex_shipments
WHERE Delivery_Date < Pickup_Date;

-- Add Flag Column and Mark Invalid Records
ALTER TABLE fedex_shipments
ADD COLUMN Date_Integrity_Flag VARCHAR(50) DEFAULT NULL;

UPDATE fedex_shipments
SET Date_Integrity_Flag = 'Invalid Date'
WHERE Delivery_Date < Pickup_Date;

-- Referential Integrity: Orders vs Routes
SELECT o.Order_ID, o.Route_ID
FROM fedex_orders o
LEFT JOIN fedex_routes r ON o.Route_ID = r.Route_ID
WHERE r.Route_ID IS NULL;

-- Referential Integrity: Orders vs Warehouses
SELECT o.Order_ID, o.Warehouse_ID
FROM fedex_orders o
LEFT JOIN fedex_warehouses w ON o.Warehouse_ID = w.Warehouse_ID
WHERE w.Warehouse_ID IS NULL;

-- Referential Integrity: Shipments vs Orders
SELECT s.Shipment_ID, s.Order_ID
FROM fedex_shipments s
LEFT JOIN fedex_orders o ON s.Order_ID = o.Order_ID
WHERE o.Order_ID IS NULL;

-- Referential Integrity: Shipments vs Agents
SELECT s.Shipment_ID, s.Agent_ID
FROM fedex_shipments s
LEFT JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
WHERE a.Agent_ID IS NULL;

-- Referential Integrity: Shipments vs Routes
SELECT s.Shipment_ID, s.Route_ID
FROM fedex_shipments s
LEFT JOIN fedex_routes r ON s.Route_ID = r.Route_ID
WHERE r.Route_ID IS NULL;

-- Referential Integrity: Shipments vs Warehouses
SELECT s.Shipment_ID, s.Warehouse_ID
FROM fedex_shipments s
LEFT JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
WHERE w.Warehouse_ID IS NULL;


-- ============================================================
-- TASK 2: DELAY ANALYSIS
-- ============================================================

-- Delivery Delay in Hours per Shipment
SELECT
    Shipment_ID,
    Order_ID,
    Pickup_Date,
    Delivery_Date,
    TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date) AS Actual_Transit_Hours,
    Delay_Hours
FROM fedex_shipments;

-- Top 10 Delayed Routes by Average Delay Hours
SELECT
    s.Route_ID,
    r.Source_City,
    r.Destination_City,
    r.Source_Country,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    COUNT(s.Shipment_ID)         AS Total_Shipments
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City, r.Source_Country
ORDER BY Avg_Delay_Hours DESC
LIMIT 10;

-- Rank Shipments by Delay Within Each Warehouse
SELECT
    Shipment_ID,
    Warehouse_ID,
    Route_ID,
    Delay_Hours,
    RANK()       OVER (PARTITION BY Warehouse_ID ORDER BY Delay_Hours DESC) AS Delay_Rank,
    DENSE_RANK() OVER (PARTITION BY Warehouse_ID ORDER BY Delay_Hours DESC) AS Delay_Dense_Rank,
    ROW_NUMBER() OVER (PARTITION BY Warehouse_ID ORDER BY Delay_Hours DESC) AS Row_Num
FROM fedex_shipments
ORDER BY Warehouse_ID, Delay_Rank;

-- Average Delay per Delivery_Type
SELECT
    o.Delivery_Type,
    COUNT(s.Shipment_ID)         AS Total_Shipments,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    ROUND(MAX(s.Delay_Hours), 2) AS Max_Delay_Hours,
    ROUND(MIN(s.Delay_Hours), 2) AS Min_Delay_Hours
FROM fedex_shipments s
JOIN fedex_orders o ON s.Order_ID = o.Order_ID
GROUP BY o.Delivery_Type
ORDER BY Avg_Delay_Hours DESC;


-- ============================================================
-- TASK 3: ROUTE PERFORMANCE ANALYSIS
-- ============================================================

-- Avg Transit Time, Avg Delay & Efficiency Ratio per Route
SELECT
    s.Route_ID,
    r.Source_City,
    r.Destination_City,
    r.Distance_KM,
    r.Avg_Transit_Time_Hours AS Expected_Transit_Hrs,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 2) AS Avg_Actual_Transit_Hrs,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    ROUND(r.Distance_KM /
        NULLIF(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 0), 2) AS Efficiency_Ratio
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City,
         r.Distance_KM, r.Avg_Transit_Time_Hours
ORDER BY Efficiency_Ratio DESC;

-- 3 Routes with Worst Efficiency Ratio
SELECT
    s.Route_ID,
    r.Source_City,
    r.Destination_City,
    r.Distance_KM,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 2) AS Avg_Actual_Transit_Hrs,
    ROUND(r.Distance_KM /
        NULLIF(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 0), 2) AS Efficiency_Ratio
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City, r.Distance_KM
ORDER BY Efficiency_Ratio ASC
LIMIT 3;

-- Routes Where >20% Shipments Exceeded Expected Transit Time
SELECT
    s.Route_ID,
    r.Source_City,
    r.Destination_City,
    r.Avg_Transit_Time_Hours AS Expected_Hrs,
    COUNT(*) AS Total_Shipments,
    SUM(CASE
        WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date) > r.Avg_Transit_Time_Hours
        THEN 1 ELSE 0 END) AS Delayed_Beyond_Expected,
    ROUND(SUM(CASE
        WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date) > r.Avg_Transit_Time_Hours
        THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Pct_Delayed
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City, r.Avg_Transit_Time_Hours
HAVING Pct_Delayed > 20
ORDER BY Pct_Delayed DESC;

-- Routes Recommended for Optimization
SELECT
    s.Route_ID,
    r.Source_City,
    r.Destination_City,
    r.Distance_KM,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 2) AS Avg_Transit_Hrs,
    ROUND(r.Distance_KM /
        NULLIF(AVG(TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date)), 0), 2) AS Efficiency_Ratio,
    'Review & Optimize' AS Recommendation
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City, r.Distance_KM
ORDER BY Avg_Delay_Hours DESC, Efficiency_Ratio ASC
LIMIT 5;


-- ============================================================
-- TASK 4: WAREHOUSE PERFORMANCE
-- ============================================================

-- Top 3 Warehouses with Highest Average Delay
SELECT
    s.Warehouse_ID,
    w.City,
    w.Country,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    COUNT(s.Shipment_ID)         AS Total_Shipments
FROM fedex_shipments s
JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY s.Warehouse_ID, w.City, w.Country
ORDER BY Avg_Delay_Hours DESC
LIMIT 3;

-- Total Shipments vs Delayed Shipments per Warehouse
SELECT
    s.Warehouse_ID,
    w.City,
    COUNT(*) AS Total_Shipments,
    SUM(CASE WHEN s.Delay_Hours > 0 THEN 1 ELSE 0 END) AS Delayed_Shipments,
    SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) AS OnTime_Shipments,
    ROUND(SUM(CASE WHEN s.Delay_Hours > 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Delay_Pct
FROM fedex_shipments s
JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY s.Warehouse_ID, w.City
ORDER BY Delay_Pct DESC;

-- CTE: Warehouses Exceeding Global Average Delay
WITH GlobalAvg AS (
    SELECT ROUND(AVG(Delay_Hours), 2) AS Global_Avg_Delay
    FROM fedex_shipments
),
WarehouseAvg AS (
    SELECT
        s.Warehouse_ID,
        w.City,
        w.Country,
        ROUND(AVG(s.Delay_Hours), 2) AS Warehouse_Avg_Delay
    FROM fedex_shipments s
    JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
    GROUP BY s.Warehouse_ID, w.City, w.Country
)
SELECT
    wa.Warehouse_ID,
    wa.City,
    wa.Country,
    wa.Warehouse_Avg_Delay,
    ga.Global_Avg_Delay,
    ROUND(wa.Warehouse_Avg_Delay - ga.Global_Avg_Delay, 2) AS Above_Global_By_Hrs
FROM WarehouseAvg wa
CROSS JOIN GlobalAvg ga
WHERE wa.Warehouse_Avg_Delay > ga.Global_Avg_Delay
ORDER BY wa.Warehouse_Avg_Delay DESC;

-- Rank Warehouses by On-Time Delivery Percentage
SELECT
    s.Warehouse_ID,
    w.City,
    COUNT(*) AS Total_Shipments,
    SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) AS OnTime_Deliveries,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct,
    RANK() OVER (
        ORDER BY SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) DESC
    ) AS Warehouse_Rank
FROM fedex_shipments s
JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY s.Warehouse_ID, w.City
ORDER BY OnTime_Pct DESC;


-- ============================================================
-- TASK 5: DELIVERY AGENT PERFORMANCE
-- ============================================================

-- Rank Agents per Route by On-Time Delivery %
SELECT
    s.Route_ID,
    s.Agent_ID,
    a.Agent_Name,
    a.Zone,
    COUNT(*) AS Total_Deliveries,
    SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) AS OnTime_Deliveries,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct,
    RANK() OVER (
        PARTITION BY s.Route_ID
        ORDER BY SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) DESC
    ) AS Agent_Rank
FROM fedex_shipments s
JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
GROUP BY s.Route_ID, s.Agent_ID, a.Agent_Name, a.Zone
ORDER BY s.Route_ID, Agent_Rank;

-- Agents with On-Time % Below 85%
SELECT
    s.Agent_ID,
    a.Agent_Name,
    a.Zone,
    a.Experience_Years,
    a.Avg_Rating,
    COUNT(*) AS Total_Deliveries,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct
FROM fedex_shipments s
JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
GROUP BY s.Agent_ID, a.Agent_Name, a.Zone, a.Experience_Years, a.Avg_Rating
HAVING OnTime_Pct < 85
ORDER BY OnTime_Pct ASC;

-- Top 5 Agents
SELECT
    'Top 5' AS Category,
    a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct
FROM fedex_shipments s
JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
GROUP BY a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years
ORDER BY OnTime_Pct DESC
LIMIT 5;

-- Bottom 5 Agents
SELECT
    'Bottom 5' AS Category,
    a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct
FROM fedex_shipments s
JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
GROUP BY a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years
ORDER BY OnTime_Pct ASC
LIMIT 5;

-- Top 5 vs Bottom 5 Combined
SELECT * FROM (
    SELECT 'Top 5' AS Category, a.Agent_ID, a.Agent_Name,
           a.Avg_Rating, a.Experience_Years,
           ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct
    FROM fedex_shipments s
    JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
    GROUP BY a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years
    ORDER BY OnTime_Pct DESC LIMIT 5
) AS top5
UNION ALL
SELECT * FROM (
    SELECT 'Bottom 5' AS Category, a.Agent_ID, a.Agent_Name,
           a.Avg_Rating, a.Experience_Years,
           ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct
    FROM fedex_shipments s
    JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
    GROUP BY a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years
    ORDER BY OnTime_Pct ASC LIMIT 5
) AS bot5;


-- ============================================================
-- TASK 6: SHIPMENT STATUS & BOTTLENECK ANALYSIS
-- ============================================================

-- Latest Status and Delivery Date per Shipment
SELECT
    Shipment_ID,
    Order_ID,
    Agent_ID,
    Route_ID,
    Delivery_Status,
    DATE_FORMAT(Delivery_Date, '%Y-%m-%d %H:%i:%s') AS Latest_Delivery_Date,
    Delay_Hours
FROM fedex_shipments
ORDER BY Delivery_Date DESC;

-- Routes Where Majority are "In Transit" or "Returned"
SELECT
    s.Route_ID,
    r.Source_City,
    r.Destination_City,
    COUNT(*) AS Total_Shipments,
    SUM(CASE WHEN s.Delivery_Status IN ('In Transit','Returned') THEN 1 ELSE 0 END) AS InTransit_Returned,
    ROUND(SUM(CASE WHEN s.Delivery_Status IN ('In Transit','Returned') THEN 1 ELSE 0 END)
          / COUNT(*) * 100, 2) AS Pct_Not_Delivered
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Destination_City
HAVING Pct_Not_Delivered > 50
ORDER BY Pct_Not_Delivered DESC;

-- Most Frequent Delay Reasons
SELECT
    Delivery_Feedback       AS Delay_Reason,
    COUNT(*)                AS Frequency,
    ROUND(AVG(Delay_Hours), 2) AS Avg_Delay_Hours
FROM fedex_shipments
WHERE Delay_Hours > 0
  AND Delivery_Feedback IS NOT NULL
GROUP BY Delivery_Feedback
ORDER BY Frequency DESC;

-- Orders with Delay > 120 Hours (Bottlenecks)
SELECT
    s.Shipment_ID,
    s.Order_ID,
    s.Agent_ID,
    s.Route_ID,
    s.Warehouse_ID,
    s.Delay_Hours,
    s.Delivery_Status,
    s.Delivery_Feedback,
    DATE_FORMAT(s.Pickup_Date,   '%Y-%m-%d %H:%i:%s') AS Pickup_Date,
    DATE_FORMAT(s.Delivery_Date, '%Y-%m-%d %H:%i:%s') AS Delivery_Date,
    r.Source_City,
    r.Destination_City
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
WHERE s.Delay_Hours > 120
ORDER BY s.Delay_Hours DESC;


-- ============================================================
-- TASK 7: KPI DASHBOARD
-- ============================================================

-- Avg Delivery Delay per Source_Country
SELECT
    r.Source_Country,
    COUNT(s.Shipment_ID)         AS Total_Shipments,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    ROUND(MAX(s.Delay_Hours), 2) AS Max_Delay_Hours
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY r.Source_Country
ORDER BY Avg_Delay_Hours DESC;

-- Overall On-Time Delivery Percentage
SELECT
    COUNT(*) AS Total_Deliveries,
    SUM(CASE WHEN Delay_Hours = 0 THEN 1 ELSE 0 END) AS OnTime_Deliveries,
    SUM(CASE WHEN Delay_Hours > 0 THEN 1 ELSE 0 END) AS Delayed_Deliveries,
    ROUND(SUM(CASE WHEN Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct
FROM fedex_shipments;

-- Average Delay per Route_ID
SELECT
    s.Route_ID,
    r.Source_City,
    r.Source_Country,
    r.Destination_City,
    r.Destination_Country,
    COUNT(s.Shipment_ID)         AS Total_Shipments,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_City, r.Source_Country,
         r.Destination_City, r.Destination_Country
ORDER BY Avg_Delay_Hours DESC;

-- Warehouse Utilization %
SELECT
    s.Warehouse_ID,
    w.City,
    w.Country,
    w.Manager_Name,
    w.Capacity_per_day,
    COUNT(s.Shipment_ID) AS Shipments_Handled,
    ROUND(COUNT(s.Shipment_ID) / w.Capacity_per_day * 100, 2) AS Utilization_Pct,
    CASE
        WHEN ROUND(COUNT(s.Shipment_ID) / w.Capacity_per_day * 100, 2) >= 90 THEN 'Over-Utilized'
        WHEN ROUND(COUNT(s.Shipment_ID) / w.Capacity_per_day * 100, 2) >= 70 THEN 'Optimally Used'
        ELSE 'Under-Utilized'
    END AS Utilization_Status
FROM fedex_shipments s
JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY s.Warehouse_ID, w.City, w.Country, w.Manager_Name, w.Capacity_per_day
ORDER BY Utilization_Pct DESC;

-- Full KPI Summary Table
SELECT
    r.Source_Country,
    s.Route_ID,
    s.Warehouse_ID,
    COUNT(s.Shipment_ID) AS Total_Shipments,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct,
    ROUND(COUNT(s.Shipment_ID) / w.Capacity_per_day * 100, 2) AS Warehouse_Utilization_Pct
FROM fedex_shipments s
JOIN fedex_routes     r ON s.Route_ID     = r.Route_ID
JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY r.Source_Country, s.Route_ID, s.Warehouse_ID, w.Capacity_per_day
ORDER BY Avg_Delay_Hours DESC;

-- ============================================================
-- END OF SCRIPT
-- ============================================================
