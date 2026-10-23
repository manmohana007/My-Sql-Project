## Identify and delete duplicate Order_ID or Shipment_ID records.

-- Identify and delete duplicate Order_ID records. 
SELECT Order_ID, COUNT(Order_ID)
FROM fedex_orders
GROUP BY Order_ID
HAVING COUNT(Order_ID) > 1;

DELETE FROM fedex_orders
WHERE Order_ID IN 
(SELECT Order_ID FROM 
    (SELECT Order_ID, ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_ID) AS rn FROM fedex_orders) ranked
WHERE rn > 1);

-- Identify and delete duplicate Shipment_ID records. 
SELECT Shipment_ID, COUNT(Shipment_ID)
FROM fedex_shipments
GROUP BY Shipment_ID
HAVING COUNT(Shipment_ID) > 1;

-- Delete
DELETE FROM fedex_shipments
WHERE Shipment_ID IN 
(SELECT Shipment_ID FROM 
	(SELECT Shipment_ID, ROW_NUMBER() OVER (PARTITION BY Shipment_ID ORDER BY Shipment_ID) AS rn FROM fedex_shipments) ranked
WHERE rn > 1);

## Replace null or missing Delay_Hours values in the Shipments Table with the average delay for that Route_ID

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

## Convert all date columns (Order_Date, Pickup_Date, Delivery_Date) into YYYY-MM-DD HH:MM:SS format using SQL date functions

-- Convert Order_Date, Pickup_Date and Delivery_Date to YYYY-MM-DD HH:MM:SS
SELECT
    Order_ID,
    DATE_FORMAT(Order_Date, '%Y-%m-%d %H:%i:%s') AS Order_Date
FROM fedex_orders;
SELECT
    Shipment_ID,
    DATE_FORMAT(Pickup_Date,   '%Y-%m-%d %H:%i:%s') AS Pickup_Date,
    DATE_FORMAT(Delivery_Date, '%Y-%m-%d %H:%i:%s') AS Delivery_Date
FROM fedex_shipments;

Alter table fedex_orders
Modify Order_Date datetime;
Alter table fedex_shipments
Modify Pickup_Date datetime;
Alter table fedex_shipments
modify Delivery_Date datetime;

## Ensure that no Delivery_Date occurs before Pickup_Date (flag such records).
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

## Validate referential integrity between Orders, Routes, Warehouses, and Shipments.
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








