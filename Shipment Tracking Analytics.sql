-- Latest Status and Delivery Date per Shipment
SELECT
    Shipment_ID, Order_ID, Agent_ID, Route_ID, Delivery_Status, Delivery_Date, Delay_Hours
FROM fedex_shipments
ORDER BY Delivery_Date DESC;

-- Routes Where Majority are "In Transit" or "Returned"
SELECT
    s.Route_ID, r.Source_City, r.Destination_City,
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
    Delay_Reason, COUNT(*) AS Frequency,
    ROUND(AVG(Delay_Hours), 2) AS Avg_Delay_Hours
FROM fedex_shipments
WHERE Delay_Hours > 0
  AND Delay_Reason IS NOT NULL
GROUP BY Delay_Reason
ORDER BY Frequency DESC;

-- Orders with Delay > 120 Hours (Bottlenecks)
SELECT
    Shipment_ID, Order_ID, Delay_Hours
FROM fedex_shipments
WHERE Delay_Hours > 120
ORDER BY Delay_Hours DESC;
