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

SELECT * FROM Railway_Cleaned

-- * Feature Engineering * --

-- 1.Peak Category
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

-- 2.Delay Minutes
ALTER TABLE Railway_Cleaned
ADD Delay_Minutes INT

UPDATE Railway_Cleaned
SET Delay_Minutes = DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)

-- 3.Journey Duration Minutes
ALTER TABLE railway_cleaned
ADD Journey_Duration_Minutes INT

UPDATE railway_cleaned
SET Journey_Duration_Minutes = 
CASE
	WHEN DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time) < 0
	THEN DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time) + 1440
	ELSE DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time)
END

-- 4. Discount
ALTER TABLE Railway_Cleaned
ADD 
    Original_Price MONEY,
    Discount FLOAT,
    Discount_Amount MONEY,
    Final_Price MONEY

UPDATE Railway_Cleaned
SET Discount = 
    (CASE WHEN Railcard <> 'None' THEN 0.30 ELSE 0 END) +
    (CASE WHEN Ticket_Type = 'Advance' THEN 0.50 ELSE 0 END) +
    (CASE WHEN Ticket_Type = 'Off-Peak' THEN 0.25 ELSE 0 END)
    
UPDATE Railway_Cleaned
SET Original_Price =
CASE
    WHEN Discount = 0 THEN Price
    ELSE Price / (1 - Discount)
END

UPDATE Railway_Cleaned
SET Discount_Amount = Original_Price - Price

UPDATE Railway_Cleaned
SET Final_Price = Price

-- 5.Refunded Amount
ALTER TABLE Railway_Cleaned
ADD Refunded_Amount MONEY

UPDATE Railway_Cleaned
SET Refunded_Amount = 
	CASE
		WHEN Journey_Status = 'Cancelled' AND Refund_Request = 'Yes' THEN Final_Price
		WHEN Journey_Status = 'Delayed' AND Refund_Request = 'Yes' THEN
			CASE
				WHEN Delay_Minutes >= 60 THEN Final_Price * 0.75
				WHEN Delay_Minutes >= 30 AND Delay_Minutes < 60 THEN Final_Price * 0.50
				WHEN Delay_Minutes >= 15 AND Delay_Minutes < 30 THEN Final_Price * 0.25
                WHEN Delay_Minutes >= 1 AND Delay_Minutes < 15 THEN Final_Price * 0.05
				ELSE 0
			END
		ELSE 0
	END

-- 6.Profit
ALTER TABLE Railway_Cleaned
ADD Profit MONEY

UPDATE Railway_Cleaned
SET Profit = Final_Price - Refunded_Amount

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
    Original_Price MONEY,
    Discount FLOAT,
    Discount_Amount MONEY,
    Final_Price MONEY,
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
    R.Original_Price,
    R.Discount,
    R.Discount_Amount,
    R.Final_Price,
    R.Refund_Request,
    R.Refunded_Amount,
    R.Profit
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

------------ Analysis ------------
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
---------------------------------------------------
---------------------------------------------------
-- ((( Trip Operations Performance )))

-- 12. How many total trips are there?
SELECT COUNT(*) AS Total_Trips
FROM Trips

-- 13. What is the distribution of trip status (On Time, Delayed, Cancelled)?
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

-- 14. How are trips distributed across weekdays vs weekends?
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

-- 15. How many trips occur during Peak vs Off-Peak periods?
SELECT
    Peak_Category,
    COUNT(*) AS Total_Trips,
    CAST(
        (COUNT(*) * 100.0) / SUM(COUNT(*)) OVER()
        AS DECIMAL(5,2)) AS Percentage
FROM Trips
GROUP BY Peak_Category
ORDER BY Total_Trips DESC

-- 16. What is the average, longest, shortest trip duration?
SELECT
    ROUND(AVG(CAST(Trip_Duration AS FLOAT)), 2) AS AVG_Trip_Duration,
    MAX(Trip_Duration) AS Longest_Trip,
    MIN(Trip_Duration) AS Shortest_Trip
FROM Trips

-- 17. How are trips distributed across different times of the day?
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
---------------------------------------------------
---------------------------------------------------
-- ((( Route Performance )))

-- 18. How many unique routes are there?
SELECT COUNT(*) AS Total_Routes
FROM Routes

-- 19. Which routes have the highest number of transactions & trips?
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

-- 20. Which routes have the highest delay rate?
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

-- 21. Which routes have the highest cancellation rate?
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

-- 22. Which routes have the highest On-Time performance rate?
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
---------------------------------------------------
---------------------------------------------------
-- ((( Revenue & Pricing Analysis )))

-- 23. What is the total revenue before discounts?
SELECT ROUND(SUM(Original_Price), 2) AS Revenue_Before_Discounts
FROM Transactions

-- 24. What is the total revenue after discounts?
SELECT ROUND(SUM(Final_Price), 2) AS Revenue_After_Discounts
FROM Transactions

-- 25. How much revenue is lost due to discounts?
SELECT ROUND(SUM(Discount_Amount), 2) AS Revenue_Loss
FROM Transactions

-- 26. What is the total profit?
SELECT SUM(Profit) AS Net_Profit
FROM Transactions

-- 27. What is the average revenue and profit per transaction?
SELECT
	ROUND(AVG(Final_Price), 2) AS AVG_Price,
	ROUND(AVG(Profit), 2) AS AVG_Profit
FROM Transactions

-- 28. What percentage of total revenue is impacted by discounts?
SELECT
    ROUND(SUM(Original_Price), 2) AS Total_Revenue_Before_Discount,
    ROUND(SUM(Discount_Amount), 2) AS Total_Discount_Value,
    SUM(Final_Price) AS Total_Revenue_After_Discount,
    CAST(
        (SUM(Discount_Amount) * 100.0) / SUM(Original_Price)
        AS DECIMAL(5,2)) AS Discount_Impact_Percentage
FROM Transactions

-- 29. Which ticket types generate the highest revenue?
SELECT
    Ticket_Type,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Ticket_Type
ORDER BY Gross_Revenue DESC

-- 30. Which ticket class generates the highest revenue?
SELECT
    Ticket_Class,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Ticket_Class
ORDER BY Gross_Revenue DESC

-- 31. Which payment methods generate the highest revenue?
SELECT
    Payment_Method,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Payment_Method
ORDER BY Gross_Revenue DESC

-- 32. Which purchase type generates the highest revenue?
SELECT
    Purchase_Type,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Purchase_Type
ORDER BY Gross_Revenue DESC

-- 33. Which routes generate the highest revenue and profit?
SELECT TOP 10
    R.Route_Name,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Routes R JOIN Transactions T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Gross_Revenue DESC

-- 34. Which railcard generates the highest revenue and profit?
SELECT
    Railcard,
    COUNT(*) AS Total_Transactions,
    SUM(Final_Price) AS Total_Revenue,
    SUM(Discount_Amount) AS Total_Discount,
    SUM(Profit) AS Total_Profit,
    ROUND(AVG(Final_Price), 2) AS Avg_Ticket_Price
FROM Transactions
GROUP BY Railcard
ORDER BY Total_Revenue DESC

-- 35. How do Railcard revenue compare to non-Railcard?
SELECT
    CASE 
        WHEN Railcard = 'None' THEN 'No Railcard'
        ELSE 'Railcard'
    END AS Railcard_Type,
    COUNT(*) AS Total_Transactions,
    COUNT(DISTINCT Trip_ID) AS Total_Trips,
    SUM(Final_Price) AS Total_Revenue,
    ROUND(SUM(Discount_Amount), 2) AS Total_Discount,
    SUM(Profit) AS Total_Profit,
    ROUND(AVG(Final_Price), 2) AS Avg_Ticket_Price
FROM Transactions
GROUP BY 
    CASE 
        WHEN Railcard = 'None' THEN 'No Railcard'
        ELSE 'Railcard'
    END

-- 36. Do discounted tickets generate higher or lower profit than full-price tickets?
SELECT
    CASE 
        WHEN Discount > 0 THEN 'Discounted Tickets'
        ELSE 'Full Price Tickets'
    END AS Ticket_Pricing_Type,
    COUNT(*) AS Total_Transactions,
    SUM(Profit) AS Total_Profit,
    ROUND(AVG(Profit), 2) AS Avg_Profit_Per_Transaction
FROM Transactions
GROUP BY 
    CASE 
        WHEN Discount > 0 THEN 'Discounted Tickets'
        ELSE 'Full Price Tickets'
    END

-- 37. How does pricing strategy affect overall profitability?
SELECT
    CASE 
        WHEN Discount = 0 THEN 'No Discount'
        WHEN Discount > 0 AND Discount <= 0.25 THEN '1-25%'
        WHEN Discount > 0.25 AND Discount <= 0.50 THEN '26-50%'
        ELSE '>50%'
    END AS Discount_Level,
    COUNT(*) AS Total_Transactions,
    SUM(Final_Price) AS Total_Revenue,
    ROUND(SUM(Discount_Amount), 2) AS Total_Discount,
    SUM(Profit) AS Total_Profit,
    ROUND(AVG(Profit), 2) AS Avg_Profit_Per_Transaction,
    CAST(
        SUM(Profit) * 100.0 / SUM(Final_Price)
        AS DECIMAL(5,2)) AS Profit_Margin_Percentage
FROM Transactions
GROUP BY 
    CASE 
        WHEN Discount = 0 THEN 'No Discount'
        WHEN Discount > 0 AND Discount <= 0.25 THEN '1-25%'
        WHEN Discount > 0.25 AND Discount <= 0.50 THEN '26-50%'
        ELSE '>50%'
    END
ORDER BY Profit_Margin_Percentage DESC
---------------------------------------------------
---------------------------------------------------
-- ((( Refund & Risk Analysis )))

-- 38. What is the total refunded amount and its percentage?
SELECT
	SUM(Refunded_Amount) AS Total_Refunds,
	CAST(
    (SUM(Refunded_Amount) * 100.0) / SUM(Final_Price) AS DECIMAL(5, 2)) AS Refunds_Percentage
FROM Transactions

-- 39. What percentage of transactions include refund requests?
SELECT
    Refund_Request,
    COUNT(*) AS Requests,
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)) AS Percentage
FROM Transactions
GROUP BY Refund_Request
ORDER BY Requests DESC

-- 40. What is the average refund amount per transaction?
SELECT
    ROUND(AVG(Refunded_Amount), 2) AS AVG_Refund_Per_Transaction,
    ROUND(AVG(CASE WHEN Refunded_Amount > 0 THEN Refunded_Amount END), 2)
    AS AVG_Refund_Per_Refunded_Ticket
FROM Transactions

-- 41. Which ticket types have the highest refund rate?
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

-- 42. Which routes generate the highest refund amounts?
SELECT TOP 10
    R.Route_Name,
    SUM(T.Refunded_Amount) AS Total_Refunds
FROM Routes R
JOIN Transactions T
    ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Total_Refunds DESC

-- 43. Are refunds more driven by cancellations or delays?
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

-- 44. Which routes are high-risk (high delay + high refund)?
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
---------------------------------------------------
---------------------------------------------------
-- ((( Delay & Service Reliability )))

-- 45. What is the overall delay rate in the system?
SELECT
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 ELSE 0 END) AS Delayed_Trips,
    CAST(
        SUM(CASE WHEN Trip_Status = 'Delayed' THEN 1 ELSE 0 END) * 100.0
        / COUNT(*) AS DECIMAL(5,2)) AS Delay_Rate_Percentage
FROM Trips

-- 46. What is the average, minimum, and maximum delay time?
SELECT
    SUM(Delay_Minutes) AS Total_Delay_Minutes,
    ROUND(AVG(CAST(Delay_Minutes AS FLOAT)), 2) AS AVG_Delay_Per_Trip,
    AVG(CASE WHEN Delay_Minutes > 0 THEN Delay_Minutes END) AS AVG_Delay_Per_DelayedTrips,
    MAX(Delay_Minutes) AS Longest_Delay,
    MIN(CASE WHEN Delay_Minutes > 0 THEN Delay_Minutes END) AS Shortest_Delay
FROM Trips

-- 47. What are the most common reasons for Delays?
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

-- 48. What are the most common reasons for cancellations?
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

-- 49. How are delays distributed across severity levels (0–15, 15–30, 30–60, 60+ minutes)?
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

-- 50. Which routes are most affected by severe delays (60+ minutes)?
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

-- 51. What is the most common delay reason per route?
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

-- 52. How does Peak vs Off-Peak affect delay rates?
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

-- 53. How does time of day affect delays?
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

-- 54. How does delay affect refund probability?
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