-- Create Database
CREATE DATABASE UK_Train_Rides

-- Use Database
USE UK_Train_Rides

-- Create The Main Table
CREATE TABLE railway (
	Transaction_ID VARCHAR(50),
	Date_of_Purchase DATE,
	Time_of_Purchase TIME(0),
	Purchase_Type VARCHAR(20),
	Payment_Method VARCHAR(20),
	Railcard VARCHAR(20),
	Ticket_Class VARCHAR(20),
	Ticket_Type VARCHAR(20),
	Price MONEY,
	Departure_Station VARCHAR(50),
	Arrival_Destination VARCHAR(50),
	Date_of_Journey DATE,
	Departure_Time TIME(0),
	Arrival_Time TIME(0),
	Actual_Arrival_Time TIME(0),
	Journey_Status VARCHAR(20),
	Reason_for_Delay VARCHAR(20),
	Refund_Request VARCHAR(20)
)

-- Insert Data Into The Main Table
BULK INSERT railway
FROM 'C:\Users\01004\OneDrive\Desktop\DEPI_Final_PJ\Data\railway.csv'
WITH (
	FIRSTROW = 2,
	ROWTERMINATOR = '\n',
	FIELDTERMINATOR = ','
)

-- Show The Main Table
SELECT *
FROM railway

-- Take A Copy From The Main Table
SELECT *
INTO railway_cleaned
FROM railway
ORDER BY Date_of_Purchase ASC

-- Show The Copied Table
SELECT *
FROM railway_cleaned

-- Search For Duplicates
SELECT Transaction_ID, COUNT(*) AS CountDuplicates
FROM railway_cleaned
GROUP BY Transaction_ID
HAVING COUNT(*) > 1

-- Search For Missing & Incorrect Values
SELECT DISTINCT Reason_for_Delay
FROM railway_cleaned

SELECT DISTINCT Railcard
FROM railway_cleaned

UPDATE railway_cleaned
SET Reason_for_Delay = 'No Delay'
WHERE Reason_for_Delay IS NULL
AND Journey_Status = 'On Time'

UPDATE railway_cleaned
SET Reason_for_Delay = 'Staffing'
WHERE Reason_for_Delay = 'Staff Shortage'

UPDATE railway_cleaned
SET Reason_for_Delay = 'Signal Failure'
WHERE Reason_for_Delay = 'Signal failure'

UPDATE railway_cleaned
SET Reason_for_Delay = 'Weather'
WHERE Reason_for_Delay = 'Weather Conditions'

UPDATE railway_cleaned
SET Refund_Request = 'No'
WHERE Refund_Request LIKE '%No%'

UPDATE railway_cleaned
SET Refund_Request = 'Yes'
WHERE Refund_Request LIKE '%Yes%'

SELECT *
FROM railway_cleaned
WHERE Journey_Status = 'On Time'
AND Refund_Request = 'Yes'

SELECT *
FROM railway_cleaned
WHERE Arrival_Time <> Actual_Arrival_Time
AND Journey_Status = 'On Time'

-- Founded 18 Rows ==> Delayed
SELECT *
FROM railway_cleaned
WHERE Arrival_Time = Actual_Arrival_Time
AND Journey_Status <> 'On Time'

-- Solving Them
UPDATE railway_cleaned
SET
	Journey_Status = 'On Time',
	Reason_for_Delay = 'No Delay',
	Refund_Request = 'No'
WHERE Arrival_Time = Actual_Arrival_Time
AND Journey_Status <> 'On Time'

-- Advance Ticket ==> Non-refundable
SELECT *
FROM railway_cleaned
WHERE Ticket_Type = 'Advance'
AND Refund_Request = 'Yes'

UPDATE railway_cleaned
SET Refund_Request = 'Non_Refundable'
WHERE Ticket_Type = 'Advance'
AND Journey_Status = 'Delayed'

-- Add New Column (Refunded_Amount)
ALTER TABLE railway_cleaned
ADD Refunded_Amount MONEY

UPDATE railway_cleaned
SET Refunded_Amount = CASE 
    WHEN Journey_Status = 'Cancelled' AND Refund_Request = 'Yes' THEN Price
    WHEN Journey_Status = 'Delayed' AND Refund_Request = 'Yes' THEN 
        CASE 
            WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) >= 60 THEN Price
            WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) >= 30 THEN Price * 0.5
            WHEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) >= 15 THEN Price * 0.25
            ELSE 0 
        END
    ELSE 0 
END

-- Violations
SELECT *
FROM railway_cleaned
WHERE Ticket_Type = 'Off-Peak'
AND (Departure_Time BETWEEN '06:00:00' AND '08:00:00'
OR Departure_Time BETWEEN '16:00:00' AND '18:00:00')

-- 1.Delay Minutes
ALTER TABLE railway_cleaned
ADD Delay_Minutes INT

UPDATE railway_cleaned
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

-- 3.Month Of Purchase
ALTER TABLE railway_cleaned
ADD Month_of_Purchase VARCHAR(50)

UPDATE railway_cleaned
SET Month_of_Purchase = DATENAME(MONTH, Date_of_Purchase)

-- 4.Purchase Hour
ALTER TABLE railway_cleaned
ADD Purchase_Hour INT

UPDATE railway_cleaned
SET Purchase_Hour = DATEPART(HOUR, Time_of_Purchase)

-- 5.Departure Day
ALTER TABLE railway_cleaned
ADD Departure_Day VARCHAR(50)

UPDATE railway_cleaned
SET Departure_Day = DATENAME(WEEKDAY, Date_of_Journey)

-- 6.Departure Hour
ALTER TABLE railway_cleaned
ADD Departure_Hour INT

UPDATE railway_cleaned
SET Departure_Hour = DATEPART(HOUR, Departure_Time)

SELECT *
FROM railway_cleaned

------- * Normalization * -------
------------------------------
CREATE TABLE Routes (
	Route_ID INT IDENTITY(1, 1),
	Departure_Station VARCHAR(50),
	Arrival_Station VARCHAR(50),
	Route_Name VARCHAR(100)
	CONSTRAINT Routes_PK PRIMARY KEY (Route_ID)
)

INSERT INTO Routes
SELECT DISTINCT
	Departure_Station,
	Arrival_Destination,
	Departure_Station + '_' + Arrival_Destination AS Route_Name
FROM railway_cleaned
ORDER BY Departure_Station, Arrival_Destination, Route_Name

SELECT *
FROM Routes
------------------------------
CREATE TABLE Tickets (
    Ticket_Type_ID INT IDENTITY(1, 1),
    Ticket_Type VARCHAR(20),
    Ticket_Class VARCHAR(20)
    CONSTRAINT Tickets_PK PRIMARY KEY (Ticket_Type_ID),
)

INSERT INTO Tickets
SELECT DISTINCT Ticket_Type, Ticket_Class
FROM railway_cleaned
ORDER BY Ticket_Type, Ticket_Class

SELECT *
FROM Tickets
------------------------------
CREATE TABLE Railcard (
    Railcard_ID INT IDENTITY(1, 1),
    Railcard_Type VARCHAR(20)
    CONSTRAINT Railcard_PK PRIMARY KEY (Railcard_ID)
)

INSERT INTO Railcard
SELECT DISTINCT Railcard
FROM railway_cleaned

SELECT *
FROM Railcard
------------------------------
CREATE TABLE Payments (
    Payment_ID INT IDENTITY(1, 1),
    Payment_Method VARCHAR(20)
	CONSTRAINT Payments_PK PRIMARY KEY (Payment_ID)
)

INSERT INTO Payments
SELECT DISTINCT Payment_Method
FROM railway_cleaned
ORDER BY Payment_Method

SELECT *
FROM Payments
------------------------------
CREATE TABLE Purchase_Type (
    Purchase_Type_ID INT IDENTITY(1, 1),
    Purchase_Type VARCHAR(20)
	CONSTRAINT Purchase_PK PRIMARY KEY (Purchase_Type_ID)
)

INSERT INTO Purchase_Type
SELECT DISTINCT Purchase_Type
FROM railway_cleaned

SELECT *
FROM Purchase_Type
------------------------------
CREATE TABLE Status (
    Status_ID INT IDENTITY(1, 1),
    Journey_Status VARCHAR(20)
	CONSTRAINT Status_PK PRIMARY KEY (Status_ID)
)

INSERT INTO Status
SELECT DISTINCT Journey_Status
FROM railway_cleaned

SELECT *
FROM Status
------------------------------
CREATE TABLE Delay_Reasons (
    Delay_ID INT IDENTITY(1, 1),
    Reason_for_Delay VARCHAR(50)
	CONSTRAINT Delay_Reasons_PK PRIMARY KEY (Delay_ID)
)

INSERT INTO Delay_Reasons
SELECT DISTINCT Reason_for_Delay
FROM railway_cleaned

SELECT *
FROM Delay_Reasons
------------------------------
CREATE TABLE Dates (
    Date_ID INT IDENTITY(1, 1),
    Full_Date DATE,
    Day_Name VARCHAR(20),
    Month_Name VARCHAR(20),
    Day_Type VARCHAR(10)
	CONSTRAINT Dates_PK PRIMARY KEY (Date_ID)
)

INSERT INTO Dates
SELECT DISTINCT
	Date_of_Purchase,
	DATENAME(WEEKDAY, Date_of_Purchase),
	DATENAME(MONTH, Date_of_Purchase),
	CASE 
        WHEN DATENAME(WEEKDAY, Date_of_Purchase) IN ('Saturday', 'Sunday') 
        THEN 'Weekend'
        ELSE 'Weekday'
    END
FROM railway_cleaned
ORDER BY Date_of_Purchase

SELECT *
FROM Dates
------------------------------
CREATE TABLE Times (
    Time_ID INT IDENTITY(1, 1),
    Hour_24 INT,
	CONSTRAINT Times_PK PRIMARY KEY (Time_ID)
)

INSERT INTO Times
SELECT DISTINCT DATEPART(HOUR, Time_of_Purchase)
FROM railway_cleaned
ORDER BY DATEPART(HOUR, Time_of_Purchase)

SELECT *
FROM Times
------------------------------
CREATE TABLE Refunds (
    Refund_ID INT IDENTITY(1, 1),
    Refund_Request VARCHAR(20)
    CONSTRAINT Refunds_PK PRIMARY KEY(Refund_ID)
)

INSERT INTO Refunds
SELECT DISTINCT Refund_Request
FROM railway_cleaned

SELECT *
FROM Refunds
------------------------------
CREATE TABLE Transaction_Details (
	Transaction_ID VARCHAR(50),
    Route_ID INT,
    Ticket_Type_ID INT,
    Railcard_ID INT,
    Payment_ID INT,
    Purchase_Type_ID INT,
    Status_ID INT,
    Delay_ID INT,
    Purchase_Date_ID INT,
	Purchase_Time_ID INT,
    Journey_Date_ID INT,
    Journey_Time_ID INT,
	Delay_Minutes INT,
    Journey_Duration_Minutes INT,
	Refund_ID INT,
	Price MONEY,
    Refunded_Amount MONEY
	CONSTRAINT Transaction_Details_PK PRIMARY KEY (Transaction_ID),
	CONSTRAINT Transaction_Details_Tickets_FK FOREIGN KEY (Ticket_Type_ID) REFERENCES Tickets(Ticket_Type_ID),
    CONSTRAINT Transaction_Details_Railcard_FK FOREIGN KEY (Railcard_ID) REFERENCES Railcard(Railcard_ID),
	CONSTRAINT Transaction_Details_Routes_FK FOREIGN KEY (Route_ID) REFERENCES Routes(Route_ID),
	CONSTRAINT Transaction_Details_Payments_FK FOREIGN KEY (Payment_ID) REFERENCES Payments(Payment_ID),
	CONSTRAINT Transaction_Details_Status_FK FOREIGN KEY (Status_ID) REFERENCES Status(Status_ID),
	CONSTRAINT Transaction_Details_Delay_FK FOREIGN KEY (Delay_ID) REFERENCES Delay_Reasons(Delay_ID),
    CONSTRAINT Transaction_Details_PurchaseDate_FK FOREIGN KEY (Purchase_Date_ID) REFERENCES Dates(Date_ID),
    CONSTRAINT Transaction_Details_JourneyDate_FK FOREIGN KEY (Journey_Date_ID) REFERENCES Dates(Date_ID),
    CONSTRAINT Transaction_Details_PurchaseTime_FK FOREIGN KEY (Purchase_Time_ID) REFERENCES Times(Time_ID),
    CONSTRAINT Transaction_Details_DepartureTime_FK FOREIGN KEY (Journey_Time_ID) REFERENCES Times(Time_ID),
    CONSTRAINT Transaction_Details_Refunds_FK FOREIGN KEY (Refund_ID) REFERENCES Refunds(Refund_ID)
)

INSERT INTO Transaction_Details
SELECT DISTINCT
    rc.Transaction_ID,
    ro.Route_ID,
    t.Ticket_Type_ID,
    ra.Railcard_ID,
    p.Payment_ID,
    pt.Purchase_Type_ID,
    s.Status_ID,
    d.Delay_ID,
    da1.Date_ID AS Purchase_Date_ID,
    ti1.Time_ID AS Purchase_Time_ID,
    da2.Date_ID AS Journey_Date_ID,
    ti2.Time_ID AS Journey_Time_ID,
    rc.Delay_Minutes,
    rc.Journey_Duration_Minutes,
    rf.Refund_ID,
    rc.Price,
    rc.Refunded_Amount
FROM railway_cleaned rc

-- Tickets
JOIN Tickets t
ON t.Ticket_Class = rc.Ticket_Class
AND t.Ticket_Type = rc.Ticket_Type

-- Railcard
JOIN Railcard ra
ON ra.Railcard_Type = rc.Railcard

-- Routes
JOIN Routes ro 
ON ro.Arrival_Station = rc.Arrival_Destination
AND ro.Departure_Station = rc.Departure_Station

-- Payments
JOIN Payments p 
ON p.Payment_Method = rc.Payment_Method

-- Purchase Type
JOIN Purchase_Type pt 
ON pt.Purchase_Type = rc.Purchase_Type

-- Status
JOIN Status s 
ON s.Journey_Status = rc.Journey_Status

-- Delay
JOIN Delay_Reasons d 
ON d.Reason_for_Delay = rc.Reason_for_Delay

-- Purchase Date
JOIN Dates da1 
ON da1.Full_Date = rc.Date_of_Purchase

-- Journey Date
JOIN Dates da2 
ON da2.Full_Date = rc.Date_of_Journey

-- Purchase Time
JOIN Times ti1 
ON ti1.Hour_24 = DATEPART(HOUR, rc.Time_of_Purchase)

-- Journey Time
JOIN Times ti2 
ON ti2.Hour_24 = DATEPART(HOUR, rc.Departure_Time)

-- Refunds
JOIN Refunds rf
ON rf.Refund_Request = rc.Refund_Request

ALTER TABLE Transaction_Details
ADD CONSTRAINT Transaction_Details_Purchase_FK FOREIGN KEY (Purchase_Type_ID) REFERENCES Purchase_Type(Purchase_Type_ID)

SELECT *
FROM Transaction_Details
------------------------------
-------- * Analysis * --------
------------ KPIs ------------
-- 1.What are the total Gross Revenue, Refunds, and Net Revenue from all transactions?
SELECT
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Price - Refunded_Amount) AS Net_Revenue
FROM Transaction_Details

-- 2.What are the average, maximum, and minimum prices of all transactions?
SELECT
    AVG(Price) AS Avg_Price,
    MAX(Price) AS Max_Price,
    MIN(Price) AS Min_Price
FROM Transaction_Details

-- 3.What are the total, maximum, and average refund amounts,
-- and what percentage of total revenue do refunds represent?
SELECT
    SUM(Refunded_Amount) AS Total_Refunds,
    MAX(Refunded_Amount) AS The_Highest_Refund_Amount,
    ROUND(AVG(Refunded_Amount), 2) AS Avg_Refund_Per_Sale,
    ROUND(AVG(NULLIF(Refunded_Amount, 0)), 2) AS Avg_Refund_Per_Refunded_Ticket,
    CONCAT(
    CAST(
    (SUM(Refunded_Amount) * 100.0) / SUM(Price) AS DECIMAL(5, 2)), '%')
    AS Refunds_Percentage
FROM Transaction_Details

-- 4.What are the average, maximum, and minimum journey durations across all trips?
SELECT
    AVG(Journey_Duration_Minutes) AS Avg_Trip_Minutes,
    MAX(Journey_Duration_Minutes) AS Max_Trip_Duration,
    MIN(Journey_Duration_Minutes) AS Min_Trip_Duration
FROM Transaction_Details

------------ Revenue Insights ------------
-- 5.How do Gross Revenue, Refunds, and Net Revenue compare across different ticket types,
-- and which ticket type generates the highest revenue?
SELECT
    t.Ticket_Type,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Price - Refunded_Amount) AS Net_Revenue
FROM Transaction_Details td JOIN Tickets t
ON t.Ticket_Type_ID = td.Ticket_Type_ID
GROUP BY t.Ticket_Type
ORDER BY Gross_Revenue DESC

-- 6.How does revenue (Gross, Refunds, and Net) vary across different ticket classes,
-- and which ticket class generates the highest gross revenue?
SELECT
    t.Ticket_Class,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Price - Refunded_Amount) AS Net_Revenue
FROM Transaction_Details td JOIN Tickets t
ON t.Ticket_Type_ID = td.Ticket_Type_ID
GROUP BY t.Ticket_Class
ORDER BY Gross_Revenue DESC

-- 7.How do different payment methods compare in terms of Gross Revenue, Refunds,
-- and Net Revenue, and which payment method generates the highest revenue?
SELECT
    p.Payment_Method,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Price - Refunded_Amount) AS Net_Revenue
FROM Transaction_Details td JOIN Payments p
ON p.Payment_ID = td.Payment_ID
GROUP BY p.Payment_Method
ORDER BY Gross_Revenue DESC

-- 8.How does revenue (Gross, Refunds, and Net Revenue) differ across purchase types,
-- and which purchase type contributes the most revenue?
SELECT
    p.Purchase_Type,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Price - Refunded_Amount) AS Net_Revenue
FROM Transaction_Details td JOIN Purchase_Type p
ON p.Purchase_Type_ID = td.Purchase_Type_ID
GROUP BY p.Purchase_Type
ORDER BY Gross_Revenue DESC

-- 9.How does revenue (Gross, Refunds, and Net Revenue) vary across different routes,
-- and which route generates the highest gross revenue?
SELECT
    r.Route_Name,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Price - Refunded_Amount) AS Net_Revenue
FROM Transaction_Details td JOIN Routes r
ON r.Route_ID = td.Route_ID
GROUP BY r.Route_Name
ORDER BY Gross_Revenue DESC

-- 10.How do Gross Revenue, Refunds, and Net Revenue vary across different months,
-- and which month generates the highest revenue?
SELECT
    d.Month_Name,
    SUM(Price) AS Gross_Revenue,
    SUM(Refunded_Amount) AS Refunds,
    SUM(Price - Refunded_Amount) AS Net_Revenue
FROM Transaction_Details td JOIN Dates d
ON d.Date_ID = td.Purchase_Date_ID
GROUP BY d.Month_Name
ORDER BY Gross_Revenue DESC

------------ Customer behavior & demand ------------
-- 11.What is the distribution of trips across different ticket types?
SELECT
    t.Ticket_Type,
    COUNT(*) AS Trips,
    CONCAT(
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Tickets t
ON t.Ticket_Type_ID = td.Ticket_Type_ID
GROUP BY t.Ticket_Type
ORDER BY Trips DESC

-- 12.What is the distribution of trips across different ticket classes?
SELECT
    t.Ticket_Class,
    COUNT(*) AS Trips,
    CONCAT(
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Tickets t
ON t.Ticket_Type_ID = td.Ticket_Type_ID
GROUP BY t.Ticket_Class
ORDER BY Trips DESC

-- 13.What is the distribution of trips across different purchase types?
SELECT
    p.Purchase_Type,
    COUNT(*) AS Trips,
    CONCAT(
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Purchase_Type p
ON p.Purchase_Type_ID = td.Purchase_Type_ID
GROUP BY p.Purchase_Type
ORDER BY Trips DESC

-- 14.What is the distribution of trips across different payment methods?
SELECT
    p.Payment_Method,
    COUNT(*) AS Trips,
    CONCAT(
    CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Payments p
ON p.Payment_ID = td.Payment_ID
GROUP BY p.Payment_Method
ORDER BY Trips DESC

-- 15.How do trips and average prices differ between passengers with & without a railcard?
SELECT
    CASE 
        WHEN r.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END AS Railcard_Status,
    COUNT(*) AS Trips,
    CONCAT(
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5, 2)), '%')
    AS Percentage,
    ROUND(AVG(Price), 2) AS Avg_Price
FROM Transaction_Details td JOIN Railcard r
ON r.Railcard_ID = td.Railcard_ID
GROUP BY
    CASE 
        WHEN r.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END
ORDER BY Trips DESC

-- 16.How do trips, percentage distribution, and average prices
-- compare across different railcard types (excluding non-railcard users)?
SELECT
    r.Railcard_Type,
    COUNT(*) AS Trips,
    CONCAT(
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5, 2)), '%')
    AS Percentage,
    ROUND(AVG(Price), 2) AS Avg_Price
FROM Transaction_Details td JOIN Railcard r
ON r.Railcard_ID = td.Railcard_ID
GROUP BY r.Railcard_Type
HAVING r.Railcard_Type <> 'None'
ORDER BY Trips DESC

-- 17.What is the distribution of trips across different routes?
SELECT
    r.Route_Name,
    COUNT(*) AS Trips,
    CONCAT(
        CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Routes r
ON r.Route_ID = td.Route_ID
GROUP BY r.Route_Name
ORDER BY Trips DESC

------------ Temporal Trends ------------
-- 18.How are trips distributed across different months?
SELECT
    d.Month_Name,
    COUNT(*) AS Trips,
    CONCAT(
        CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Dates d
ON d.Date_ID = td.Purchase_Date_ID
GROUP BY d.Month_Name
ORDER BY Trips DESC

-- 19.How are trips distributed across different days of the week?
SELECT
    d.Day_Name,
    COUNT(*) AS Trips,
    CONCAT(
        CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Dates d
ON d.Date_ID = td.Purchase_Date_ID
GROUP BY d.Day_Name
ORDER BY Trips DESC

-- 20.How are trips distributed between weekday and weekend days?
SELECT
    d.Day_Type,
    COUNT(*) AS Trips,
    CONCAT(
        CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Dates d
ON d.Date_ID = td.Purchase_Date_ID
GROUP BY d.Day_Type
ORDER BY Trips DESC

-- 21.How are trips distributed across different hours of the day?
SELECT
    t.Hour_24,
    COUNT(*) AS Trips,
    CONCAT(
        CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Times t
ON t.Time_ID = td.Purchase_Time_ID
GROUP BY t.Hour_24
ORDER BY Trips DESC

-- 22.How do trip counts and total delay minutes vary across different hours of the day?
SELECT
    t.Hour_24,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes
FROM Transaction_Details td JOIN Times t
ON t.Time_ID = td.Purchase_Time_ID
GROUP BY t.Hour_24
ORDER BY Delay_Minutes DESC

------------ Operational Performance ------------
-- 23.How do trip counts and delay patterns differ across ticket classes?
SELECT
    t.Ticket_Class,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    AVG(NULLIF(Delay_Minutes, 0)) AS Avg_Delay_Per_Delayed
FROM Transaction_Details td JOIN Tickets t
ON t.Ticket_Type_ID = td.Ticket_Type_ID
GROUP BY t.Ticket_Class
ORDER BY Delay_Minutes DESC

-- 24.How do refund requests vary across different ticket classes in terms of trip counts?
SELECT
    t.Ticket_Class,
    COUNT(*) AS Trips,
    COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) AS Refund_Request,
    CONCAT(
        CAST((COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
        AS DECIMAL(5, 2)), '%')
    AS Refund_Percentage
FROM Transaction_Details td JOIN Tickets t
ON t.Ticket_Type_ID = td.Ticket_Type_ID
JOIN Refunds rf
ON rf.Refund_ID = td.Refund_ID
GROUP BY t.Ticket_Class
ORDER BY Refund_Percentage DESC

-- 25.How do trip counts and delay patterns vary across different ticket types?
SELECT
    t.Ticket_Type,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    AVG(NULLIF(Delay_Minutes, 0)) AS Avg_Delay_Per_Delayed
FROM Transaction_Details td JOIN Tickets t
ON t.Ticket_Type_ID = td.Ticket_Type_ID
GROUP BY t.Ticket_Type
ORDER BY Delay_Minutes DESC

-- 26.How do refund requests vary across different ticket types in terms of trip counts?
SELECT
    t.Ticket_Type,
    COUNT(*) AS Trips,
    COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) AS Refund_Request,
    CONCAT(
        CAST((COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
        AS DECIMAL(5, 2)), '%')
    AS Refund_Percentage
FROM Transaction_Details td JOIN Tickets t
ON t.Ticket_Type_ID = td.Ticket_Type_ID
JOIN Refunds rf
ON rf.Refund_ID = td.Refund_ID
GROUP BY t.Ticket_Type
ORDER BY Refund_Percentage DESC

-- 27.How do trip counts and delay patterns vary across different purchase types?
SELECT
    p.Purchase_Type,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    AVG(NULLIF(Delay_Minutes, 0)) AS Avg_Delay_Per_Delayed
FROM Transaction_Details td JOIN Purchase_Type p
ON p.Purchase_Type_ID = td.Purchase_Type_ID
GROUP BY p.Purchase_Type
ORDER BY Delay_Minutes DESC

-- 28.How do refund requests vary across different purchase types in terms of trip counts?
SELECT
    p.Purchase_Type,
    COUNT(*) AS Trips,
    COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) AS Refund_Request,
    CONCAT(
        CAST((COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
        AS DECIMAL(5, 2)), '%')
    AS Refund_Percentage
FROM Transaction_Details td JOIN Purchase_Type p
ON p.Purchase_Type_ID = td.Purchase_Type_ID
JOIN Refunds rf
ON rf.Refund_ID = td.Refund_ID
GROUP BY p.Purchase_Type
ORDER BY Refund_Percentage DESC

-- 29.How do trip counts and delay patterns vary across different payment methods?
SELECT
    p.Payment_Method,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    AVG(NULLIF(Delay_Minutes, 0)) AS Avg_Delay_Per_Delayed
FROM Transaction_Details td JOIN Payments p
ON p.Payment_ID = td.Payment_ID
GROUP BY p.Payment_Method
ORDER BY Delay_Minutes DESC

-- 30.How do refund requests vary across different payment methods in terms of trip counts?
SELECT
    p.Payment_Method,
    COUNT(*) AS Trips,
    COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) AS Refund_Request,
    CONCAT(
        CAST((COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
        AS DECIMAL(5, 2)), '%')
    AS Refund_Percentage
FROM Transaction_Details td JOIN Payments p
ON p.Payment_ID = td.Payment_ID
JOIN Refunds rf
ON rf.Refund_ID = td.Refund_ID
GROUP BY p.Payment_Method
ORDER BY Refund_Percentage DESC

-- 31.How do trip counts and delay patterns differ between passengers with & without a railcard?
SELECT
    CASE 
        WHEN r.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END AS Railcard_Status,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    AVG(NULLIF(Delay_Minutes, 0)) AS Avg_Delay_Per_Delayed
FROM Transaction_Details td JOIN Railcard r
ON r.Railcard_ID = td.Railcard_ID
GROUP BY
    CASE 
        WHEN r.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END
ORDER BY Delay_Minutes DESC

-- 32.How do refund requests differ between passengers with & without a railcard in terms of trip counts?
SELECT
    CASE 
        WHEN r.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END AS Railcard_Status,
    COUNT(*) AS Trips,
    COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) AS Refund_Request,
    CONCAT(
        CAST((COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
        AS DECIMAL(5, 2)), '%')
    AS Refund_Percentage
FROM Transaction_Details td JOIN Railcard r
ON r.Railcard_ID = td.Railcard_ID
JOIN Refunds rf
ON rf.Refund_ID = td.Refund_ID
GROUP BY
    CASE 
        WHEN r.Railcard_Type = 'None' THEN 'No Railcard'
        ELSE 'Has Railcard'
    END
ORDER BY Refund_Percentage DESC

-- 33.How do trip counts and delay patterns vary across different routes?
SELECT
    r.Route_Name,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    AVG(NULLIF(Delay_Minutes, 0)) AS Avg_Delay_Per_Delayed
FROM Transaction_Details td JOIN Routes r
ON r.Route_ID = td.Route_ID
GROUP BY r.Route_Name
HAVING SUM(Delay_Minutes) <> 0
ORDER BY Delay_Minutes DESC

-- 34.How do refund requests vary across different routes in terms of trip counts?
SELECT
    r.Route_Name,
    COUNT(*) AS Trips,
    COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) AS Refund_Request,
    CONCAT(
        CAST((COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
        AS DECIMAL(5, 2)), '%')
    AS Refund_Percentage
FROM Transaction_Details td JOIN Routes r
ON r.Route_ID = td.Route_ID
JOIN Refunds rf
ON rf.Refund_ID = td.Refund_ID
GROUP BY r.Route_Name
ORDER BY (COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
DESC

-- 35.What are the most common reasons for trip delays?
SELECT
    d.Reason_for_Delay,
    COUNT(*) AS Trips,
    CONCAT(
        CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Delay_Reasons d
ON d.Delay_ID = td.Delay_ID
GROUP BY d.Reason_for_Delay
HAVING d.Reason_for_Delay <> 'No Delay'
ORDER BY Trips DESC

-- 36.How do delay reasons compare in terms of trip counts, total delay minutes,
-- and average delay duration per trip?
SELECT
    d.Reason_for_Delay,
    COUNT(*) AS Trips,
    SUM(Delay_Minutes) AS Delay_Minutes,
    AVG(Delay_Minutes) AS Avg_Delay_Minutes
FROM Transaction_Details td JOIN Delay_Reasons d
ON d.Delay_ID = td.Delay_ID
GROUP BY d.Reason_for_Delay
HAVING d.Reason_for_Delay <> 'No Delay'
ORDER BY Delay_Minutes DESC

-- 37.How do refund requests vary across different delay reasons in terms of trip counts?
SELECT
    d.Reason_for_Delay,
    COUNT(*) AS Trips,
    COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) AS Refund_Request,
    CONCAT(
        CAST((COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
        AS DECIMAL(5, 2)), '%')
    AS Refund_Percentage
FROM Transaction_Details td JOIN Delay_Reasons d
ON d.Delay_ID = td.Delay_ID
JOIN Refunds rf
ON rf.Refund_ID = td.Refund_ID
GROUP BY d.Reason_for_Delay
HAVING d.Reason_for_Delay <> 'No Delay'
ORDER BY (COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
DESC

-- 38.What is the distribution of journey statuses?
SELECT
    s.Journey_Status,
    COUNT(*) AS Trips,
    CONCAT(
        CAST((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)), '%')
    AS Percentage
FROM Transaction_Details td JOIN Status s
ON s.Status_ID = td.Status_ID
GROUP BY s.Journey_Status
ORDER BY Trips DESC

-- 39.How do trip counts and delay patterns vary across different journey statuses?
SELECT
    s.Journey_Status,
    COUNT(*) AS Trips,
    SUM(COALESCE(Delay_Minutes, 0)) AS Delay_Minutes,
    AVG(COALESCE(Delay_Minutes, 0)) AS Avg_Delay_Per_Delayed
FROM Transaction_Details td JOIN Status s
ON s.Status_ID = td.Status_ID
GROUP BY s.Journey_Status
ORDER BY Delay_Minutes DESC

-- 40.How do refund requests vary across different journey statuses in terms of trip counts?
SELECT
    s.Journey_Status,
    COUNT(*) AS Trips,
    COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) AS Refund_Request,
    CONCAT(
        CAST((COUNT(CASE WHEN rf.Refund_Request = 'Yes' THEN 1 END) * 100.0) / COUNT(*)
        AS DECIMAL(5, 2)), '%')
    AS Refund_Percentage
FROM Transaction_Details td JOIN Status s
ON s.Status_ID = td.Status_ID
JOIN Refunds rf
ON rf.Refund_ID = td.Refund_ID
GROUP BY s.Journey_Status
ORDER BY Refund_Percentage DESC