-- load the csv files into mysql
-- csvs are made by scripts/parquet_to_csv.py
-- change the paths below to wherever your csv files are (use / even on windows)
--
-- one-time setup:
--   workbench > edit connection > advanced > others > OPT_LOCAL_INFILE=1
--   workbench > preferences > sql editor > read timeout = 3600
--   (the default 30 sec kills the big load)

USE instacart;

-- local_infile is off by default in MySQL 8 for security, so it is turned on
-- only for the bulk load (turn it off again after loading).

SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';   -- should say ON


-- products
-- ESCAPED BY '' turns off backslash handling. with the default only 49,355
-- rows loaded instead of 49,688

LOAD DATA LOCAL INFILE 'C:/instacart-sql/data/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n';

SELECT COUNT(*) FROM products;        -- 49,688
SHOW COUNT(*) WARNINGS;               -- 0


-- orders
-- no ESCAPED BY here, the csv writes the missing gap as \N and mysql only
-- reads that as NULL when escapes are on

LOAD DATA LOCAL INFILE 'C:/instacart-sql/data/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

SELECT COUNT(*) FROM orders;                                       -- 3,346,083
SELECT COUNT(*) FROM orders WHERE days_since_prior_order IS NULL;  -- 206,209 (first orders)
SELECT eval_set, COUNT(*) FROM orders GROUP BY eval_set;           -- train 131,209 / prior 3,214,874
SHOW COUNT(*) WARNINGS;                                            -- 0


-- order_products (biggest one, ~600 MB csv, takes a few minutes)
-- these settings make the bulk load faster, reset after the load

SET autocommit = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;

LOAD DATA LOCAL INFILE 'C:/instacart-sql/data/order_products.csv'
INTO TABLE order_products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';

COMMIT;
SET autocommit = 1;
SET unique_checks = 1;
SET foreign_key_checks = 1;

SELECT COUNT(*) FROM order_products;         -- 33,819,106
SELECT SUM(reordered) FROM order_products;   -- 19,955,360, same as the pandas department summary
SHOW COUNT(*) WARNINGS;                      -- 0