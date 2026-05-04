-- ((( Refund & Risk Analysis )))

-- 1. What is the total refunded amount and its percentage?
SELECT
	SUM(Refunded_Amount) AS Total_Refunds,
	CAST(
    (SUM(Refunded_Amount) * 100.0) / SUM(Final_Price) AS DECIMAL(5, 2)) AS Refunds_Percentage
FROM Transactions

-- 2. What percentage of transactions include refund requests?
SELECT
    Refund_Request,
    COUNT(*) AS Requests,
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)) AS Percentage
FROM Transactions
GROUP BY Refund_Request
ORDER BY Requests DESC

-- 3. What is the average refund amount per transaction?
SELECT
    ROUND(AVG(Refunded_Amount), 2) AS AVG_Refund_Per_Transaction,
    ROUND(AVG(CASE WHEN Refunded_Amount > 0 THEN Refunded_Amount END), 2)
    AS AVG_Refund_Per_Refunded_Ticket
FROM Transactions

-- 4. Which ticket types have the highest refund rate?
SELECT
    Ticket_Type,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Transactions,
    CAST(
        ROUND(
            (SUM(CASE WHEN Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*),
        2) AS DECIMAL(5,2)) AS Refund_Rate_Percentage
FROM Transactions
GROUP BY Ticket_Type
ORDER BY Refund_Rate_Percentage DESC

-- 5. Which routes generate the highest refund amounts?
SELECT TOP 10
    R.Route_Name,
    SUM(T.Refunded_Amount) AS Total_Refunds
FROM Routes R
JOIN Transactions T
    ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Total_Refunds DESC

-- 6. Are refunds more driven by cancellations or delays?
SELECT
    CASE 
        WHEN T.Trip_Status = 'Cancelled' THEN 'Cancellation Driven'
        WHEN T.Delay_Minutes > 0 THEN 'Delay Driven'
        ELSE 'No Issue'
    END AS Refund_Driver,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN TR.Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Transactions,
    CAST(
        SUM(CASE WHEN TR.Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0 
        / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS Refund_Rate_Percentage
FROM Trips T JOIN Transactions TR
ON T.Trip_ID = TR.Trip_ID
GROUP BY 
    CASE 
        WHEN T.Trip_Status = 'Cancelled' THEN 'Cancellation Driven'
        WHEN T.Delay_Minutes > 0 THEN 'Delay Driven'
        ELSE 'No Issue'
    END
ORDER BY Refund_Rate_Percentage DESC

-- 7. Which routes are high-risk (high delay + high refund)?
SELECT
    R.Route_Name,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN T.Delay_Minutes > 0 THEN 1 ELSE 0 END) AS Delayed_Trips,
    SUM(CASE WHEN TR.Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Trips,
    CAST(
        SUM(CASE WHEN T.Delay_Minutes > 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)) AS Delay_Rate,
    CAST(
        SUM(CASE WHEN TR.Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)) AS Refund_Rate
FROM Routes R JOIN Trips T
ON R.Route_ID = T.Route_ID
JOIN Transactions TR
ON TR.Trip_ID = T.Trip_ID
GROUP BY R.Route_Name
HAVING 
    SUM(CASE WHEN T.Delay_Minutes > 0 THEN 1 ELSE 0 END) > 0
    AND SUM(CASE WHEN TR.Refunded_Amount > 0 THEN 1 ELSE 0 END) > 0
ORDER BY Delay_Rate DESC, Refund_Rate DESC