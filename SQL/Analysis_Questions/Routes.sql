-- ((( Route Performance )))

-- 1. How many unique routes are there?
SELECT COUNT(*) AS Total_Routes
FROM Routes

-- 2. Which routes have the highest number of transactions & trips?
SELECT TOP 10
    R.Route_Name,
    COUNT(TR.Transaction_ID) AS Total_Transactions,
    COUNT(DISTINCT T.Trip_ID) AS Total_Trips,
    CAST(
        COUNT(DISTINCT TR.Transaction_ID) * 1.0 / NULLIF(COUNT(DISTINCT T.Trip_ID), 0)
        AS DECIMAL(10,2)
    ) AS Demand_Per_Trip
FROM Routes R JOIN Trips T
ON T.Route_ID = R.Route_ID
JOIN Transactions TR
ON TR.Route_ID = R.Route_ID
AND TR.Trip_ID = T.Trip_ID
GROUP BY R.Route_Name
ORDER BY Total_Transactions DESC, Total_Trips DESC

-- 3. Which routes have the highest delay rate?
SELECT TOP 10
    R.Route_Name,
    COUNT(T.Trip_ID) AS Total_Trips,
    SUM(CASE WHEN T.Trip_Status = 'Delayed' THEN 1 END) AS Delayed_Trips,
    SUM(CASE WHEN T.Trip_Status = 'Delayed' THEN Delay_Minutes END) AS Total_Delay_Minutes,
    AVG(CASE WHEN T.Trip_Status = 'Delayed' THEN Delay_Minutes END) AS AVG_Delay,
    CAST(
    ROUND(
    (SUM(CASE WHEN T.Trip_Status = 'Delayed' THEN 1 END) * 100.0) / COUNT(T.Trip_ID), 2)
    AS DECIMAL(5, 2)) AS Delay_Rate
FROM Routes R JOIN Trips T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
HAVING SUM(CASE WHEN T.Trip_Status = 'Delayed' THEN 1 END) > 0
ORDER BY Delay_Rate DESC

-- 4. Which routes have the highest cancellation rate?
SELECT TOP 10
    R.Route_Name,
    COUNT(T.Trip_ID) AS Total_Trips,
    SUM(CASE WHEN T.Trip_Status = 'Cancelled' THEN 1 END) AS Cancelled_Trips,
    CAST(
    ROUND(
    (SUM(CASE WHEN T.Trip_Status = 'Cancelled' THEN 1 END) * 100.0) / COUNT(T.Trip_ID), 2)
    AS DECIMAL(5, 2)) AS Cancellation_Rate
FROM Routes R JOIN Trips T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
HAVING SUM(CASE WHEN T.Trip_Status = 'Cancelled' THEN 1 END) > 0
ORDER BY Cancellation_Rate DESC, Total_Trips DESC

-- 5. Which routes have the highest On-Time performance rate?
SELECT
    R.Route_Name,
    COUNT(T.Trip_ID) AS Total_Trips,
    SUM(CASE WHEN T.Trip_Status = 'On Time' THEN 1 END) AS OnTime_Trips,
    CAST(
    ROUND(
    (SUM(CASE WHEN T.Trip_Status = 'On Time' THEN 1 END) * 100.0) / COUNT(T.Trip_ID), 2)
    AS DECIMAL(5, 2)) AS OnTime_Rate
FROM Routes R JOIN Trips T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
HAVING SUM(CASE WHEN T.Trip_Status = 'On Time' THEN 1 END) > 0
ORDER BY OnTime_Rate DESC, Total_Trips DESC