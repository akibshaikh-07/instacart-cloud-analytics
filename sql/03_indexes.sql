-- indexes and memory setting, run after the load
-- run each ALTER only once. running it again gives error 1068 / 1061,
-- which just means the index is already there (check with SHOW INDEX)

USE instacart;

-- pandas showed no duplicate (order_id, product_id) pairs, so this works as a primary key
ALTER TABLE order_products
  ADD PRIMARY KEY (order_id, product_id),
  ADD INDEX idx_product (product_id);

ALTER TABLE orders
  ADD INDEX idx_user (user_id);

SHOW INDEX FROM order_products;
SHOW INDEX FROM orders;


-- innodb buffer pool was 128 MB by default, way too small for order_products
-- set it to 2 GB (laptop has 8 GB). PERSIST keeps it after a restart
SELECT @@innodb_buffer_pool_size / 1024 / 1024 AS buffer_pool_mb;   -- 128 
SET PERSIST innodb_buffer_pool_size = 2147483648;
SELECT @@innodb_buffer_pool_size / 1024 / 1024 AS buffer_pool_mb;   -- 2048