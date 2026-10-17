-- business queries on the instacart data
-- run 01 to 03 first
-- numbers in the comments match what pandas gave, so the two sides agree
--
-- rule i followed: aggregate the big table first, join to products after.
-- joining all 33.8M rows first is a lot slower

USE instacart;


-- Q0: top 10 products (check against pandas)
-- joining first took 217 sec, aggregating first took 7.8 sec
-- banana 491,291 / bag of organic bananas 394,930 / organic strawberries 275,577

SELECT p.product_name, t.orders
FROM (
    SELECT product_id, COUNT(*) AS orders
    FROM order_products
    GROUP BY product_id
    ORDER BY orders DESC
    LIMIT 10
) t
JOIN products p ON p.product_id = t.product_id
ORDER BY t.orders DESC;


-- Q1: peak ordering hours
-- peak is hour 10 (282,470), all hours add up to 3,346,083

SELECT order_hour_of_day, COUNT(*) AS orders
FROM orders
GROUP BY order_hour_of_day
ORDER BY order_hour_of_day;


-- Q2: department-wise orders and reorder rate
-- IGNORE INDEX on purpose: with idx_product it took 10+ min (random lookups
-- for reordered), without it about 28 sec
-- produce 9,888,378 orders / 0.6505, dairy eggs 5,631,067 / 0.6702

SELECT p.department,
       SUM(t.orders)   AS orders,
       SUM(t.reorders) AS reorders,
       ROUND(SUM(t.reorders) / SUM(t.orders), 4) AS reorder_rate
FROM (
    SELECT product_id, COUNT(*) AS orders, SUM(reordered) AS reorders
    FROM order_products IGNORE INDEX (idx_product)
    GROUP BY product_id
) t
JOIN products p ON p.product_id = t.product_id
GROUP BY p.department
ORDER BY orders DESC;


-- Q3: customer segments by order count
-- the 30 and 10 cut-offs are my own choice
-- days_since_prior_order is capped at 30 in the data, so the gap for
-- occasional customers is probably higher than shown
-- occasional 98,771 (18.9 days), regular 77,304 (14.0), loyal 30,134 (7.3) = 206,209 customers

WITH user_stats AS (
    SELECT user_id,
           COUNT(*) AS total_orders,
           AVG(days_since_prior_order) AS avg_gap
    FROM orders
    GROUP BY user_id
)
SELECT CASE
           WHEN total_orders >= 30 THEN 'Loyal (30+)'
           WHEN total_orders >= 10 THEN 'Regular (10-29)'
           ELSE 'Occasional (<10)'
       END AS segment,
       COUNT(*) AS customers,
       ROUND(AVG(avg_gap), 1) AS avg_gap_days
FROM user_stats
GROUP BY segment
ORDER BY customers DESC;


-- Q4: top 3 products in each department
-- 21 departments x 3 = 63 rows
-- "missing" and "other" are unclassified departments

WITH prod AS (
    SELECT product_id, COUNT(*) AS orders
    FROM order_products
    GROUP BY product_id
),
ranked AS (
    SELECT p.department, p.product_name, prod.orders,
           ROW_NUMBER() OVER (PARTITION BY p.department
                              ORDER BY prod.orders DESC) AS rn
    FROM prod
    JOIN products p ON p.product_id = prod.product_id
)
SELECT department, product_name, orders
FROM ranked
WHERE rn <= 3
ORDER BY department, orders DESC;


-- Q5: days between orders
-- 31 rows (0 to 30), total 3,139,874 (all orders except first orders)
-- spikes at 7 (315,335) and 30 (346,256), 30 is probably "30 or more"

SELECT days_since_prior_order AS gap_days, COUNT(*) AS orders
FROM orders
WHERE days_since_prior_order IS NOT NULL
GROUP BY days_since_prior_order
ORDER BY days_since_prior_order;


-- Q6: first orders vs repeat orders
-- first: 206,209 orders, basket 10.08, reorder share 0
-- repeat: 3,139,874 orders, basket 10.11, reorder share 0.6287

WITH basket AS (
    SELECT order_id, COUNT(*) AS items, SUM(reordered) AS reordered_items
    FROM order_products
    GROUP BY order_id
)
SELECT o.is_first_order,
       COUNT(*) AS orders,
       ROUND(AVG(b.items), 2) AS avg_basket_size,
       ROUND(SUM(b.reordered_items) / SUM(b.items), 4) AS reorder_share
FROM orders o
JOIN basket b ON b.order_id = o.order_id
GROUP BY o.is_first_order;


-- helper tables for Q7 and Q8 (market basket)
-- a self-join on all 33.8M rows is too heavy for my laptop, so only the
-- 50 most popular products are used

DROP TABLE IF EXISTS top_products;

CREATE TABLE top_products AS
SELECT product_id, COUNT(*) AS orders
FROM order_products
GROUP BY product_id
ORDER BY orders DESC
LIMIT 50;

ALTER TABLE top_products ADD PRIMARY KEY (product_id);

-- only the order lines that have one of those 50 products

DROP TABLE IF EXISTS op_top;

CREATE TABLE op_top AS
SELECT op.order_id, op.product_id
FROM order_products op
JOIN top_products t ON t.product_id = op.product_id;

ALTER TABLE op_top ADD INDEX idx_order (order_id);

-- these two must match (5,595,295)

SELECT COUNT(*) FROM op_top;

SELECT SUM(orders) FROM top_products;

-- how often each pair of products shows up in the same order
-- a.product_id < b.product_id so every pair is counted once

DROP TABLE IF EXISTS pairs_top;

CREATE TABLE pairs_top AS
SELECT a.product_id AS pa, b.product_id AS pb, COUNT(*) AS together
FROM op_top a
JOIN op_top b ON a.order_id = b.order_id
             AND a.product_id < b.product_id
GROUP BY a.product_id, b.product_id;

SELECT COUNT(*) FROM pairs_top;   -- max 1,225 pairs (50 x 49 / 2)


-- Q7: top product pairs bought together (top 50 products only)
-- raw counts, so this mostly shows popular products, see Q8 for lift
-- bag of organic bananas + organic hass avocado 64,761
-- bag of organic bananas + organic strawberries 64,702

SELECT p1.product_name AS product_a,
       p2.product_name AS product_b,
       pt.together
FROM pairs_top pt
JOIN products p1 ON p1.product_id = pt.pa
JOIN products p2 ON p2.product_id = pt.pb
ORDER BY pt.together DESC
LIMIT 10;


-- Q8: product pairs ranked by lift (top 50 products)
-- lift = together * total orders / (orders of a * orders of b)
-- above 1 means the pair sells together more than chance
-- pairs with less than 5,000 together are skipped (my cut-off)
-- organic red onion + organic cilantro 9,069 / lift 5.87
-- limes + organic cilantro 18,572 / lift 5.80

SELECT p1.product_name AS product_a,
       p2.product_name AS product_b,
       pt.together,
       ROUND(pt.together * tot.n / (ta.orders * tb.orders), 2) AS lift
FROM pairs_top pt
JOIN top_products ta ON ta.product_id = pt.pa
JOIN top_products tb ON tb.product_id = pt.pb
JOIN products p1 ON p1.product_id = pt.pa
JOIN products p2 ON p2.product_id = pt.pb
CROSS JOIN (SELECT COUNT(*) AS n FROM orders) tot
WHERE pt.together >= 5000
ORDER BY lift DESC
LIMIT 10;