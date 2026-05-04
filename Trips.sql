-- ((( Trip Operations Performance )))

-- 1. How many total trips are there?
SELECT COUNT(*) AS Total_Trips
FROM Trips

-- 2. What is the distribution of trip status (On Time, Delayed, Cancelled)?
SELECT
    Trip_Status,
    COUNT(*) AS Total_Trips,
    CAST(
    ROUND(
    (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Percentage
FROM Trips
GROUP BY Trip_Status
ORDER BY Total_Trips DESC

-- 3. How are trips distributed across weekdays vs weekends?
SELECT
    CASE
        WHEN DATEPART(WEEKDAY, Trip_Date) BETWEEN 2 AND 6
        THEN 'Weekdays'
        ELSE 'Weekends'
    END AS Day_Type,
    COUNT(*) AS Total_Trips,
    CAST(
        (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)) AS Percentage
FROM Trips
GROUP BY
    CASE
        WHEN DATEPART(WEEKDAY, Trip_Date) BETWEEN 2 AND 6
        THEN 'Weekdays'
        ELSE 'Weekends'
    END
ORDER BY Total_Trips DESC

-- 4. How many trips occur during Peak vs Off-Peak periods?
SELECT
    Peak_Category,
    COUNT(*) AS Total_Trips,
    CAST(
        (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)) AS Percentage
FROM Trips
GROUP BY Peak_Category
ORDER BY Total_Trips DESC

-- 5. What is the average, longest, shortest trip duration?
SELECT
    ROUND(AVG(CAST(Trip_Duration AS FLOAT)), 2) AS AVG_Trip_Duration,
    MAX(Trip_Duration) AS Longest_Trip,
    MIN(Trip_Duration) AS Shortest_Trip
FROM Trips

-- 6. How are trips distributed across different times of the day?
SELECT
    CASE
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Night'
    END AS Time_Of_Day,
    COUNT(*) AS Total_Trips,
    CAST(
        (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)
    ) AS Percentage
FROM Trips
GROUP BY
    CASE
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN DATEPART(HOUR, Departure_Time) BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Night'
    END
ORDER BY Total_Trips DESC