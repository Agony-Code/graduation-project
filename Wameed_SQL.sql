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
	Refund_Request VARCHAR(20),
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
    CONSTRAINT Transaction_Details_DepartureTime_FK FOREIGN KEY (Journey_Time_ID) REFERENCES Times(Time_ID)
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
    rc.Refund_Request,
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

ALTER TABLE Transaction_Details
ADD CONSTRAINT Transaction_Details_Purchase_FK FOREIGN KEY (Purchase_Type_ID) REFERENCES Purchase_Type(Purchase_Type_ID)

SELECT *
FROM Transaction_Details
------------------------------