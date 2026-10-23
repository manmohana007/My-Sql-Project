-- Avg Delivery Delay per Source_Country
SELECT
    r.Source_Country,
    COUNT(s.Shipment_ID) AS Total_Shipments,
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
    s.Route_ID, r.Source_Country,
    COUNT(s.Shipment_ID) AS Total_Shipments,
    ROUND(AVG(s.Delay_Hours), 2) AS Avg_Delay_Hours
FROM fedex_shipments s
JOIN fedex_routes r ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID, r.Source_Country
ORDER BY Avg_Delay_Hours DESC;

-- Warehouse Utilization %
SELECT
    s.Warehouse_ID, w.City, w.Country, w.Manager_Name, w.Capacity_per_day,
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
