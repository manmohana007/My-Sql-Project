-- Top 3 Warehouses with Highest Average Delay
SELECT
    s.Warehouse_ID, w.City, w.Country,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours,
    COUNT(s.Shipment_ID) AS Total_Shipments
FROM fedex_shipments s
JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY s.Warehouse_ID, w.City, w.Country
ORDER BY Avg_Delay_Hours DESC
LIMIT 3;

-- Total Shipments vs Delayed Shipments per Warehouse
SELECT
    s.Warehouse_ID, w.City,
    COUNT(*) AS Total_Shipments,
    SUM(CASE WHEN s.Delay_Hours > 0 THEN 1 ELSE 0 END) AS Delayed_Shipments,
    SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) AS OnTime_Shipments,
    ROUND(SUM(CASE WHEN s.Delay_Hours > 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `Delay_%`
FROM fedex_shipments s
JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY s.Warehouse_ID, w.City
ORDER BY `Delay_%` DESC;

-- CTE: Warehouses Exceeding Global Average Delay
WITH GlobalAvg AS 
	(SELECT ROUND(AVG(Delay_Hours), 2) AS Global_Avg_Delay
    FROM fedex_shipments),
WarehouseAvg AS 
	(SELECT s.Warehouse_ID, w.City, w.Country,
        ROUND(AVG(s.Delay_Hours), 2) AS Warehouse_Avg_Delay
    FROM fedex_shipments s
    JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
    GROUP BY s.Warehouse_ID, w.City, w.Country)
SELECT
    wa.Warehouse_ID, wa.City, wa.Country, wa.Warehouse_Avg_Delay, ga.Global_Avg_Delay,                                              
    ROUND(wa.Warehouse_Avg_Delay - ga.Global_Avg_Delay, 2) AS Above_Global_By_Hrs
FROM WarehouseAvg wa
CROSS JOIN GlobalAvg ga
WHERE wa.Warehouse_Avg_Delay > ga.Global_Avg_Delay
ORDER BY wa.Warehouse_Avg_Delay DESC;

-- Rank Warehouses by On-Time Delivery Percentage
SELECT
    s.Warehouse_ID, w.City,
    COUNT(*) AS Total_Shipments,
    SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) AS OnTime_Deliveries,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `OnTime_%`,
    RANK() OVER (
        ORDER BY SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) DESC
    ) AS Warehouse_Rank
FROM fedex_shipments s
JOIN fedex_warehouses w ON s.Warehouse_ID = w.Warehouse_ID
GROUP BY s.Warehouse_ID, w.City
ORDER BY `OnTime_%` DESC;

