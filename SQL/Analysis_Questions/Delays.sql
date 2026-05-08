-- ((( Delay & Service Reliability )))

-- 1. What is the overall delay rate in the system?
SELECT
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 ELSE 0 END) AS Delayed_Trips,
    CAST(
        SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*) AS DECIMAL(5,2)) AS Delay_Rate_Percentage
FROM Trips

-- 2. What is the average, minimum, and maximum delay time?
SELECT
    SUM(Delay_Minutes) AS Total_Delay_Minutes,
    ROUND(AVG(CAST(Delay_Minutes AS FLOAT)), 2) AS AVG_Delay_Per_Trip,
    AVG(CASE WHEN Delay_Minutes > 0 THEN Delay_Minutes END) AS AVG_Delay_Per_DelayedTrips,
    MAX(Delay_Minutes) AS Longest_Delay,
    MIN(CASE WHEN Delay_Minutes > 0 THEN Delay_Minutes END) AS Shortest_Delay
FROM Trips

-- 3. What are the most common reasons for Delays?
SELECT
    DelayOrCancelled_Reason AS Delay_Reason,
    COUNT(*) AS Total_Delays,
    CAST(
        ROUND(
            (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(),
        2) AS DECIMAL(5,2)) AS Percentage
FROM Trips
WHERE Trip_Status = 'Delayed'
GROUP BY DelayOrCancelled_Reason
ORDER BY Total_Delays DESC

-- 4. What are the most common reasons for cancellations?
SELECT
    DelayOrCancelled_Reason AS Cancellation_Reason,
    COUNT(*) AS Total_Cancelled,
    CAST(
        ROUND(
            (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(),
        2) AS DECIMAL(5,2)) AS Percentage
FROM Trips
WHERE Trip_Status = 'Cancelled'
GROUP BY DelayOrCancelled_Reason
ORDER BY Total_Cancelled DESC

-- 5. How are delays distributed across severity levels (0–15, 15–30, 30–60, 60+ minutes)?
SELECT
    CASE
        WHEN Delay_Minutes BETWEEN 0 AND 14 THEN '0-15 min'
        WHEN Delay_Minutes BETWEEN 15 AND 29 THEN '15-30 min'
        WHEN Delay_Minutes BETWEEN 30 AND 59 THEN '30-60 min'
        ELSE '60+ min'
    END AS Delay_Phase,
    COUNT(*) AS Total_Trips,
    CAST(
        ROUND(
            (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(),
        2) AS DECIMAL(5,2)
    ) AS Percentage,
    SUM(Delay_Minutes) AS Total_Delay_Minutes
FROM Trips
WHERE Trip_Status = 'Delayed'
GROUP BY
    CASE
        WHEN Delay_Minutes BETWEEN 0 AND 14 THEN '0-15 min'
        WHEN Delay_Minutes BETWEEN 15 AND 29 THEN '15-30 min'
        WHEN Delay_Minutes BETWEEN 30 AND 59 THEN '30-60 min'
        ELSE '60+ min'
    END
ORDER BY Delay_Phase

-- 6. Which routes are most affected by severe delays (60+ minutes)?
SELECT
    R.Route_Name,
    COUNT(T.Trip_ID) AS Total_Trips,
    SUM(CASE WHEN T.Delay_Minutes >= 60 THEN 1 ELSE 0 END) AS Severe_Delays,
    CAST(
        ROUND(
            (SUM(CASE WHEN T.Delay_Minutes >= 60 THEN 1 ELSE 0 END) * 100.0) / COUNT(T.Trip_ID),
        2) AS DECIMAL(5,2)
    ) AS Severe_Delay_Rate,
    SUM(CASE WHEN T.Delay_Minutes >= 60 THEN T.Delay_Minutes ELSE 0 END) AS Total_Severe_Delay_Minutes
FROM Trips T
JOIN Routes R
    ON R.Route_ID = T.Route_ID
GROUP BY R.Route_Name
HAVING SUM(CASE WHEN T.Delay_Minutes >= 60 THEN 1 ELSE 0 END) > 0
ORDER BY Severe_Delay_Rate DESC, Total_Severe_Delay_Minutes DESC

-- 7. What is the most common delay reason per route?
WITH DelayCounts AS (
    SELECT
        R.Route_Name,
        T.DelayOrCancelled_Reason,
        COUNT(*) AS Delay_Count,
        ROW_NUMBER() OVER (
            PARTITION BY R.Route_Name
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM Trips T
    JOIN Routes R
        ON R.Route_ID = T.Route_ID
    WHERE T.DelayOrCancelled_Reason <> 'No Delay'
    GROUP BY R.Route_Name, T.DelayOrCancelled_Reason
)
SELECT
    Route_Name,
    DelayOrCancelled_Reason AS Most_Common_Delay_Reason,
    Delay_Count
FROM DelayCounts
WHERE rn = 1
ORDER BY Delay_Count DESC

-- 8. How does Peak vs Off-Peak affect delay rates?
SELECT
    Peak_Category,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 END) AS Delayed_Trips,CAST(
    ROUND(
    (SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 END) * 100.0) / COUNT(*), 2)
    AS DECIMAL(5, 2)) AS DelayedTrips_Rate,
    SUM(Delay_Minutes) AS Total_Delay_Minutes,
    ROUND(AVG(CAST(Delay_Minutes AS FLOAT)), 2) AS AVG_Delay_PerTrip,
    AVG(CASE WHEN Delay_Minutes > 0 THEN Delay_Minutes END) AS AVG_Delay_Per_DelayedTrip
FROM Trips
GROUP BY Peak_Category
ORDER BY DelayedTrips_Rate DESC

-- 9. How does time of day affect delays?
SELECT
    CASE 
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Night'
    END AS Time_Of_Day,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 ELSE 0 END) AS Delayed_Trips,
    CAST(
        SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*) AS DECIMAL(5,2)) AS Delay_Rate_Percentage,
    ROUND(AVG(CAST(Delay_Minutes AS FLOAT)), 2) AS Avg_Delay_Minutes
FROM Trips
GROUP BY 
    CASE 
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Night'
    END
ORDER BY Delay_Rate_Percentage DESC

-- 10. How does delay affect refund probability?
SELECT
    CASE
        WHEN T.Delay_Minutes <= 0 THEN 'No Delay'
        WHEN T.Delay_Minutes BETWEEN 1 AND 14 THEN '0-15 min'
        WHEN T.Delay_Minutes BETWEEN 15 AND 29 THEN '15-30 min'
        WHEN T.Delay_Minutes BETWEEN 30 AND 59 THEN '30-60 min'
        ELSE '60+ min'
    END AS Delay_Phase,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN TR.Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Tickets,
    CAST(
        ROUND(
            (SUM(CASE WHEN TR.Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*),
        2) AS DECIMAL(5,2)
    ) AS Refund_Probability_Percentage
FROM Trips T JOIN Transactions TR
ON TR.Trip_ID = T.Trip_ID
GROUP BY
    CASE
        WHEN T.Delay_Minutes <= 0 THEN 'No Delay'
        WHEN T.Delay_Minutes BETWEEN 1 AND 14 THEN '0-15 min'
        WHEN T.Delay_Minutes BETWEEN 15 AND 29 THEN '15-30 min'
        WHEN T.Delay_Minutes BETWEEN 30 AND 59 THEN '30-60 min'
        ELSE '60+ min'
    END
ORDER BY Delay_Phase DESC