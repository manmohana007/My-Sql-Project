-- Rank Agents per Route by On-Time Delivery %
SELECT
    s.Route_ID, s.Agent_ID, a.Agent_Name, a.Zone,
    COUNT(*) AS Total_Deliveries,
    SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) AS OnTime_Deliveries,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `OnTime_%`,
    RANK() OVER 
		(PARTITION BY s.Route_ID
        ORDER BY SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) DESC) AS Agent_Rank
FROM fedex_shipments s
JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
GROUP BY s.Route_ID, s.Agent_ID, a.Agent_Name, a.Zone
ORDER BY s.Route_ID, Agent_Rank;

-- Agents with On-Time % Below 85%
SELECT
    s.Agent_ID, a.Agent_Name, a.Zone, a.Experience_Years, a.Avg_Rating,
    COUNT(*) AS Total_Deliveries,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `OnTime_%`
FROM fedex_shipments s
JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
GROUP BY s.Agent_ID, a.Agent_Name, a.Zone, a.Experience_Years, a.Avg_Rating
HAVING `OnTime_%` < 85
ORDER BY `OnTime_%` ASC;

-- Top 5 Agents
SELECT
    'Top 5' AS Category, a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `OnTime_%`
FROM fedex_shipments s
JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
GROUP BY a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years
ORDER BY `OnTime_%` DESC
LIMIT 5;

-- Bottom 5 Agents
SELECT
    'Bottom 5' AS Category, a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years,
    ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `OnTime_%`
FROM fedex_shipments s
JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
GROUP BY a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years
ORDER BY `OnTime_%` ASC
LIMIT 5;

-- Top 5 vs Bottom 5 Combined
SELECT * FROM (
    SELECT 'Top 5' AS Category, a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years,
           ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct
    FROM fedex_shipments s
    JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
    GROUP BY a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years
    ORDER BY OnTime_Pct DESC LIMIT 5) AS top5
UNION ALL
SELECT * FROM 
	(SELECT 'Bottom 5' AS Category, a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years,
           ROUND(SUM(CASE WHEN s.Delay_Hours = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS OnTime_Pct
    FROM fedex_shipments s
    JOIN fedex_delivery_agents a ON s.Agent_ID = a.Agent_ID
    GROUP BY a.Agent_ID, a.Agent_Name, a.Avg_Rating, a.Experience_Years
    ORDER BY OnTime_Pct ASC LIMIT 5) AS bot5;
