-- ((( Customer & Sales Activity Overview )))

-- 1. How many total transactions are there?
SELECT COUNT(*) AS Total_Transactions
FROM Transactions

-- 2. How are transactions distributed over time (year, quarter, month, day)?
-- Years
SELECT
    DATEPART(YEAR, Purchase_Date) AS Year,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY
    DATEPART(YEAR, Purchase_Date)
ORDER BY Year

-- Quarter
SELECT
    DATEPART(QUARTER, Purchase_Date) AS Quarter,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY
    DATEPART(YEAR, Purchase_Date),
    DATEPART(QUARTER, Purchase_Date)
ORDER BY DATEPART(YEAR, Purchase_Date)

-- Months
SELECT
    DATENAME(MONTH, Purchase_Date) AS Month_Name,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY
    DATEPART(YEAR, Purchase_Date),
    DATEPART(MONTH, Purchase_Date),
    DATENAME(MONTH, Purchase_Date)
ORDER BY DATEPART(YEAR, Purchase_Date)

-- Days of Month
SELECT
    DATEPART(DAY, Purchase_Date) AS Day_Num,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY DATEPART(DAY, Purchase_Date)
ORDER BY Day_Num

-- Days of Week
SELECT
    DATENAME(WEEKDAY, Purchase_Date) AS Day_Name,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY
    DATENAME(WEEKDAY, Purchase_Date),
    DATEPART(WEEKDAY, Purchase_Date)
ORDER BY DATEPART(WEEKDAY, Purchase_Date)

-- 3. What are the busiest days and hours for transactions?
SELECT
    DATEPART(HOUR, Purchase_Time) AS Hour,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY DATEPART(HOUR, Purchase_Time)
ORDER BY Hour

-- 4. What is the distribution of purchase types?
SELECT
    Purchase_Type,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Percentage
FROM Transactions
GROUP BY Purchase_Type
ORDER BY Total_Transactions DESC

-- 5. What are the most commonly used payment methods?
SELECT
    Payment_Method,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Percentage
FROM Transactions
GROUP BY Payment_Method
ORDER BY Total_Transactions DESC

-- 6. Which ticket classes are most popular?
SELECT
    Ticket_Class,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Percentage
FROM Transactions TR JOIN Trips T
ON TR.Trip_ID = T.Trip_ID
GROUP BY Ticket_Class
ORDER BY Total_Transactions DESC

-- 7. Which ticket types are most frequently purchased?
SELECT
    Ticket_Type,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Percentage
FROM Transactions TR JOIN Trips T
ON TR.Trip_ID = T.Trip_ID
GROUP BY Ticket_Type
ORDER BY Total_Transactions DESC

-- 8. What is the distribution of railcard usage?
SELECT
    Railcard,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Percentage
FROM Transactions
WHERE Railcard <> 'None'
GROUP BY Railcard
ORDER BY Total_Transactions DESC

-- 9. How do transactions differ between railcard and non-railcard users?
SELECT
    CASE
        WHEN Railcard = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END AS Railcard_Type,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Transactions_Percentage
FROM Transactions
GROUP BY
    CASE
        WHEN Railcard = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END
ORDER BY Total_Transactions DESC

-- 10. What is the average ticket price per transaction?
SELECT ROUND(AVG(Final_Price), 2) AS AVG_Price
FROM Transactions

-- 11. How far in advance are tickets purchased (Purchase Date vs Journey Date)?
SELECT
    DATEDIFF(DAY, Purchase_Date, T.Trip_Date) AS Days_Before_Travel,
    COUNT(*) AS Total_Transactions,
    CAST(
        (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)
    ) AS Percentage
FROM Transactions TR JOIN Trips T
ON TR.Trip_ID = T.Trip_ID
GROUP BY DATEDIFF(DAY, Purchase_Date, T.Trip_Date)
ORDER BY Days_Before_Travel