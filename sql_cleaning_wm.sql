-- * Create Database * --
CREATE DATABASE UK_Train_Rides

-- * Use Database * --
USE UK_Train_Rides

-- * Create The Main Table * --
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
	Departure_Station VARCHAR(100),
	Arrival_Destination VARCHAR(100),
	Date_of_Journey DATE,
	Departure_Time TIME(0),
	Arrival_Time TIME(0),
	Actual_Arrival_Time TIME(0),
	Journey_Status VARCHAR(20),
	Reason_for_Delay VARCHAR(20),
	Refund_Request VARCHAR(5)
	CONSTRAINT railway_PK PRIMARY KEY (Transaction_ID)
)

-- * Insert Values Into The Main Table * --
BULK INSERT railway
FROM 'C:\Users\01004\OneDrive\Desktop\DEPI_Final_PJ\Original_Data\railway.csv'
WITH (
	FIRSTROW = 2,
	ROWTERMINATOR = '0x0a',
	FIELDTERMINATOR = ','
)

-- * Show The Main Table * --
SELECT *
FROM railway
ORDER BY Transaction_ID ASC

-- * Create a Copy From The Table * --
SELECT *
INTO railway_cleaned
FROM railway
ORDER BY Transaction_ID ASC

-- * Show The New Table * --
SELECT *
FROM railway_cleaned

-- * Searching NULL Values * --
SELECT DISTINCT Reason_for_Delay
FROM railway_cleaned

-- * Correcting NULL Values * --
UPDATE railway_cleaned
SET Reason_for_Delay = 'No Delay'
WHERE Reason_for_Delay IS NULL
AND Journey_Status = 'On Time'

-- * Searching Duplicates * --
SELECT Transaction_ID, COUNT(*) AS Count_Duplicates
FROM railway_cleaned
GROUP BY Transaction_ID
HAVING COUNT(*) > 1 --> No Duplicates Founded

-- * Editing Incorrect Values * --
UPDATE railway_cleaned
SET Refund_Request = 'No'
WHERE Refund_Request LIKE '%No%'

UPDATE railway_cleaned
SET Refund_Request = 'Yes'
WHERE Refund_Request LIKE '%Yes%'

SELECT *
FROM railway_cleaned
WHERE Refund_Request = 'Yes'

SELECT *
FROM railway_cleaned
WHERE Refund_Request = 'No'
---------------------------
UPDATE railway_cleaned
SET Reason_for_Delay = 'Staffing'
WHERE Reason_for_Delay LIKE 'Staff Shortage'

UPDATE railway_cleaned
SET Reason_for_Delay = 'Weather'
WHERE Reason_for_Delay LIKE 'Weather Conditions'

UPDATE railway_cleaned
SET Reason_for_Delay = 'Signal Failure'
WHERE Reason_for_Delay LIKE 'Signal failure'

SELECT DISTINCT Reason_for_Delay
FROM railway_cleaned

-- * Feature Engineering * --

-- 1.Month_of_Purchase
ALTER TABLE railway_cleaned
ADD Month_of_Purchase VARCHAR(50)

UPDATE railway_cleaned
SET Month_of_Purchase = DATENAME(MONTH, Date_of_Purchase)

-- 2.Purchase_Hour
ALTER TABLE railway_cleaned
ADD Purchase_Hour INT

UPDATE railway_cleaned
SET Purchase_Hour = DATEPART(HOUR, Time_of_Purchase)

-- 3.Delay_Minutes
ALTER TABLE railway_cleaned
ADD Delay_Minutes INT

UPDATE railway_cleaned
SET Delay_Minutes = DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)

-- 4.Journey_Duration_Minutes
ALTER TABLE railway_cleaned
ADD Journey_Duration_Minutes INT

UPDATE railway_cleaned
SET Journey_Duration_Minutes = 
    CASE 
        WHEN DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time) < 0 
        THEN DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time) + 1440
        ELSE DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time)
    END

-- 5.Departure_Day
ALTER TABLE railway_cleaned
ADD Departure_Day VARCHAR(50)

UPDATE railway_cleaned
SET Departure_Day = DATENAME(WEEKDAY, Date_of_Journey)

-- 6.Departure_Hour
ALTER TABLE railway_cleaned
ADD Departure_Hour INT

UPDATE railway_cleaned
SET Departure_Hour = DATEPART(HOUR, Departure_Time)

-- * Normalization * --
-- 1.Stations Table

CREATE TABLE stations (
	station_ID INT IDENTITY(1, 1),
	station_name VARCHAR(50)
	CONSTRAINT stations_PK PRIMARY KEY (station_ID)
)

INSERT INTO stations
SELECT DISTINCT Departure_Station AS station_name
FROM railway_cleaned
UNION
SELECT DISTINCT Arrival_Destination AS station_name
FROM railway_cleaned
ORDER BY station_name ASC

SELECT *
FROM stations

-- 2.Tickets Table

CREATE TABLE tickets (
	ticket_ID INT IDENTITY(1, 1),
	ticket_class VARCHAR(20),
	ticket_type VARCHAR(20),
	railcard VARCHAR(20)
	CONSTRAINT tickets_PK PRIMARY KEY (ticket_ID)
)

INSERT INTO tickets
SELECT DISTINCT Ticket_Class, Ticket_Type, Railcard
FROM railway_cleaned

SELECT *
FROM tickets

-- 3.Payment Table

CREATE TABLE payment (
	payment_ID INT IDENTITY(1, 1),
	payment_type VARCHAR(20),
	payment_method VARCHAR(20)

	CONSTRAINT payment_PK PRIMARY KEY (payment_ID)
)

INSERT INTO payment
SELECT DISTINCT Purchase_Type, Payment_Method
FROM railway_cleaned

SELECT *
FROM payment

-- 4.Transactions Table

CREATE TABLE transactions (
	transaction_ID VARCHAR(50),
	journey_date DATE,
	station_original_ID INT,
	station_destination_ID INT,
	ticket_type_ID INT,
	payment_ID INT,
	price MONEY,
	delay_minutes INT,
	Journey_Duration_Minutes INT,
    Journey_Status VARCHAR(20)

	CONSTRAINT transactions_PK PRIMARY KEY (transaction_ID),
	FOREIGN KEY (station_original_ID) REFERENCES stations(Station_ID),
    FOREIGN KEY (station_destination_ID) REFERENCES stations(Station_ID),
	FOREIGN KEY (payment_ID) REFERENCES payment(payment_ID),
    FOREIGN KEY (Ticket_Type_ID) REFERENCES tickets(ticket_ID)
)

INSERT INTO transactions
SELECT DISTINCT
	c.Transaction_ID,
	c.Date_of_Journey,
	s1.station_ID,
	s2.station_ID,
	t.ticket_ID,
	p.payment_ID,
	c.Price,
	c.Delay_Minutes,
	c.Journey_Duration_Minutes,
	c.Journey_Status
	
FROM railway_cleaned c JOIN stations s1
ON c.Departure_Station = s1.station_name
JOIN stations s2
ON c.Arrival_Destination = s2.station_name
JOIN payment p
ON c.Purchase_Type = p.payment_type
	AND c.Payment_Method = p.payment_method
JOIN tickets t
ON c.Ticket_Class = t.ticket_class
	AND c.Ticket_Type = t.ticket_type
	AND c.Railcard = t.railcard

SELECT *
FROM transactions