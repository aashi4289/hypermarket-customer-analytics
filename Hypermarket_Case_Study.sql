-- 1: Average points earned per customer, by gender

SELECT Gender, AVG(Points_earned) AS Avg_Points_Earned
FROM Customer
GROUP BY Gender;

-- 2: Customers with above-average points redeemed

SELECT c.Customer_ID, c.Points_Redemed, a.Overall_Avg_Points_Redemed
FROM Customer as c
CROSS JOIN (SELECT AVG(Points_Redemed) AS Overall_Avg_Points_Redemed FROM Customer) as a
WHERE c.Points_Redemed > a.Overall_Avg_Points_Redemed
ORDER BY c.Points_Redemed DESC;

-- 3: Percentage of churned customers (LTD before 01-Jan-2013)

SELECT COUNT(*) AS Total_Customers,SUM(CASE WHEN LTD < 20130101 THEN 1 ELSE 0 END) AS Churned_Customers,
ROUND(100.0 * SUM(CASE WHEN LTD < 20130101 THEN 1 ELSE 0 END) / COUNT(*), 2) AS Percentage
FROM Customer;

-- 4: Rank customers by total points earned (highest first)

SELECT Customer_ID, Points_earned AS Points_Earned, RANK() OVER (ORDER BY Points_earned DESC) AS Points_Rank
FROM Customer
ORDER BY Points_Rank;

-- 5: Average total orders per gender, ranked

SELECT Gender, AVG(Total_Orders) AS Avg_Total_Orders,RANK() OVER (ORDER BY AVG(Total_Orders) DESC) AS Orders_Rank
FROM Customer
GROUP BY Gender;

-- 6: Month-over-month change in active customers

WITH txn AS (
    SELECT USER_ID,
           CASE WHEN STR_TO_DATE(Order_time, '%d-%m-%Y') < '2012-01-01'
                THEN DATE('2012-01-01')
                ELSE DATE_FORMAT(STR_TO_DATE(Order_time, '%d-%m-%Y'), '%Y-%m-01')
           END AS month_start
    FROM Transactions
),
monthly AS (
    SELECT month_start,
           COUNT(DISTINCT USER_ID) AS Active_Customers
    FROM txn
    GROUP BY month_start
)
SELECT YEAR(month_start)  AS `Year`,
       MONTH(month_start) AS `Month`,
       Active_Customers,
       LAG(Active_Customers) OVER (ORDER BY month_start) AS Prev_Month_Active,
       Active_Customers
         - LAG(Active_Customers) OVER (ORDER BY month_start) AS MoM_Change
FROM monthly
ORDER BY month_start;

-- 7: Top customer by points redeemed for each merchant location (customers counted at every location they shopped at)

WITH cust_loc AS (
    SELECT DISTINCT p.Merchant_Location, t.USER_ID AS Customer_ID
    FROM Transactions t
    JOIN Product p
      ON t.Product_id  = p.Product_Id
     AND t.Merchant_id = p.Merchant_id
),
ranked AS (
    SELECT cl.Merchant_Location,
           cl.Customer_ID,
           c.Points_Redemed,
           RANK() OVER (PARTITION BY cl.Merchant_Location
                        ORDER BY c.Points_Redemed DESC) AS Location_Rank
    FROM cust_loc cl
    JOIN Customer c ON c.Customer_ID = cl.Customer_ID
)
SELECT Merchant_Location, Customer_ID, Points_Redemed, Location_Rank
FROM ranked
WHERE Location_Rank = 1
ORDER BY Merchant_Location;

-- 8: Running total of active customers by month

WITH txn AS (
    SELECT USER_ID,
           CASE WHEN STR_TO_DATE(Order_time, '%d-%m-%Y') < '2012-01-01'
                THEN DATE('2012-01-01')
                ELSE DATE_FORMAT(STR_TO_DATE(Order_time, '%d-%m-%Y'), '%Y-%m-01')
           END AS month_start
    FROM Transactions
),
monthly AS (
    SELECT month_start,
           COUNT(DISTINCT USER_ID) AS Active_Customers
    FROM txn
    GROUP BY month_start
)
SELECT YEAR(month_start)  AS `Year`,
       MONTH(month_start) AS `Month`,
       Active_Customers,
       SUM(Active_Customers) OVER (ORDER BY month_start
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
         AS Running_Total
FROM monthly
ORDER BY month_start;

-- 9: Weekly transaction count for the top 5 customers by points earned ISO weeks; Year is included so Week 1 of 2012 and 2013 stay separate

WITH top5 AS (
    SELECT Customer_ID
    FROM Customer
    ORDER BY Points_earned DESC
    LIMIT 5
)
SELECT t.USER_ID AS Customer_ID,
       YEAR(STR_TO_DATE(t.Order_time, '%d-%m-%Y'))      AS `Year`,
       WEEK(STR_TO_DATE(t.Order_time, '%d-%m-%Y'), 3)   AS Week_Number,
       COUNT(DISTINCT t.Order_id)                       AS Transactions_Handled
FROM Transactions t
JOIN top5 ON top5.Customer_ID = t.USER_ID
GROUP BY t.USER_ID,
         YEAR(STR_TO_DATE(t.Order_time, '%d-%m-%Y')),
         WEEK(STR_TO_DATE(t.Order_time, '%d-%m-%Y'), 3)
ORDER BY t.USER_ID, `Year`, Week_Number;

-- 10: Average customer value by segment

SELECT Segment,
       AVG(Customer_Total_value) AS Avg_Customer_Value
FROM (
    SELECT Customer_Total_value,
           CASE
             WHEN LTD BETWEEN 20130101 AND 20130331
                  AND Customer_Total_value > 10000 THEN 'Loyal'
             WHEN LTD BETWEEN 20130101 AND 20130331 THEN 'Active'
             WHEN LTD BETWEEN 20120901 AND 20121231 THEN 'Inactive'
             ELSE 'Churned'
           END AS Segment
    FROM Customer
) s
GROUP BY Segment;