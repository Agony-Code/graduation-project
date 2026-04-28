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
FROM 'C:\Users\01004\OneDrive\Desktop\Railway_PROJ\Data\railway.csv'
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

-- Sorting By Date_Of_Purchase Ascending
CREATE CLUSTERED INDEX idx_Railway_Date
ON Railway_Cleaned(Date_Of_Purchase)

SELECT * FROM Railway_Cleaned

-- Editing Missing Values
UPDATE Railway_Cleaned
SET Reason_for_Delay = 'No Delay'
WHERE Reason_for_Delay IS NULL
AND Journey_Status = 'On Time'

-- Editing Inconsistent & Duplicated Data
SELECT Transaction_ID, COUNT(*) AS #Num
FROM Railway_Cleaned
GROUP BY Transaction_ID
HAVING COUNT(*) > 1

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
				WHEN Delay_Minutes >= 120 THEN Price * 0.75
				WHEN Delay_Minutes >= 60 THEN Price * 0.5
				WHEN Delay_Minutes >= 30 THEN Price * 0.25
				ELSE 0
			END
		ELSE 0
	END

-- 4.Month Of Purchase
ALTER TABLE railway_cleaned
ADD Month_of_Purchase VARCHAR(50)

UPDATE railway_cleaned
SET Month_of_Purchase = DATENAME(MONTH, Date_of_Purchase)

-- 5.Purchase Hour
ALTER TABLE railway_cleaned
ADD Purchase_Hour INT

UPDATE railway_cleaned
SET Purchase_Hour = DATEPART(HOUR, Time_of_Purchase)

-- 6.Departure Day
ALTER TABLE railway_cleaned
ADD Departure_Day VARCHAR(50)

UPDATE railway_cleaned
SET Departure_Day = DATENAME(WEEKDAY, Date_of_Journey)

-- 7.Departure Hour
ALTER TABLE railway_cleaned
ADD Departure_Hour INT

UPDATE railway_cleaned
SET Departure_Hour = DATEPART(HOUR, Departure_Time)

SELECT * FROM Railway_Cleaned

-- * Normalization * --

-- 1.Date Dimension
CREATE TABLE Dates (
    Full_Date DATE,
	Year INT,
	Quarter INT,
	Month_Num INT,
	Month_Name VARCHAR(20),
    Day_Name VARCHAR(20),
    Day_Type VARCHAR(10),
	CONSTRAINT Dates_PK PRIMARY KEY (Full_Date)
)

WITH DateSeries AS (
    SELECT CAST('2023-12-08' AS DATE) AS Full_Date
    UNION ALL
    SELECT DATEADD(DAY, 1, Full_Date)
    FROM DateSeries
    WHERE Full_Date < '2024-04-30'
)

INSERT INTO Dates
SELECT
    Full_Date,
    YEAR(Full_Date),
    DATEPART(QUARTER, Full_Date),
    MONTH(Full_Date),
    DATENAME(MONTH, Full_Date),
    DATENAME(WEEKDAY, Full_Date),
    CASE 
        WHEN DATENAME(WEEKDAY, Full_Date) IN ('Saturday','Sunday') 
        THEN 'Weekend'
        ELSE 'Weekday'
    END
FROM DateSeries
OPTION (MAXRECURSION 1000)

SELECT * FROM Dates

-- 2.Time Dimension
CREATE TABLE Times (
    Hour_24 INT,
    Hour_12 INT,
    AM_PM VARCHAR(2),
    Time_Bucket VARCHAR(20),
    Is_OffPeak BIT,
    CONSTRAINT Times_PK PRIMARY KEY (Hour_24)
)

WITH Hours AS (
    SELECT 0 AS Hour_24
    UNION ALL
    SELECT Hour_24 + 1
    FROM Hours
    WHERE Hour_24 < 23
)

INSERT INTO Times
SELECT
    Hour_24,
    CASE 
        WHEN Hour_24 = 0 THEN 12
        WHEN Hour_24 > 12 THEN Hour_24 - 12
        ELSE Hour_24
    END AS Hour_12,
    CASE 
        WHEN Hour_24 < 12 THEN 'AM'
        ELSE 'PM'
    END AS AM_PM,
    CASE 
        WHEN Hour_24 BETWEEN 5 AND 11 THEN 'Morning'
        WHEN Hour_24 BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN Hour_24 BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Night'
    END AS Time_Bucket,

    -- Peak hours
    CASE 
        WHEN (Hour_24 BETWEEN 6 AND 8 OR Hour_24 BETWEEN 16 AND 18) THEN 1
        ELSE 0
    END AS Is_OffPeak
FROM Hours
OPTION (MAXRECURSION 100)

SELECT * FROM Times

-- 3.Purchases
CREATE TABLE Purchases (
    Purchase_ID INT IDENTITY(1, 1),
    Purchase_Type VARCHAR(20) UNIQUE,
	CONSTRAINT Purchase_PK PRIMARY KEY (Purchase_ID)
)

INSERT INTO Purchases
SELECT DISTINCT Purchase_Type
FROM railway_cleaned
ORDER BY Purchase_Type

SELECT * FROM Purchases

-- 4.Payments
CREATE TABLE Payments (
    Payment_ID INT IDENTITY(1, 1),
    Payment_Method VARCHAR(20) UNIQUE,
	CONSTRAINT Payments_PK PRIMARY KEY (Payment_ID)
)

INSERT INTO Payments
SELECT DISTINCT Payment_Method
FROM railway_cleaned
ORDER BY Payment_Method

SELECT * FROM Payments

-- 5.Railcard
CREATE TABLE Railcards (
    Railcard_ID INT IDENTITY(1, 1),
    Railcard_Type VARCHAR(20) UNIQUE,
    CONSTRAINT Railcard_PK PRIMARY KEY (Railcard_ID)
)

INSERT INTO Railcards
SELECT DISTINCT Railcard
FROM railway_cleaned
ORDER BY Railcard

SELECT * FROM Railcards

-- 6.Ticket Class
CREATE TABLE Ticket_Class (
    Ticket_Class_ID INT IDENTITY(1,1),
    Ticket_Class VARCHAR(20) UNIQUE,
    CONSTRAINT Class_PK PRIMARY KEY (Ticket_Class_ID)
)

INSERT INTO Ticket_Class
SELECT DISTINCT Ticket_Class
FROM Railway_Cleaned
ORDER BY Ticket_Class

SELECT * FROM Ticket_Class

-- 7.Ticket Type
CREATE TABLE Ticket_Type (
    Ticket_Type_ID INT IDENTITY(1,1),
    Ticket_Type VARCHAR(20) UNIQUE,
    CONSTRAINT Type_PK PRIMARY KEY (Ticket_Type_ID)
)

INSERT INTO Ticket_Type
SELECT DISTINCT Ticket_Type
FROM Railway_Cleaned
ORDER BY Ticket_Type

SELECT * FROM Ticket_Type

-- 8.Routes
CREATE TABLE Routes (
	Route_ID INT IDENTITY(1, 1),
	Departure_Station VARCHAR(50),
	Arrival_Station VARCHAR(50),
	Route_Name VARCHAR(100),
	CONSTRAINT Routes_PK PRIMARY KEY (Route_ID)
)

INSERT INTO Routes
SELECT DISTINCT
	Departure_Station,
	Arrival_Station,
	Departure_Station + '_' + Arrival_Station AS Route_Name
FROM railway_cleaned
ORDER BY Departure_Station, Arrival_Station, Route_Name

SELECT * FROM Routes

SELECT Route_Name, COUNT(*) #Duplicates
FROM Routes
GROUP BY Route_Name
HAVING COUNT(*) > 1 --> 0 Duplicates

-- 9. Journey Status
CREATE TABLE Status (
    Status_ID INT IDENTITY(1, 1),
    Journey_Status VARCHAR(20) UNIQUE,
	CONSTRAINT Status_PK PRIMARY KEY (Status_ID)
)

INSERT INTO Status
SELECT DISTINCT Journey_Status
FROM railway_cleaned
ORDER BY Journey_Status

SELECT * FROM Status

-- 10.Delay Reasons
CREATE TABLE Delay_Reasons (
    Delay_ID INT IDENTITY(1, 1),
    Reason_for_Delay VARCHAR(50) UNIQUE,
	CONSTRAINT Delay_Reasons_PK PRIMARY KEY (Delay_ID)
)

INSERT INTO Delay_Reasons
SELECT DISTINCT Reason_for_Delay
FROM railway_cleaned
ORDER BY Reason_for_Delay

SELECT * FROM Delay_Reasons

-- 11.Refund Request
CREATE TABLE Refunds (
    Refund_ID INT IDENTITY(1, 1),
    Refund_Request VARCHAR(20) UNIQUE,
    CONSTRAINT Refunds_PK PRIMARY KEY(Refund_ID)
)

INSERT INTO Refunds
SELECT DISTINCT Refund_Request
FROM railway_cleaned
ORDER BY Refund_Request

SELECT * FROM Refunds

-- 12.Fact Transactions
CREATE TABLE Fact_Transactions (
    Transaction_ID VARCHAR(100),
    Journey_Date DATE,
    Purchase_Date DATE,
    Time_ID INT,
    Purchase_ID INT,
    Payment_ID INT,
    Railcard_ID INT,
    Ticket_Class_ID INT,
    Ticket_Type_ID INT,
    Route_ID INT,
    Status_ID INT,
    Delay_ID INT,
    Refund_ID INT,
    Price MONEY,
    Refunded_Amount MONEY,
    Profit AS (Price - Refunded_Amount),
    Delay_Minutes INT,
    Journey_Duration_Minutes INT,

    CONSTRAINT PK_Transactions PRIMARY KEY NONCLUSTERED (Transaction_ID),
    CONSTRAINT FK_JourneyDate FOREIGN KEY (Journey_Date) REFERENCES Dates(Full_Date),
    CONSTRAINT FK_PurchaseDate FOREIGN KEY (Purchase_Date) REFERENCES Dates(Full_Date),
    CONSTRAINT FK_Time FOREIGN KEY (Time_ID) REFERENCES Times(Hour_24),
    CONSTRAINT FK_Purchase FOREIGN KEY (Purchase_ID) REFERENCES Purchases(Purchase_ID),
    CONSTRAINT FK_Payment FOREIGN KEY (Payment_ID) REFERENCES Payments(Payment_ID),
    CONSTRAINT FK_Railcard FOREIGN KEY (Railcard_ID) REFERENCES Railcards(Railcard_ID),
    CONSTRAINT FK_Class FOREIGN KEY (Ticket_Class_ID) REFERENCES Ticket_Class(Ticket_Class_ID),
    CONSTRAINT FK_Type FOREIGN KEY (Ticket_Type_ID) REFERENCES Ticket_Type(Ticket_Type_ID),
    CONSTRAINT FK_Route FOREIGN KEY (Route_ID) REFERENCES Routes(Route_ID),
    CONSTRAINT FK_Status FOREIGN KEY (Status_ID) REFERENCES Status(Status_ID),
    CONSTRAINT FK_Delay FOREIGN KEY (Delay_ID) REFERENCES Delay_Reasons(Delay_ID),
    CONSTRAINT FK_Refund FOREIGN KEY (Refund_ID) REFERENCES Refunds(Refund_ID)
)

INSERT INTO Fact_Transactions (
    Transaction_ID,
    Journey_Date,
    Purchase_Date,
    Time_ID,
    Purchase_ID,
    Payment_ID,
    Railcard_ID,
    Ticket_Class_ID,
    Ticket_Type_ID,
    Route_ID,
    Status_ID,
    Delay_ID,
    Refund_ID,
    Price,
    Refunded_Amount,
    Delay_Minutes,
    Journey_Duration_Minutes
)
SELECT 
    R.Transaction_ID,
    R.Date_of_Journey,
    R.Date_of_Purchase,
    DATEPART(HOUR, R.Departure_Time),
    P.Purchase_ID,
    PM.Payment_ID,
    RC.Railcard_ID,
    TC.Ticket_Class_ID,
    TT.Ticket_Type_ID,
    RT.Route_ID,
    S.Status_ID,
    DR.Delay_ID,
    RF.Refund_ID,
    R.Price,
    R.Refunded_Amount,
    R.Delay_Minutes,
    R.Journey_Duration_Minutes
FROM Railway_Cleaned R
LEFT JOIN Purchases P 
    ON R.Purchase_Type = P.Purchase_Type
LEFT JOIN Payments PM 
    ON R.Payment_Method = PM.Payment_Method
LEFT JOIN Railcards RC 
    ON R.Railcard = RC.Railcard_Type
LEFT JOIN Ticket_Class TC 
    ON R.Ticket_Class = TC.Ticket_Class
LEFT JOIN Ticket_Type TT 
    ON R.Ticket_Type = TT.Ticket_Type
LEFT JOIN Routes RT 
    ON R.Departure_Station = RT.Departure_Station 
   AND R.Arrival_Station = RT.Arrival_Station
LEFT JOIN Status S 
    ON R.Journey_Status = S.Journey_Status
LEFT JOIN Delay_Reasons DR 
    ON R.Reason_for_Delay = DR.Reason_for_Delay
LEFT JOIN Refunds RF 
    ON R.Refund_Request = RF.Refund_Request

CREATE CLUSTERED INDEX IX_Fact_JourneyDate
ON Fact_Transactions (Journey_Date, Purchase_Date, Time_ID, Route_ID)

SELECT * FROM Fact_Transactions

------------------
-- * Analysis * --
------------------

-- A. General Overview

-- 1. What is the total number of journeys recorded?
SELECT COUNT(*) AS Total_Trips
FROM Fact_Transactions

-- 2. How many journeys occur yearly, monthly, daily?
-- yearly
SELECT
    D.Year,
    COUNT(Transaction_ID) AS Trips
FROM Fact_Transactions F RIGHT JOIN Dates D
ON D.Full_Date = F.Journey_Date
GROUP BY D.Year
-- monthly
SELECT
    D.Month_Num,
    D.Month_Name,
    COUNT(Transaction_ID) AS Trips
FROM Fact_Transactions F RIGHT JOIN Dates D
ON D.Full_Date = F.Journey_Date
GROUP BY D.Year, D.Month_Num, D.Month_Name
ORDER BY D.Year
-- daily
SELECT
    D.Full_Date,
    COUNT(Transaction_ID) AS Trips
FROM Fact_Transactions F RIGHT JOIN Dates D
ON D.Full_Date = F.Journey_Date
GROUP BY D.Full_Date

-- 3. What is the distribution of journey statuses (On Time, Delayed, Cancelled)?
SELECT
    S.Journey_Status,
    COUNT(Transaction_ID) AS Trips,
    CAST(
    (COUNT(Transaction_ID) * 100.0) / SUM(COUNT(*)) OVER()
    AS DECIMAL(5,2)) AS Percentage
FROM Fact_Transactions F JOIN Status S
ON S.Status_ID = F.Status_ID
GROUP BY S.Journey_Status
ORDER BY Trips DESC

-- 4. What is the average journey duration?
SELECT AVG(Journey_Duration_Minutes) AS Avg_Duration
FROM Fact_Transactions

-- 5. What is the average delay time per journey?
SELECT AVG(Delay_Minutes) AS Avg_Delay
FROM Fact_Transactions

----------------------------------------------------
----------------------------------------------------
-- B. Sales & Revenue Analysis

-- 6. What is the total revenue?
SELECT SUM(Price) AS Total_Revenue
FROM Fact_Transactions

-- 7. What is the total refunded amount and its impact on revenue?
SELECT
    SUM(Refunded_Amount) AS Total_Refunds,
    CAST(
    (SUM(Refunded_Amount) * 100.0) / SUM(Price)
    AS DECIMAL(5,2)) AS Refunds_Percentage
FROM Fact_Transactions

-- 8. What is the net profit after refunds?
SELECT SUM(Profit) AS Net_Profit
FROM Fact_Transactions

-- 9. Which ticket type generates the highest revenue?
SELECT
    TT.Ticket_Type,
    SUM(Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue,
    SUM(Refunded_Amount) AS Refunds
FROM Fact_Transactions F JOIN Ticket_Type TT
ON TT.Ticket_Type_ID = F.Ticket_Type_ID
GROUP BY TT.Ticket_Type
ORDER BY Gross_Revenue DESC

-- 10. Which ticket class contributes the most to revenue?
SELECT
    TC.Ticket_Class,
    SUM(Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue,
    SUM(Refunded_Amount) AS Refunds
FROM Fact_Transactions F JOIN Ticket_Class TC
ON TC.Ticket_Class_ID = F.Ticket_Class_ID
GROUP BY TC.Ticket_Class
ORDER BY Gross_Revenue DESC

-- 11. How does revenue vary by month?
SELECT
    D.Month_Num,
    D.Month_Name,
    SUM(Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue,
    SUM(Refunded_Amount) AS Refunds
FROM Fact_Transactions F JOIN Dates D
ON D.Full_Date = F.Purchase_Date
GROUP BY D.Year, D.Month_Num, D.Month_Name
ORDER BY D.Year ASC

-- 12. Which routes generate the highest revenue?
SELECT
    R.Route_Name,
    SUM(Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue,
    SUM(Refunded_Amount) AS Refunds
FROM Fact_Transactions F JOIN Routes R
ON R.Route_ID = F.Route_ID
GROUP BY R.Route_Name
ORDER BY Gross_Revenue DESC

-- 13. What is the average ticket price per route?
SELECT
    R.Route_Name,
    ROUND(AVG(Price), 2) AS Avg_Price
FROM Fact_Transactions F JOIN Routes R
ON R.Route_ID = F.Route_ID
GROUP BY R.Route_Name
ORDER BY Avg_Price DESC

-- 14. How does railcard usage affect ticket pricing and revenue?
SELECT
    CASE
        WHEN R.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END AS Railcard_Type,
    COUNT(Transaction_ID) AS Tickets,
    ROUND(AVG(Price), 2) AS Avg_Price,
    SUM(Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue,
    SUM(Refunded_Amount) AS Refunds
FROM Fact_Transactions F JOIN Railcards R
ON R.Railcard_ID = F.Railcard_ID
GROUP BY
    CASE
        WHEN R.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END
ORDER BY Gross_Revenue DESC

-- 15. Which payment method is most frequently used?
SELECT
    P.Payment_Method,
    COUNT(Transaction_ID) AS Tickets,
    CAST(
    (COUNT(Transaction_ID) * 100.0) / SUM(COUNT(*)) OVER()
    AS DECIMAL(5,2)) AS Percentage
FROM Fact_Transactions F JOIN Payments P
ON P.Payment_ID = F.Payment_ID
GROUP BY P.Payment_Method
ORDER BY Tickets DESC

-- 16. Which payment method generates the highest revenue?
SELECT
    P.Payment_Method,
    ROUND(AVG(Price), 2) AS Avg_Price,
    SUM(Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue,
    SUM(Refunded_Amount) AS Refunds
FROM Fact_Transactions F JOIN Payments P
ON P.Payment_ID = F.Payment_ID
GROUP BY P.Payment_Method
ORDER BY Gross_Revenue DESC

-- 17. How does purchase type (online vs station) affect revenue?
SELECT
    P.Purchase_Type,
    ROUND(AVG(Price), 2) AS Avg_Price,
    SUM(Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue,
    SUM(Refunded_Amount) AS Refunds
FROM Fact_Transactions F JOIN Purchases P
ON P.Purchase_ID = F.Purchase_ID
GROUP BY P.Purchase_Type
ORDER BY Gross_Revenue DESC

----------------------------------------------------
----------------------------------------------------
-- C. Customer & Purchase Behavior

-- 18. When do customers most frequently purchase tickets (hour/day/month)?
-- hour
SELECT TOP 5
    T.Hour_24,
    COUNT(Transaction_ID) AS Tickets_Purchased
FROM Fact_Transactions F JOIN Times T
ON T.Hour_24 = F.Time_ID
GROUP BY T.Hour_24
ORDER BY Tickets_Purchased DESC
-- day
SELECT
    D.Day_Name,
    COUNT(Transaction_ID) AS Tickets_Purchased
FROM Fact_Transactions F JOIN Dates D
ON D.Full_Date = F.Purchase_Date
GROUP BY D.Day_Name
ORDER BY Tickets_Purchased DESC
-- month
SELECT
    D.Month_Name,
    COUNT(Transaction_ID) AS Tickets_Purchased
FROM Fact_Transactions F JOIN Dates D
ON D.Full_Date = F.Purchase_Date
GROUP BY D.Month_Name
ORDER BY Tickets_Purchased DESC

-- 19. What is the demand trend for different ticket types (Advance, Off-Peak, Anytime)?
SELECT
    D.Year,
    D.Month_Num,
    D.Month_Name,
    TT.Ticket_Type,
    COUNT(F.Transaction_ID) AS Tickets
FROM Fact_Transactions F JOIN Dates D
ON F.Purchase_Date = D.Full_Date
JOIN Ticket_Type TT
ON F.Ticket_Type_ID = TT.Ticket_Type_ID
GROUP BY 
    D.Year,
    D.Month_Num,
    D.Month_Name,
    TT.Ticket_Type
ORDER BY 
    D.Year,
    D.Month_Num,
    TT.Ticket_Type

-- 20. Are customers with railcards more likely to purchase certain ticket types?
SELECT
    CASE
        WHEN R.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END AS Railcard_Type,
    TT.Ticket_Type,
    COUNT(Transaction_ID) AS Tickets
FROM Fact_Transactions F JOIN Railcards R
ON R.Railcard_ID = F.Railcard_ID
JOIN Ticket_Type TT
ON TT.Ticket_Type_ID = F.Ticket_Type_ID
WHERE R.Railcard_Type <> 'None'
GROUP BY
    CASE
        WHEN R.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END, TT.Ticket_Type
ORDER BY Tickets DESC

-- 21. What percentage of customers request refunds?
SELECT
    R.Refund_Request,
    COUNT(*) AS Requests,
    CAST(
    (COUNT(*) * 100.0) / (SELECT COUNT(*) FROM Fact_Transactions)
    AS DECIMAL(5,2)) AS Percentage
FROM Fact_Transactions F JOIN Refunds R
ON R.Refund_ID = F.Refund_ID
WHERE R.Refund_Request = 'Yes'
GROUP BY R.Refund_Request

-- 22. Are refund requests more common with specific ticket types or classes?
-- type
SELECT
    TT.Ticket_Type,
    COUNT(*) AS Yes_Requests,
    CAST(
    (COUNT(*) * 100.0) / (SELECT COUNT(*) FROM Fact_Transactions)
    AS DECIMAL(5,2)) AS Percentage
FROM Fact_Transactions F JOIN Refunds R
ON R.Refund_ID = F.Refund_ID
JOIN Ticket_Type TT
ON TT.Ticket_Type_ID = F.Ticket_Type_ID
WHERE R.Refund_Request = 'Yes'
GROUP BY R.Refund_Request, TT.Ticket_Type
ORDER BY Yes_Requests DESC
-- class
SELECT
    TC.Ticket_Class,
    COUNT(*) AS Yes_Requests,
    CAST(
    (COUNT(*) * 100.0) / (SELECT COUNT(*) FROM Fact_Transactions)
    AS DECIMAL(5,2)) AS Percentage
FROM Fact_Transactions F JOIN Refunds R
ON R.Refund_ID = F.Refund_ID
JOIN Ticket_Class TC
ON TC.Ticket_Class_ID = F.Ticket_Class_ID
WHERE R.Refund_Request = 'Yes'
GROUP BY R.Refund_Request, TC.Ticket_Class
ORDER BY Yes_Requests DESC

----------------------------------------------------
----------------------------------------------------
-- D. Journey Performance

-- 23. Which routes have the highest delay rates?
SELECT
    R.Route_Name,
    SUM(Delay_Minutes) AS Delay_Minutes,
    CAST(
    (SUM(Delay_Minutes) * 100.0) / SUM(SUM(Delay_Minutes)) OVER()
    AS DECIMAL(5,2)) AS Delay_Rate
FROM Fact_Transactions F JOIN Routes R
ON R.Route_ID = F.Route_ID
GROUP BY R.Route_Name
ORDER BY Delay_Rate DESC

-- 24. Which routes have the longest journey durations?
SELECT
    R.Route_Name,
    AVG(Journey_Duration_Minutes) AS Avg_Duration
FROM Fact_Transactions F JOIN Routes R
ON R.Route_ID = F.Route_ID
GROUP BY R.Route_Name
ORDER BY Avg_Duration DESC

-- 25. At what times of the day do delays occur most frequently?
-- hours
SELECT
    T.Hour_24,
    COUNT(*) AS Total_Trips,
    SUM(CASE 
            WHEN F.Delay_Minutes > 0 THEN 1 
            ELSE 0 
        END) AS Delayed_Trips,
    CAST(
        (SUM(CASE WHEN F.Delay_Minutes > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS Delay_Rate
FROM Fact_Transactions F JOIN Times T
ON F.Time_ID = T.Hour_24
GROUP BY T.Hour_24
ORDER BY Delay_Rate DESC
-- buckets
SELECT
    T.Time_Bucket,
    COUNT(*) AS Total_Trips,
    SUM(CASE 
            WHEN F.Delay_Minutes > 0 THEN 1 
            ELSE 0 
        END) AS Delayed_Trips,
    CAST(
        (SUM(CASE WHEN F.Delay_Minutes > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS Delay_Rate
FROM Fact_Transactions F JOIN Times T
ON F.Time_ID = T.Hour_24
GROUP BY T.Time_Bucket
ORDER BY Delayed_Trips DESC

-- 26. Are peak-hour journeys more prone to delays?
SELECT
    CASE 
        WHEN T.Is_OffPeak = 1 THEN 'Off-Peak'
        ELSE 'Peak'
    END AS Is_OffPeak,
    COUNT(*) AS Total_Trips,
    SUM(CASE 
            WHEN F.Delay_Minutes > 0 THEN 1 
            ELSE 0 
        END) AS Delayed_Trips,
    CAST(
        (SUM(CASE WHEN F.Delay_Minutes > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS Delay_Rate
FROM Fact_Transactions F JOIN Times T
ON T.Hour_24 = F.Time_ID
GROUP BY Is_OffPeak
ORDER BY Delay_Rate DESC

-- 27. Which days of the week have the highest delay rates?
SELECT
    D.Day_Name,
    COUNT(*) AS Total_Trips,
    SUM(CASE 
            WHEN F.Delay_Minutes > 0 THEN 1 
            ELSE 0 
        END) AS Delayed_Trips,
    CAST(
        (SUM(CASE WHEN F.Delay_Minutes > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS Delay_Rate
FROM Fact_Transactions F JOIN Dates D
ON D.Full_Date = F.Journey_Date
GROUP BY D.Day_Name
ORDER BY Delay_Rate DESC

-- 28. What is the longest & shortest journey duration recorded?
SELECT
    MAX(Journey_Duration_Minutes) AS The_Longest_Trip,
    MIN(Journey_Duration_Minutes) AS The_Shortest_Trip
FROM Fact_Transactions

-- 29. How does journey duration affect the likelihood of delay?
SELECT
    CASE 
        WHEN Journey_Duration_Minutes BETWEEN 0 AND 60 THEN '0–1 Hour'
        WHEN Journey_Duration_Minutes BETWEEN 61 AND 120 THEN '1–2 Hours'
        WHEN Journey_Duration_Minutes BETWEEN 121 AND 180 THEN '2–3 Hours'
        ELSE '3+ Hours'
    END AS Duration_Category,
    COUNT(*) AS Total_Trips,
    SUM(CASE 
            WHEN Delay_Minutes > 0 THEN 1 
            ELSE 0 
        END) AS Delayed_Trips,
    ROUND(AVG(CAST(Delay_Minutes AS FLOAT)), 2) AS Avg_Delay,
    CAST(
        (SUM(CASE WHEN Delay_Minutes > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS Delay_Probability
FROM Fact_Transactions
WHERE Journey_Duration_Minutes IS NOT NULL
GROUP BY 
    CASE 
        WHEN Journey_Duration_Minutes BETWEEN 0 AND 60 THEN '0–1 Hour'
        WHEN Journey_Duration_Minutes BETWEEN 61 AND 120 THEN '1–2 Hours'
        WHEN Journey_Duration_Minutes BETWEEN 121 AND 180 THEN '2–3 Hours'
        ELSE '3+ Hours'
    END
ORDER BY Delay_Probability DESC

-- 30. What is the on-time performance rate per route?
SELECT
    R.Route_Name,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN S.Journey_Status = 'On Time' THEN 1 ELSE 0 END) AS OnTime_Trips,
    CAST(
    (SUM(CASE WHEN S.Journey_Status = 'On Time' THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
    AS DECIMAL(5,2)) AS OnTime_Rate
FROM Fact_Transactions F JOIN Routes R
ON R.Route_ID = F.Route_ID
JOIN Status S
ON S.Status_ID = F.Status_ID
GROUP BY R.Route_Name
ORDER BY OnTime_Rate DESC

----------------------------------------------------
----------------------------------------------------
-- E. Delay Analysis

-- 31. What is the percentage of delayed trips?
SELECT
    CASE
        WHEN D.Reason_for_Delay = 'No Delay' THEN 'No Delay'
        ELSE 'Delayed'
    END AS Is_Delayed,
    COUNT(*) AS Trips,
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage
FROM Fact_Transactions F JOIN Delay_Reasons D
ON D.Delay_ID = F.Delay_ID
GROUP BY
    CASE
        WHEN D.Reason_for_Delay = 'No Delay' THEN 'No Delay'
        ELSE 'Delayed'
    END
ORDER BY Trips DESC

-- 32. What is the most common reason for delays?
SELECT
    D.Reason_for_Delay,
    COUNT(*) AS Trips,
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage
FROM Fact_Transactions F JOIN Delay_Reasons D
ON D.Delay_ID = F.Delay_ID
WHERE D.Reason_for_Delay <> 'No Delay'
GROUP BY D.Reason_for_Delay
ORDER BY Trips DESC

-- 33. Which delay reason contributes the highest total delay time?
SELECT
    D.Reason_for_Delay,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    CAST((SUM(Delay_Minutes) * 100.0) / SUM(SUM(Delay_Minutes)) OVER()
    AS DECIMAL(5,2)) AS Percentage
FROM Fact_Transactions F JOIN Delay_Reasons D
ON D.Delay_ID = F.Delay_ID
WHERE D.Reason_for_Delay <> 'No Delay'
GROUP BY D.Reason_for_Delay
ORDER BY Percentage DESC

-- 34. What is the average delay duration per delay reason?
SELECT
    D.Reason_for_Delay,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    AVG(Delay_Minutes) AS Avg_Delay
FROM Fact_Transactions F JOIN Delay_Reasons D
ON D.Delay_ID = F.Delay_ID
WHERE D.Reason_for_Delay <> 'No Delay'
GROUP BY D.Reason_for_Delay
ORDER BY Avg_Delay DESC

-- 35. Are certain routes associated with specific delay reasons?
WITH DelayCounts AS (
    SELECT
        R.Route_Name,
        D.Reason_for_Delay,
        COUNT(*) AS Delayed_Trips,
        ROW_NUMBER() OVER (
            PARTITION BY R.Route_Name
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM Fact_Transactions F
    JOIN Routes R ON R.Route_ID = F.Route_ID
    JOIN Delay_Reasons D ON D.Delay_ID = F.Delay_ID
    WHERE D.Reason_for_Delay <> 'No Delay'
    GROUP BY R.Route_Name, D.Reason_for_Delay
)

SELECT
    Route_Name,
    Reason_for_Delay,
    Delayed_Trips
FROM DelayCounts
WHERE rn = 1
ORDER BY Delayed_Trips DESC

-- 36. Do delays increase during specific hours of the day?
SELECT
    T.Hour_24,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN F.Delay_Minutes > 0 THEN 1 ELSE 0 END) AS Delayed_Trips,
    AVG(CASE WHEN F.Delay_Minutes > 0 THEN F.Delay_Minutes END) AS Avg_Delay_Minutes
FROM Fact_Transactions F
JOIN Times T ON T.Hour_24 = F.Time_ID
GROUP BY T.Hour_24
ORDER BY T.Hour_24 ASC

-- 37. What is the distribution of delays (e.g., 0–30, 30–60, 60+ minutes)?
SELECT
    CASE
        WHEN Delay_Minutes = 0 THEN 'No Delay'
        WHEN Delay_Minutes > 0 AND Delay_Minutes <= 30 THEN '0–30 min'
        WHEN Delay_Minutes > 30 AND Delay_Minutes <= 60 THEN '30–60 min'
        ELSE '60+ min'
    END AS Delay_Bucket,
    COUNT(*) AS Trips
FROM Fact_Transactions
GROUP BY
    CASE
        WHEN Delay_Minutes = 0 THEN 'No Delay'
        WHEN Delay_Minutes > 0 AND Delay_Minutes <= 30 THEN '0–30 min'
        WHEN Delay_Minutes > 30 AND Delay_Minutes <= 60 THEN '30–60 min'
        ELSE '60+ min'
    END
ORDER BY Trips DESC

-- 38. Which delay reasons lead to the highest refund costs?
SELECT
    D.Reason_for_Delay,
    SUM(Refunded_Amount) AS Total_Refund_Cost
FROM Fact_Transactions F JOIN Delay_Reasons D 
ON D.Delay_ID = F.Delay_ID
WHERE D.Reason_for_Delay <> 'No Delay'
GROUP BY D.Reason_for_Delay
ORDER BY Total_Refund_Cost DESC

----------------------------------------------------
----------------------------------------------------
-- F. Refund Analysis

-- 39. What percentage of journeys result in refunds?
SELECT
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Trips,
    CAST(
    SUM(CASE WHEN Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
    AS DECIMAL(5,2)) AS Refund_Percentage
FROM Fact_Transactions

-- 40. How much revenue is lost due to refunds?
SELECT SUM(Refunded_Amount) AS Lost_Revenue
FROM Fact_Transactions

-- 41. Which ticket types have the highest refund rates?
SELECT
    TT.Ticket_Type,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN F.Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Trips,
    CAST(
    (SUM(CASE WHEN F.Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
    AS DECIMAL(5,2)) AS Refund_Rate_Percentage
FROM Fact_Transactions F JOIN Ticket_Type TT 
ON TT.Ticket_Type_ID = F.Ticket_Type_ID
GROUP BY TT.Ticket_Type
ORDER BY Refund_Rate_Percentage DESC

-- 42. Which delay durations trigger the most refunds?
SELECT
    CASE
        WHEN Delay_Minutes = 0 THEN 'No Delay'
        WHEN Delay_Minutes BETWEEN 1 AND 30 THEN '1–30 min'
        WHEN Delay_Minutes BETWEEN 31 AND 60 THEN '31–60 min'
        WHEN Delay_Minutes BETWEEN 61 AND 120 THEN '61–120 min'
        ELSE '120+ min'
    END AS Delay_Bucket,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Trips,
    CAST(
        (SUM(CASE WHEN Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0)  / COUNT(*)
        AS DECIMAL(5,2)) AS Refund_Rate
FROM Fact_Transactions
GROUP BY
    CASE
        WHEN Delay_Minutes = 0 THEN 'No Delay'
        WHEN Delay_Minutes BETWEEN 1 AND 30 THEN '1–30 min'
        WHEN Delay_Minutes BETWEEN 31 AND 60 THEN '31–60 min'
        WHEN Delay_Minutes BETWEEN 61 AND 120 THEN '61–120 min'
        ELSE '120+ min'
    END
ORDER BY Refund_Rate DESC

-- 43. Are refunds more common for certain routes?
SELECT
    R.Route_Name,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN F.Refunded_Amount > 0 THEN 1 ELSE 0 END) AS Refunded_Trips,
    CAST(
        (SUM(CASE WHEN F.Refunded_Amount > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS Refund_Rate
FROM Fact_Transactions F JOIN Routes R
ON R.Route_ID = F.Route_ID
GROUP BY R.Route_Name
ORDER BY Refund_Rate DESC

-- 44. What is the average refunded amount per journey?
SELECT ROUND(AVG(Refunded_Amount), 2) AS Avg_Refund
FROM Fact_Transactions
WHERE Refunded_Amount > 0

-- 45. How do cancellations vs delays impact refund amounts?
SELECT
    S.Journey_Status,
    COUNT(*) AS Total_Trips,
    SUM(F.Refunded_Amount) AS Total_Refunded_Amount,
    ROUND(AVG(F.Refunded_Amount), 2) AS Avg_Refunded_Per_Journey,
    CAST(
        SUM(F.Refunded_Amount) * 100.0 / SUM(SUM(F.Refunded_Amount)) OVER()
        AS DECIMAL(5,2)) AS Refund_Contribution_Percentage
FROM Fact_Transactions F JOIN Status S
ON S.Status_ID = F.Status_ID
WHERE S.Journey_Status <> 'On Time'
GROUP BY S.Journey_Status

----------------------------------------------------
----------------------------------------------------
-- G. Operational Efficiency

-- 46. Which routes are the most efficient (lowest delay + highest profit)?
WITH RouteMetrics AS (
    SELECT
        R.Route_Name,
        COUNT(*) AS Total_Trips,
        AVG(F.Delay_Minutes) AS Avg_Delay,
        SUM(F.Profit) AS Total_Profit
    FROM Fact_Transactions F JOIN Routes R
    ON R.Route_ID = F.Route_ID
    GROUP BY R.Route_Name
),

Normalized AS (
    SELECT
        Route_Name,
        Total_Trips,
        Avg_Delay,
        Total_Profit,
        (MAX(Avg_Delay) OVER() - Avg_Delay) AS Delay_Score,
        Total_Profit AS Profit_Score
    FROM RouteMetrics
)

SELECT
    Route_Name,
    Total_Trips,
    Avg_Delay,
    Total_Profit,
    (0.6 * Profit_Score + 0.4 * Delay_Score) AS Efficiency_Score
FROM Normalized
ORDER BY Efficiency_Score DESC

-- 47. Which time periods have the best on-time performance?
-- Time Buckets
SELECT
    T.Time_Bucket,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN S.Journey_Status = 'On Time' THEN 1 ELSE 0 END) AS OnTime_Trips,
    CAST(
        (SUM(CASE WHEN S.Journey_Status = 'On Time' THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS OnTime_Rate
FROM Fact_Transactions F JOIN Times T
ON T.Hour_24 = F.Time_ID
JOIN Status S
ON S.Status_ID = F.Status_ID
GROUP BY T.Time_Bucket
ORDER BY OnTime_Rate DESC

-- Hours
SELECT
    T.Hour_24,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN S.Journey_Status = 'On Time' THEN 1 ELSE 0 END) AS OnTime_Trips,
    CAST(
        (SUM(CASE WHEN S.Journey_Status = 'On Time' THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS OnTime_Rate
FROM Fact_Transactions F JOIN Times T
ON T.Hour_24 = F.Time_ID
JOIN Status S
ON S.Status_ID = F.Status_ID
GROUP BY T.Hour_24
ORDER BY OnTime_Rate DESC

-- 48. How does peak vs off-peak performance compare?
SELECT
    CASE 
        WHEN T.Is_OffPeak = 1 THEN 'Off-Peak'
        ELSE 'Peak'
    END AS Period_Type,
    COUNT(*) AS Total_Trips,
    SUM(CASE WHEN S.Journey_Status = 'On Time' THEN 1 ELSE 0 END) AS OnTime_Trips,
    SUM(CASE WHEN F.Delay_Minutes > 0 THEN 1 ELSE 0 END) AS Delayed_Trips,
    CAST(
        (SUM(CASE WHEN S.Journey_Status = 'On Time' THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS OnTime_Rate,

    CAST(
        (SUM(CASE WHEN F.Delay_Minutes > 0 THEN 1 ELSE 0 END) * 100.0) / COUNT(*)
        AS DECIMAL(5,2)) AS Delay_Rate,
    AVG(F.Delay_Minutes) AS Avg_Delay
FROM Fact_Transactions F JOIN Times T
ON T.Hour_24 = F.Time_ID
JOIN Status S
ON S.Status_ID = F.Status_ID
GROUP BY T.Is_OffPeak

-- 49. What operational factors most impact delays and revenue loss?
SELECT
    D.Reason_for_Delay,
    COUNT(*) AS Total_Trips,
    SUM(F.Delay_Minutes) AS Total_Delay,
    AVG(F.Delay_Minutes) AS Avg_Delay,
    SUM(F.Refunded_Amount) AS Total_Revenue_Loss,
    CAST(
        (SUM(F.Refunded_Amount) * 100.0) / SUM(SUM(F.Refunded_Amount)) OVER()
        AS DECIMAL(5,2)) AS Loss_Contribution_Percentage
FROM Fact_Transactions F JOIN Delay_Reasons D
ON D.Delay_ID = F.Delay_ID
WHERE D.Reason_for_Delay <> 'No Delay'
GROUP BY D.Reason_for_Delay
ORDER BY Total_Revenue_Loss DESC

-- 50. Which combinations of route + time + ticket type maximize profit?
SELECT TOP 1
    R.Route_Name,
    T.Hour_24,
    TT.Ticket_Type,
    COUNT(*) AS Total_Trips,
    SUM(F.Profit) AS Total_Profit,
    ROUND(AVG(F.Profit), 2) AS Avg_Profit_Per_Trip
FROM Fact_Transactions F JOIN Routes R
ON R.Route_ID = F.Route_ID
JOIN Times T
ON T.Hour_24 = F.Time_ID
JOIN Ticket_Type TT
ON TT.Ticket_Type_ID = F.Ticket_Type_ID
GROUP BY R.Route_Name, T.Hour_24, TT.Ticket_Type
ORDER BY Total_Profit DESC