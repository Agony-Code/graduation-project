CREATE DATABASE UK_Train_Rides_DEPI

USE UK_Train_Rides_DEPI

CREATE TABLE Railway (
	Transaction_ID VARCHAR(100),
	Date_Of_Purchase DATE,
	Time_Of_Purchase TIME(0),
	Purchase_Type VARCHAR(20),
	Payment_Method VARCHAR(20),
	Railcard VARCHAR(20),
	Ticket_Class VARCHAR(20),
	Ticket_Type VARCHAR(20),
	Price MONEY,
	Departure_Station VARCHAR(100),
	Arrival_Station VARCHAR(100),
	Date_Of_Journey DATE,
	Departure_Time TIME(0),
	Arrival_Time TIME(0),
	Actual_Arrival_Time TIME(0),
	Journey_Status VARCHAR(20),
	Reason_for_Delay VARCHAR(20),
	Refund_Request VARCHAR(20)
	CONSTRAINT Railway_PK PRIMARY KEY (Transaction_ID)
)

BULK INSERT Railway
FROM 'C:\Users\01004\OneDrive\Desktop\DEPI_Final_PJ\Data\railway.csv'
WITH (
	FORMAT = 'CSV',
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n'
)

SELECT * FROM Railway

-- Creating a Copy
SELECT *
INTO Railway_Cleaned
FROM Railway

-- Sorting By Date_Of_Purchase, Journey Ascending
CREATE CLUSTERED INDEX idx_Railway_Date
ON Railway_Cleaned(Date_Of_Purchase, Date_Of_Journey)

SELECT * FROM Railway_Cleaned

-- Editing Inconsistent & Duplicated Data
SELECT Transaction_ID, COUNT(*) AS #Num
FROM Railway_Cleaned
GROUP BY Transaction_ID
HAVING COUNT(*) > 1

-- Editing Missing Values
UPDATE Railway_Cleaned
SET Reason_for_Delay = 'No Delay'
WHERE Reason_for_Delay IS NULL
AND Journey_Status = 'On Time'

UPDATE Railway_Cleaned
SET Reason_for_Delay = 'Signal Failure'
WHERE Reason_for_Delay = 'Signal failure'

UPDATE Railway_Cleaned
SET Reason_for_Delay = 'Weather'
WHERE Reason_for_Delay = 'Weather Conditions'

UPDATE Railway_Cleaned
SET Reason_for_Delay = 'Staff Shortage'
WHERE Reason_for_Delay = 'Staffing'

SELECT DISTINCT Reason_for_Delay
FROM Railway_Cleaned

UPDATE Railway_Cleaned
SET Refund_Request = 'Yes'
WHERE Refund_Request LIKE '%Yes%'

UPDATE Railway_Cleaned
SET Refund_Request = 'No'
WHERE Refund_Request LIKE '%No%'

-- Searching For Errors In The Data
SELECT *
FROM Railway_Cleaned
WHERE Refund_Request = 'Yes'
AND Journey_Status = 'On Time' --> 0 Errors

SELECT *
FROM Railway_Cleaned
WHERE Arrival_Time <> Actual_Arrival_Time
AND Journey_Status = 'On Time' --> 0 Errors

SELECT *
FROM Railway_Cleaned
WHERE Arrival_Time = Actual_Arrival_Time
AND Journey_Status <> 'On Time' --> 18 Errors

-- Solving Them
UPDATE Railway_Cleaned
SET
	Journey_Status = 'On Time',
	Reason_for_Delay = 'No Delay',
	Refund_Request = 'No'
WHERE Arrival_Time = Actual_Arrival_Time
AND Journey_Status <> 'On Time'

SELECT *
FROM Railway_Cleaned
WHERE Actual_Arrival_Time IS NULL
AND Journey_Status <> 'Cancelled' --> 0 Errors

-- Advance Tickets Must Be Purchased At Least a Day Prior To Departure
SELECT *
FROM Railway_Cleaned
WHERE Ticket_Type = 'Advance'
AND Date_Of_Purchase = Date_Of_Journey --> 0 Errors

-- Off-Peak Tickets Must Be Used Outside Of Peak Hours (Weekdays Between 6-8am & 4-6pm)
SELECT *
FROM Railway_Cleaned
WHERE Ticket_Type = 'Off-Peak'
AND DATEPART(WEEKDAY, Date_Of_Journey) BETWEEN 2 AND 6
AND 
	(Departure_Time BETWEEN '06:00:00' AND '08:00:00'
	OR Departure_Time BETWEEN '16:00:00' AND '18:00:00' ) --> 0 Errors

-- Advance Ticket Is Non_Refundable
SELECT *
FROM Railway_Cleaned
WHERE Ticket_Type = 'Advance'
AND Refund_Request = 'Yes'
AND Journey_Status = 'Delayed' --> 282 Errors

UPDATE Railway_Cleaned
SET Refund_Request = 'Non_Refundable'
WHERE Ticket_Type = 'Advance'
AND Journey_Status = 'Delayed'

SELECT * FROM Railway_Cleaned

-- * Feature Engineering * --

-- 1.Delay Minutes
ALTER TABLE Railway_Cleaned
ADD Delay_Minutes INT

UPDATE Railway_Cleaned
SET Delay_Minutes = DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)

-- 2.Journey Duration Minutes
ALTER TABLE railway_cleaned
ADD Journey_Duration_Minutes INT

UPDATE railway_cleaned
SET Journey_Duration_Minutes = 
CASE
	WHEN DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time) < 0
	THEN DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time) + 1440
	ELSE DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time)
END

-- 3.Refunded Amount
ALTER TABLE Railway_Cleaned
ADD Refunded_Amount MONEY

UPDATE Railway_Cleaned
SET Refunded_Amount = 
	CASE
		WHEN Journey_Status = 'Cancelled' AND Refund_Request = 'Yes' THEN Price
		WHEN Journey_Status = 'Delayed' AND Refund_Request = 'Yes' THEN
			CASE
				WHEN Delay_Minutes >= 60 THEN Price
				WHEN Delay_Minutes >= 30 AND Delay_Minutes <= 59 THEN Price * 0.5
				WHEN Delay_Minutes >= 15 AND Delay_Minutes <= 29 THEN Price * 0.25
				ELSE 0
			END
		ELSE 0
	END

-- 4.Peak Category
ALTER TABLE Railway_Cleaned
ADD Peak_Category VARCHAR(50)

UPDATE Railway_Cleaned
SET Peak_Category = 
CASE 
    WHEN DATENAME(WEEKDAY, Date_Of_Journey) IN ('Monday','Tuesday','Wednesday','Thursday','Friday')
         AND (
             Departure_Time BETWEEN '06:00:00' AND '08:00:00'
             OR Departure_Time BETWEEN '16:00:00' AND '18:00:00'
         )
    THEN 'Peak'
    ELSE 'Off-Peak'
END

SELECT * FROM Railway_Cleaned

-- * Normalization * --

-- 1. Routes
CREATE TABLE Routes (
    Route_ID INT IDENTITY(1, 1),
    Departure_Station VARCHAR(100),
    Arrival_Station VARCHAR(100),
    Route_Name VARCHAR(100)
    CONSTRAINT Routes_PK PRIMARY KEY (Route_ID)
)

INSERT INTO Routes
SELECT DISTINCT
    Departure_Station,
    Arrival_Station,
    Departure_Station + '_' + Arrival_Station
FROM Railway_Cleaned
ORDER BY Departure_Station, Arrival_Station

SELECT * FROM Routes

-- 2. Trips
CREATE TABLE Trips (
    Trip_ID INT IDENTITY(1, 1),
    Trip_Date DATE,
    Route_ID INT,
    Departure_Time TIME(0),
    Peak_Category VARCHAR(50),
    Arrival_Time TIME(0),
    Actual_Arrival_Time TIME(0),
    Trip_Duration INT,
    Trip_Status VARCHAR(50),
    DelayOrCancelled_Reason VARCHAR(50),
    Delay_Minutes INT
    CONSTRAINT Trips_PK PRIMARY KEY (Trip_ID),
    CONSTRAINT Trips_Routes_FK FOREIGN KEY (Route_ID) REFERENCES Routes (Route_ID)
)

INSERT INTO Trips
SELECT
    R.Date_Of_Journey,
    RT.Route_ID,
    R.Departure_Time,
    R.Peak_Category,
    R.Arrival_Time,
    MAX(R.Actual_Arrival_Time),
    MAX(R.Journey_Duration_Minutes),
    MAX(R.Journey_Status),
    MAX(R.Reason_for_Delay),
    MAX(R.Delay_Minutes)
FROM Railway_Cleaned R JOIN Routes RT
ON R.Departure_Station = RT.Departure_Station
AND R.Arrival_Station = RT.Arrival_Station
GROUP BY
    R.Date_Of_Journey,
    RT.Route_ID,
    R.Departure_Time,
    R.Peak_Category,
    R.Arrival_Time
ORDER BY R.Date_Of_Journey, R.Departure_Time

SELECT * FROM Trips

-- 3. Transactions
CREATE TABLE Transactions (
    Transaction_ID VARCHAR(100),
    Trip_ID INT,
    Route_ID INT,
    Purchase_Date DATE,
    Purchase_Time TIME(0),
    Purchase_Type VARCHAR(50),
    Payment_Method VARCHAR(50),
    Railcard VARCHAR(50),
    Ticket_Class VARCHAR(50),
    Ticket_Type VARCHAR(50),
    Price MONEY,
    Refund_Request VARCHAR(50),
    Refunded_Amount MONEY,
    Profit MONEY
    CONSTRAINT Transactions_PK PRIMARY KEY NONCLUSTERED (Transaction_ID),
    CONSTRAINT Transactions_Trips_FK FOREIGN KEY (Trip_ID) REFERENCES Trips (Trip_ID),
    CONSTRAINT Transactions_Routes_FK FOREIGN KEY (Route_ID) REFERENCES Routes (Route_ID)
)

INSERT INTO Transactions
SELECT
    R.Transaction_ID,
    T.Trip_ID,
    RT.Route_ID,
    R.Date_Of_Purchase,
    R.Time_Of_Purchase,
    R.Purchase_Type,
    R.Payment_Method,
    R.Railcard,
    R.Ticket_Class,
    R.Ticket_Type,
    R.Price,
    R.Refund_Request,
    R.Refunded_Amount,
    R.Price - R.Refunded_Amount
FROM Railway_Cleaned R JOIN Routes RT
ON LTRIM(RTRIM(R.Departure_Station)) = LTRIM(RTRIM(RT.Departure_Station))
AND LTRIM(RTRIM(R.Arrival_Station)) = LTRIM(RTRIM(RT.Arrival_Station))
JOIN Trips T
ON T.Route_ID = RT.Route_ID
AND T.Trip_Date = R.Date_Of_Journey
AND T.Departure_Time = R.Departure_Time
AND T.Arrival_Time = R.Arrival_Time

CREATE CLUSTERED INDEX idx_Transactions
ON Transactions(Purchase_Date, Purchase_Time, Trip_ID)

SELECT * FROM Transactions

------------------
-- * Analysis * --
------------------
----------------------------------------------------
----------------------------------------------------
-- ((((( 1. Route Analysis )))))

-- 1. How many unique routes are there?
SELECT COUNT(*) AS Total_Routes
FROM Routes

-- 2. Which routes have the highest number of trips?
SELECT
    R.Route_Name,
    COUNT(T.Trip_ID) AS Total_Trips
FROM Routes R JOIN Trips T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Total_Trips DESC

-- 3. Which routes have the highest number of transactions?
SELECT
    R.Route_Name,
    COUNT(*) AS Tickets
FROM Routes R JOIN Transactions T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Tickets DESC

-- 4. Which routes generate the highest revenue?
SELECT
    R.Route_Name,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Profit) AS Net_Revenue
FROM Routes R JOIN Transactions T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Gross_Revenue DESC

-- 5. Which routes have the highest delay rate?
SELECT
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

-- 6. Which routes have the highest cancellation rate?
SELECT
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

-- 7. Which routes have the highest On-Time performance rate?
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

-- 8. What is the most common delay reason per route?
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
----------------------------------------------------
----------------------------------------------------
-- ((((( 2. Trip Analysis )))))

-- 9. How many total trips are there?
SELECT COUNT(*) AS Total_Trips
FROM Trips

-- 10. What is the distribution of trip status (On Time, Delayed, Cancelled)?
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

-- 11. How are trips distributed across weekdays vs weekends?
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

-- 12. How many trips occur during Peak vs Off-Peak periods?
SELECT
    Peak_Category,
    COUNT(*) AS Total_Trips,
    CAST(
        (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)) AS Percentage
FROM Trips
GROUP BY Peak_Category
ORDER BY Total_Trips DESC

-- 13. What is the average trip duration?
SELECT
    ROUND(AVG(CAST(Trip_Duration AS FLOAT)), 2) AS AVG_Trip_Duration
FROM Trips

-- 14. What are the shortest and longest trip durations?
SELECT
    MAX(Trip_Duration) AS Longest_Trip,
    MIN(Trip_Duration) AS Shortest_Trip
FROM Trips

-- 15. How does trip duration affect delay rate?
SELECT 
    CASE 
        WHEN Trip_Duration BETWEEN 0 AND 60 THEN '0-1 Hour'
        WHEN Trip_Duration BETWEEN 61 AND 120 THEN '1-2 Hours'
        WHEN Trip_Duration BETWEEN 121 AND 180 THEN '2-3 Hours'
        ELSE '3+ Hours'
    END AS Trip_Duration,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 END) AS Delayed_Trips,
    ROUND(AVG(CAST(Delay_Minutes AS FLOAT)), 2) AS Avg_Delay,
    CAST(
    ROUND(
    (SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 END) * 100.0) / COUNT(Trip_ID), 2)
    AS DECIMAL(5, 2)) AS Delay_Rate
FROM Trips
GROUP BY 
    CASE 
        WHEN Trip_Duration BETWEEN 0 AND 60 THEN '0-1 Hour'
        WHEN Trip_Duration BETWEEN 61 AND 120 THEN '1-2 Hours'
        WHEN Trip_Duration BETWEEN 121 AND 180 THEN '2-3 Hours'
        ELSE '3+ Hours'
    END
ORDER BY Trip_Duration
----------------------------------------------------
----------------------------------------------------
-- ((((( 3. Transaction Analysis )))))

-- 16. What is the total number of transactions?
SELECT COUNT(*) AS Total_Transactions
FROM Transactions

-- 17. How are transactions distributed over years, quarters, and months?
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

-- 18. How are transactions distributed across days of the month?
SELECT
    DATEPART(DAY, Purchase_Date) AS Day_Num,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY DATEPART(DAY, Purchase_Date)
ORDER BY Day_Num

-- 19. How are transactions distributed across days of the week?
SELECT
    DATENAME(WEEKDAY, Purchase_Date) AS Day_Name,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY
    DATENAME(WEEKDAY, Purchase_Date),
    DATEPART(WEEKDAY, Purchase_Date)
ORDER BY DATEPART(WEEKDAY, Purchase_Date)

-- 20. What are the busiest hours of the day for transactions?
SELECT
    DATEPART(HOUR, Purchase_Time) AS Hour,
    COUNT(*) AS Total_Transactions
FROM Transactions
GROUP BY DATEPART(HOUR, Purchase_Time)
ORDER BY Hour

-- 21. What is the most commonly used purchase type?
SELECT
    Purchase_Type,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Percentage
FROM Transactions
GROUP BY Purchase_Type
ORDER BY Total_Transactions DESC

-- 22. What is the most commonly used payment method?
SELECT
    Payment_Method,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Percentage
FROM Transactions
GROUP BY Payment_Method
ORDER BY Total_Transactions DESC

-- 23. Which ticket class is the most popular?
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

-- 24. Which ticket type is the most popular?
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

-- 25. What is the most commonly used railcard?
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

-- 26. How do railcard users compare to non-railcard users?
SELECT
    CASE
        WHEN Railcard = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END AS Railcard_Type,
    COUNT(*) AS Total_Transactions,
    CAST(
    ROUND((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Transactions_Percentage,
    COUNT(DISTINCT T.Trip_ID) AS Total_Trips,
    CAST(
    ROUND((COUNT(DISTINCT T.Trip_ID) * 100.0) / SUM(COUNT(*)) OVER(), 2)
    AS DECIMAL(5, 2)) AS Trips_Percentage
FROM Transactions TR JOIN Trips T
ON TR.Trip_ID = T.Trip_ID
GROUP BY
    CASE
        WHEN Railcard = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END
----------------------------------------------------
----------------------------------------------------
-- ((((( 4. Revenue Analysis )))))

-- 27. What is the total revenue?
SELECT SUM(Price) AS Total_Revenue
FROM Transactions

-- 28. What is the total profit?
SELECT SUM(Profit) AS Total_Profit
FROM Transactions

-- 29. What is the average ticket price?
SELECT ROUND(AVG(Price), 2) AS AVG_Price
FROM Transactions

-- 30. What is the average profit per transaction?
SELECT ROUND(AVG(Profit), 2) AS AVG_Profit
FROM Transactions

-- 31. Which ticket type generates the highest revenue?
SELECT
    Ticket_Type,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Total_Refunds,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Ticket_Type
ORDER BY Gross_Revenue DESC

-- 32. Which ticket class generates the highest revenue?
SELECT
    Ticket_Class,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Total_Refunds,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Ticket_Class
ORDER BY Gross_Revenue DESC

-- 33. Which payment method generates the highest revenue?
SELECT
    Payment_Method,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Total_Refunds,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Payment_Method
ORDER BY Gross_Revenue DESC

-- 34. Which purchase type generates the highest revenue?
SELECT
    Purchase_Type,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Total_Refunds,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Purchase_Type
ORDER BY Gross_Revenue DESC

-- 35. Which routes generate the highest revenue?
SELECT
    R.Route_Name,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Profit) AS Net_Revenue
FROM Routes R JOIN Transactions T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Gross_Revenue DESC
----------------------------------------------------
----------------------------------------------------
-- ((((( 5. Refund Analysis )))))

-- 36. What is the total refunded amount?
SELECT SUM(Refunded_Amount) AS Total_Refunds
FROM Transactions

-- 37. What is the refund percentage?
SELECT CAST(
    (SUM(Refunded_Amount) * 100.0) / SUM(Price) AS DECIMAL(5, 2)) AS Refunds_Percentage
FROM Transactions

-- 38. What percentage of transactions include refund requests?
SELECT
    Refund_Request,
    COUNT(*) AS Requests,
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)) AS Percentage
FROM Transactions
GROUP BY Refund_Request
ORDER BY Requests DESC

-- 39. Which ticket types have the highest refund rate?
SELECT
    Ticket_Type,
    COUNT(*) AS Total_Transactions,
    SUM(CASE WHEN Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Transactions,
    CAST(
        ROUND(
            (SUM(CASE WHEN Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*),
        2) AS DECIMAL(5,2)
    ) AS Refund_Rate_Percentage
FROM Transactions
GROUP BY Ticket_Type
ORDER BY Refund_Rate_Percentage DESC

-- 40. Which routes have the highest refund amount?
SELECT
    R.Route_Name,
    SUM(T.Refunded_Amount) AS Total_Refunds
FROM Routes R
JOIN Transactions T
    ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Total_Refunds DESC

-- 41. How does delay affect refund probability?
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
----------------------------------------------------
----------------------------------------------------
-- ((((( 6. Delay Analysis )))))

-- 42. What is the overall delay performance (average, max, min delay minutes)?
SELECT
    SUM(Delay_Minutes) AS Total_Delay_Minutes,
    ROUND(AVG(CAST(Delay_Minutes AS FLOAT)), 2) AS AVG_Delay_Per_Trip,
    AVG(CASE WHEN Delay_Minutes > 0 THEN Delay_Minutes END) AS AVG_Delay_Per_DelayedTrips,
    MAX(Delay_Minutes) AS Longest_Delay,
    MIN(CASE WHEN Delay_Minutes > 0 THEN Delay_Minutes END) AS Shortest_Delay
FROM Trips

-- 43. What are the most common reasons for delays?
SELECT
    DelayOrCancelled_Reason AS Delay_Reason,
    COUNT(*) AS Total_Delays,
    CAST(
        ROUND(
            (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(),
        2) AS DECIMAL(5,2)
    ) AS Percentage
FROM Trips
WHERE Trip_Status = 'Delayed'
GROUP BY DelayOrCancelled_Reason
ORDER BY Total_Delays DESC

-- 44. What are the most common reasons for cancellations?
SELECT
    DelayOrCancelled_Reason AS Cancellation_Reason,
    COUNT(*) AS Total_Cancelled,
    CAST(
        ROUND(
            (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(),
        2) AS DECIMAL(5,2)
    ) AS Percentage
FROM Trips
WHERE Trip_Status = 'Cancelled'
GROUP BY DelayOrCancelled_Reason
ORDER BY Total_Cancelled DESC

-- 45. How are delays distributed across delay phases (0–15, 15–30, 30–60, 60+ minutes)?
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
    ) AS Percentage
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

-- 46. Which delay phase contributes the most to total delay minutes?
SELECT
    CASE
        WHEN Delay_Minutes BETWEEN 0 AND 14 THEN '0-15 min'
        WHEN Delay_Minutes BETWEEN 15 AND 29 THEN '15-30 min'
        WHEN Delay_Minutes BETWEEN 30 AND 59 THEN '30-60 min'
        ELSE '60+ min'
    END AS Delay_Phase,
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
ORDER BY Total_Delay_Minutes DESC

-- 47. Which routes are most affected by severe delays (60+ minutes)?
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

-- 48. How does Peak vs Off-Peak affect delay rates?
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