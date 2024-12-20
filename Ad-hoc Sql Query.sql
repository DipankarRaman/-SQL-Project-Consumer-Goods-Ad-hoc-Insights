# 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.


SELECT DISTINCT(market) 
FROM dim_customer
WHERE customer = "Atliq Exclusive" 
  AND region = "APAC"
GROUP BY market;


# 2. What is the percentage of unique product increase in 2024 vs. 2023? 


WITH cte23 AS (
    SELECT count(DISTINCT product_code) AS unique_products_2023 
    FROM fact_manufacturing_cost f
    WHERE cost_year = 2023
),
cte24 AS (
    SELECT count(DISTINCT product_code) AS unique_products_2024 
    FROM fact_manufacturing_cost f
    WHERE cost_year = 2024
)
SELECT *, 
       ROUND((unique_products_2024 - unique_products_2023) * 100 / unique_products_2023, 2) AS percentage_chg 
FROM cte23 
CROSS JOIN cte24;


# 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.


SELECT segment, 
       count(distinct product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


# 4. Follow-up: Which segment had the most increase in unique products in 2024 vs 2023?


WITH cte2023 AS (
    SELECT segment, 
           count(DISTINCT dp.product_code) AS product_count_2023 
    FROM dim_product dp 
    JOIN fact_gross_price fp ON dp.product_code = fp.product_code
    WHERE fiscal_year = 2023
    GROUP BY segment
),
cte2024 AS (
    SELECT segment, 
           count(DISTINCT dp.product_code) AS product_count_2024 
    FROM dim_product dp 
    JOIN fact_gross_price fp ON dp.product_code = fp.product_code
    WHERE fiscal_year = 2024
    GROUP BY segment
)
SELECT cte2023.segment, 
       product_count_2023, 
       product_count_2024, 
       ABS(product_count_2024 - product_count_2023) AS difference 
FROM cte2023
JOIN cte2024 ON cte2023.segment = cte2024.segment
ORDER BY difference DESC;


# 5. Get the products that have the highest and lowest manufacturing costs.


SELECT dp.product_code, 
       dp.product, 
       fc.manufacturing_cost
FROM dim_product dp 
JOIN fact_manufacturing_cost fc USING(product_code)
WHERE fc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
   OR fc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost);


# 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2024 and in the Indian market.


SELECT fd.customer_code, 
       customer, 
       ROUND(AVG(pre_invoice_discount_pct) * 100, 2) AS average_discount_percentage 
FROM fact_pre_invoice_deductions fd 
JOIN dim_customer USING(customer_code)
WHERE fiscal_year = 2024 
  AND market = "India"
GROUP BY fd.customer_code, customer
ORDER BY average_discount_percentage DESC 
LIMIT 5;


# 7. Get the complete report of the Gross sales amount for the customer “Atliq exclusive” for each month.


SELECT MONTHNAME(fm.date) AS month, 
       YEAR(fm.date) AS year, 
       CONCAT(ROUND(SUM(fp.gross_price * fm.sold_quantity) / 1000000, 2), 'M') AS gross_sales_amount
FROM dim_customer dc
JOIN fact_Sales_monthly fm USING(customer_code)
JOIN fact_gross_price fp ON fm.product_code = fp.product_code AND fm.fiscal_year = fp.fiscal_year
WHERE dc.customer = "Atliq Exclusive"
GROUP BY month, year
ORDER BY year;


# 8. In which quarter of 2023, got the maximum total_sold_quantity?


SELECT CASE
           WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
           WHEN MONTH(date) IN (12, 01, 02) THEN 'Q2'
           WHEN MONTH(date) IN (03, 04, 05) THEN 'Q3'
           ELSE 'Q4'
       END AS Quarters, 
       SUM(sold_quantity) AS total_sold_qty
FROM fact_sales_monthly
WHERE fiscal_year = 2023
GROUP BY Quarters
ORDER BY total_sold_qty DESC;


# 9. Which channel helped to bring more gross sales in the fiscal year 2024 and the percentage of contribution?


SELECT dc.channel, 
       ROUND(SUM(fm.sold_quantity * fp.gross_price) / 1000000, 2) AS gross_sales_mln, 
       ROUND((SUM(fm.sold_quantity * fp.gross_price) / SUM(SUM(fm.sold_quantity * fp.gross_price)) OVER ()) * 100, 2) AS percentage
FROM dim_customer dc 
JOIN fact_sales_monthly fm USING(customer_code)
JOIN fact_gross_price fp ON fp.product_code = fm.product_code AND fp.fiscal_year = fm.fiscal_year
WHERE fm.fiscal_year = 2024
GROUP BY dc.channel
ORDER BY gross_sales_mln DESC;


# 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2024?


WITH temp AS (
    SELECT dp.division, 
           dp.product_code, 
           dp.product, 
           SUM(fm.sold_quantity) AS total_quantity_sold
    FROM dim_product dp
    JOIN fact_sales_monthly fm USING(product_code)
    WHERE fm.fiscal_year = 2024
    GROUP BY dp.division, dp.product_code, dp.product
)
SELECT division, 
       product_code, 
       product, 
       total_quantity_sold, 
       product_rank
FROM (
    SELECT division, 
           product_code, 
           product, 
           total_quantity_sold, 
           RANK() OVER (PARTITION BY division ORDER BY total_quantity_sold DESC) AS product_rank
    FROM temp
) AS ranked_products
WHERE product_rank <= 3
ORDER BY division, product_rank;

