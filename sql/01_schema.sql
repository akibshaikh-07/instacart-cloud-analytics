-- schema for the instacart project (mysql 8)
-- data comes from the cleaned parquet files, not the raw csvs
 
CREATE DATABASE IF NOT EXISTS instacart;

USE instacart;
 
-- product catalog, aisle and department names already joined in
CREATE TABLE IF NOT EXISTS products (
  product_id INT NOT NULL,
  product_name VARCHAR(255) NOT NULL,
  aisle_id SMALLINT NOT NULL,
  department_id TINYINT NOT NULL,
  aisle VARCHAR(100) NOT NULL,
  department VARCHAR(50) NOT NULL,
  PRIMARY KEY (product_id)
);
 
-- one row per order (prior + train only, test orders were dropped)
CREATE TABLE IF NOT EXISTS orders (
  order_id INT NOT NULL,
  user_id INT NOT NULL,
  eval_set VARCHAR(10) NOT NULL,
  order_number SMALLINT NOT NULL,
  order_dow TINYINT NOT NULL,
  order_hour_of_day TINYINT NOT NULL,
  days_since_prior_order DECIMAL(4,1) NULL,
  is_first_order TINYINT NOT NULL,
  PRIMARY KEY (order_id)
);
 
-- items in each order (prior + train combined)
-- no primary key yet, it is added after the load in 03_indexes.sql
CREATE TABLE IF NOT EXISTS order_products (
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  add_to_cart_order SMALLINT NOT NULL,
  reordered TINYINT NOT NULL
);
 
SHOW TABLES;

