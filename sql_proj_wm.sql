-- Creating The Database
CREATE DATABASE UK_Train_Rides

-- Select it
USE UK_Train_Rides

-- Create The Main Table
CREATE TABLE Railway (
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
	Refund_Request VARCHAR(5)

	CONSTRAINT Railway_PK PRIMARY KEY (Transaction_ID)
)

-- Inserting Data Into The Table
BULK INSERT Railway
FROM 'C:\Users\01004\OneDrive\Desktop\SQL_PROJ\Data\railway.csv'
WITH (
	FIRSTROW = 2,
	ROWTERMINATOR = '0x0a',
	FIELDTERMINATOR = ','
)

-- Show Data
SELECT *
FROM Railway

-- Create A Copy
SELECT *
INTO Railway_Cleaned
FROM Railway

-- Show The Copy
SELECT *
FROM Railway_Cleaned
ORDER BY Transaction_ID ASC

-- Correcting Missing Values
UPDATE Railway_Cleaned
SET Actual_Arrival_Time = NULL
WHERE Journey_Status = 'Cancelled'

UPDATE Railway_Cleaned
SET Reason_for_Delay = 'No Delay'
WHERE Journey_Status = 'On Time'

SELECT *
FROM Railway_Cleaned
WHERE Reason_for_Delay IS NULL

-- Checking For Duplicates & Inconsistent Data
SELECT Transaction_ID, COUNT(*) AS Count_Duplicates
FROM Railway_Cleaned
GROUP BY Transaction_ID
HAVING COUNT(*) > 1

UPDATE Railway_Cleaned
SET Reason_for_Delay = 'Staffing'
WHERE Reason_for_Delay = 'Staff Shortage'

UPDATE Railway_Cleaned
SET Reason_for_Delay = 'Weather'
WHERE Reason_for_Delay = 'Weather Conditions'

SELECT DISTINCT Reason_for_Delay
FROM Railway_Cleaned

UPDATE Railway_Cleaned
SET Refund_Request = 'No'
WHERE Refund_Request LIKE '%No%'

UPDATE Railway_Cleaned
SET Refund_Request = 'Yes'
WHERE Refund_Request LIKE '%Yes%'

-- ADD New Columns
ALTER TABLE Railway_Cleaned
ADD Month_of_Purchase VARCHAR(50)

UPDATE Railway_Cleaned
SET Month_of_Purchase = DATENAME(MONTH, Date_of_Purchase)
----------------------------
ALTER TABLE Railway_Cleaned
ADD Purchase_Hour INT

UPDATE Railway_Cleaned
SET Purchase_Hour = DATEPART(HOUR, Time_of_Purchase)
----------------------------
ALTER TABLE Railway_Cleaned
ADD Departure_Hour INT

UPDATE Railway_Cleaned
SET Departure_Hour = DATEPART(HOUR, Departure_Time)
----------------------------
ALTER TABLE Railway_Cleaned
ADD Departure_Day VARCHAR(50)

UPDATE Railway_Cleaned
SET Departure_Day = DATENAME(WEEKDAY, Date_of_Journey)
----------------------------
ALTER TABLE Railway_Cleaned
ADD Delay_Minutes INT

UPDATE Railway_Cleaned
SET Delay_Minutes = DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time)
----------------------------
ALTER TABLE Railway_Cleaned
ADD Journey_Duration_Minutes INT

UPDATE Railway_Cleaned
SET Journey_Duration_Minutes = DATEDIFF(MINUTE, Departure_Time, Actual_Arrival_Time)
----------------------------