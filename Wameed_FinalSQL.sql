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