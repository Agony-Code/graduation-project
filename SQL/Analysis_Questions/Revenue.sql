-- ((( Revenue & Pricing Analysis )))

-- 1. What is the total revenue before discounts?
SELECT ROUND(SUM(Original_Price), 2) AS Revenue_Before_Discounts
FROM Transactions

-- 2. What is the total revenue after discounts?
SELECT ROUND(SUM(Final_Price), 2) AS Revenue_After_Discounts
FROM Transactions

-- 3. How much revenue is lost due to discounts?
SELECT ROUND(SUM(Discount_Amount), 2) AS Revenue_Loss
FROM Transactions

-- 4. What is the total profit?
SELECT SUM(Profit) AS Net_Profit
FROM Transactions

-- 5. What is the average revenue and profit per transaction?
SELECT
	ROUND(AVG(Final_Price), 2) AS AVG_Price,
	ROUND(AVG(Profit), 2) AS AVG_Profit
FROM Transactions

-- 6. What percentage of total revenue is impacted by discounts?
SELECT
    ROUND(SUM(Original_Price), 2) AS Total_Revenue_Before_Discount,
    ROUND(SUM(Discount_Amount), 2) AS Total_Discount_Value,
    SUM(Final_Price) AS Total_Revenue_After_Discount,
    CAST(
        (SUM(Discount_Amount) * 100.0) / SUM(Original_Price)
        AS DECIMAL(5,2)) AS Discount_Impact_Percentage
FROM Transactions

-- 7. Which ticket types generate the highest revenue?
SELECT
    Ticket_Type,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Ticket_Type
ORDER BY Gross_Revenue DESC

-- 8. Which ticket class generates the highest revenue?
SELECT
    Ticket_Class,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Ticket_Class
ORDER BY Gross_Revenue DESC

-- 9. Which payment methods generate the highest revenue?
SELECT
    Payment_Method,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Payment_Method
ORDER BY Gross_Revenue DESC

-- 10. Which purchase type generates the highest revenue?
SELECT
    Purchase_Type,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Transactions
GROUP BY Purchase_Type
ORDER BY Gross_Revenue DESC

-- 11. Which routes generate the highest revenue and profit?
SELECT TOP 10
    R.Route_Name,
    SUM(Final_Price) AS Gross_Revenue,
    SUM(Profit) AS Net_Revenue
FROM Routes R JOIN Transactions T
ON T.Route_ID = R.Route_ID
GROUP BY R.Route_Name
ORDER BY Gross_Revenue DESC

-- 12. Which railcard generates the highest revenue and profit?
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

-- 13. How do Railcard revenue compare to non-Railcard?
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

-- 14. Do discounted tickets generate higher or lower profit than full-price tickets?
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

-- 15. How does pricing strategy affect overall profitability?
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