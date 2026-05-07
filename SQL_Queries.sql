CREATE DATABASE IF NOT EXISTS ecom_maang;
USE ecom_maang;

-- Customers
CREATE TABLE customers (
  customer_id VARCHAR(8) PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(120) UNIQUE,
  created_at DATETIME,
  country VARCHAR(50),
  timezone VARCHAR(50)
);

-- Suppliers
CREATE TABLE suppliers (
  supplier_id VARCHAR(8) PRIMARY KEY,
  name VARCHAR(120),
  rating DECIMAL(3,2), -- 0.00-5.00
  country VARCHAR(50)
);

-- Warehouses
CREATE TABLE warehouses (
  warehouse_id VARCHAR(8) PRIMARY KEY,
  name VARCHAR(80),
  country VARCHAR(50),
  city VARCHAR(80),
  capacity INT
);

-- Product categories (for recursive hierarchy)
CREATE TABLE categories (
  category_id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100),
  parent_id INT NULL
);
ALTER TABLE categories
ADD CONSTRAINT fk_parent
FOREIGN KEY (parent_id) REFERENCES categories(category_id);

-- SET FOREIGN_KEY_CHECKS = 0;

-- SET FOREIGN_KEY_CHECKS = 1;

-- Products
CREATE TABLE products (
  product_id VARCHAR(8) PRIMARY KEY,
  name VARCHAR(150),
  category_id INT,
  supplier_id VARCHAR(8),
  price_usd DECIMAL(10,2), -- base price in USD
  currency VARCHAR(5), -- listing currency
  created_at DATETIME,
  FOREIGN KEY (category_id) REFERENCES categories(category_id),
  FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);
Select c.category_id , c.name,
avg(p.price_usd) as avg_price,count(p.product_id) as product_count_by_category
from categories c
join products p on c.category_id = p.category_id
group by c.category_id,c.name
order by product_count_by_category;
-- Exchange rates (to convert from currency -> USD)
CREATE TABLE exchange_rates (
  currency VARCHAR(5) PRIMARY KEY,
  rate_to_usd DECIMAL(18,8), -- multiply amount * rate_to_usd -> USD
  last_updated DATE
);

-- Orders
CREATE TABLE orders (
  order_id VARCHAR(12) PRIMARY KEY,
  customer_id VARCHAR(8),
  order_datetime DATETIME,
  order_timezone VARCHAR(50),
  total_amount DECIMAL(12,2), -- in order currency
  currency VARCHAR(5),
  status VARCHAR(30), -- placed, shipped, delivered, cancelled, returned
  warehouse_id VARCHAR(8),
  shipping_delay_hours INT, -- actual delay
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
);

-- Order items (line-level)
CREATE TABLE order_items (
  order_item_id INT PRIMARY KEY AUTO_INCREMENT,
  order_id VARCHAR(12),
  product_id VARCHAR(8),
  quantity INT,
  unit_price DECIMAL(10,2) -- in order currency

);


--   FOREIGN KEY (order_id) REFERENCES orders(order_id),
--   FOREIGN KEY (product_id) REFERENCES products(product_id)
SET FOREIGN_KEY_CHECKS = 0;
truncate table order_items;
SET FOREIGN_KEY_CHECKS = 1;

-- Shipments (tracking events simplified)
CREATE TABLE shipments (
  shipment_id VARCHAR(12) PRIMARY KEY,
  order_id VARCHAR(12),
  shipped_at DATETIME,
  delivered_at DATETIME,
  status VARCHAR(30),
  carrier VARCHAR(80),
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);


SET FOREIGN_KEY_CHECKS = 0;
truncate table shipments;
-- Returns
CREATE TABLE returns (
  return_id VARCHAR(12) PRIMARY KEY,
  order_id VARCHAR(12),
  product_id VARCHAR(8),
  return_reason VARCHAR(255),
  return_datetime DATETIME,
  refund_amount DECIMAL(10,2),
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

SELECT 
  c.customer_id,
  c.name,
  COUNT(r.return_id) AS total_returns,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNT(r.return_id) / COUNT(DISTINCT o.order_id) AS return_rate_per_order
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN returns r ON o.order_id = r.order_id
GROUP BY c.customer_id, c.name
ORDER BY total_returns DESC
LIMIT 5;

 -- Total sales, total orders, avg order value by month and category (with category hierarchy)
 
WITH RECURSIVE category_hierarchy AS (
  SELECT category_id, name, parent_id
  FROM categories
  WHERE parent_id IS NULL
  
  UNION ALL
  
  SELECT c.category_id, c.name, c.parent_id
  FROM categories c
  INNER JOIN category_hierarchy ch ON c.parent_id = ch.category_id
)
SELECT * FROM category_hierarchy;
SELECT COUNT(*) FROM categories;


SELECT parent_id FROM categories
WHERE parent_id IS NOT NULL
AND parent_id NOT IN (SELECT category_id FROM categories);

SELECT c.category_id, c.name, c.parent_id, ch.category_id AS parent_cat_id, ch.name AS parent_cat_name
FROM categories c
LEFT JOIN categories ch ON c.parent_id = ch.category_id
LIMIT 20;
SELECT DISTINCT parent_id
FROM categories
WHERE parent_id IS NOT NULL;
SELECT parent_id
FROM categories
WHERE parent_id IS NOT NULL
AND parent_id NOT IN (SELECT category_id FROM categories);

UPDATE categories
SET parent_id = NULL
WHERE parent_id IS NOT NULL
AND parent_id NOT IN (SELECT category_id FROM categories);
UPDATE categories
SET parent_id = NULL
WHERE parent_id IS NOT NULL
AND parent_id NOT IN (
  SELECT category_id FROM (SELECT category_id FROM categories) AS temp_categories
);
WITH RECURSIVE category_hierarchy AS (
  SELECT category_id, name, parent_id, 0 AS level
  FROM categories
  WHERE parent_id IS NULL

  UNION ALL

  SELECT c.category_id, c.name, c.parent_id, level + 1
  FROM categories c
  INNER JOIN category_hierarchy ch ON c.parent_id = ch.category_id
)
SELECT * FROM category_hierarchy
ORDER BY level, category_id;
SELECT category_id, name, parent_id FROM categories WHERE parent_id IS NOT NULL LIMIT 10;
SELECT 
  COUNT(*) AS total_rows,
  SUM(CASE WHEN parent_id IS NULL THEN 1 ELSE 0 END) AS null_parent_count,
  SUM(CASE WHEN parent_id IS NOT NULL THEN 1 ELSE 0 END) AS non_null_parent_count
FROM categories;

 -- Total sales, total orders, avg order value by month and category (with category hierarchy)
WITH RECURSIVE category_hierarchy AS (
  SELECT category_id, name, parent_id, 0 AS level
  FROM categories
  WHERE parent_id IS NULL

  UNION ALL

  SELECT c.category_id, c.name, c.parent_id, level + 1
  FROM categories c
  INNER JOIN category_hierarchy ch ON c.parent_id = ch.category_id
)
SELECT * FROM category_hierarchy
ORDER BY level, category_id;



-- SELECT DISTINCT parent_id
-- FROM categories
-- WHERE parent_id NOT IN (SELECT category_id FROM categories);



-- UPDATE categories
-- SET parent_id = NULL
-- WHERE parent_id NOT IN (
--   SELECT category_id FROM (SELECT category_id FROM categories) AS temp
-- );

-- UPDATE categories SET parent_id = 6 WHERE category_id IN (7,8,9);
-- UPDATE categories SET parent_id = 7 WHERE category_id IN (10,11);


-- WITH RECURSIVE category_hierarchy AS (
--   SELECT category_id, name, parent_id, 0 AS level
--   FROM categories
--   WHERE parent_id IS NULL

--   UNION ALL

--   SELECT c.category_id, c.name, c.parent_id, ch.level + 1
--   FROM categories c
--   INNER JOIN category_hierarchy ch ON c.parent_id = ch.category_id
-- )
-- SELECT * FROM category_hierarchy
-- ORDER BY level, category_id;


-- UPDATE categories SET parent_id = 6 WHERE category_id IN (12, 13, 14);
-- UPDATE categories SET parent_id = 13 WHERE category_id IN (15, 16);
-- WITH RECURSIVE category_hierarchy AS (
--   SELECT category_id, name, parent_id, 0 AS level
--   FROM categories
--   WHERE parent_id IS NULL

--   UNION ALL

--   SELECT c.category_id, c.name, c.parent_id, ch.level + 1
--   FROM categories c
--   INNER JOIN category_hierarchy ch ON c.parent_id = ch.category_id
-- )
-- SELECT * FROM category_hierarchy
-- ORDER BY level, category_id;

-- UPDATE categories SET parent_id = 7 WHERE category_id IN (6, 17, 18);

-- UPDATE categories SET parent_id = 7 WHERE category_id IN (19,20);


-- SELECT category_id, parent_id FROM categories WHERE category_id = 7;
-- UPDATE categories SET parent_id = NULL WHERE category_id = 7;


-- Top 5 Customers by Total Spend (in USD)

SELECT 
  c.customer_id, 
  c.name, 
  SUM(oi.quantity * oi.unit_price * er.rate_to_usd) AS total_spent_usd
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN exchange_rates er ON o.currency = er.currency
GROUP BY c.customer_id, c.name
ORDER BY total_spent_usd DESC
LIMIT 5;

 
SELECT
  c.name,
  c.customer_id,
  SUM(oi.quantity * oi.unit_price * er.rate_to_usd) AS total_spend
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN exchange_rates er ON o.currency = er.currency
GROUP BY c.customer_id, c.name
ORDER BY total_spend DESC
LIMIT 5;


--  Average Shipping Delay per Warehouse

-- CREATE TABLE warehouses (
--   warehouse_id VARCHAR(8) PRIMARY KEY,
--   name VARCHAR(80),
--   country VARCHAR(50),
--   city VARCHAR(80),
--   capacity INT
-- );
-- CREATE TABLE shipments (
--   shipment_id VARCHAR(12) PRIMARY KEY,
--   order_id VARCHAR(12),
--   shipped_at DATETIME,
--   delivered_at DATETIME,
--   status VARCHAR(30),
--   carrier VARCHAR(80),
--   FOREIGN KEY (order_id) REFERENCES orders(order_id)
-- );

--  Average Shipping Delay per Warehouse
Select 
w.warehouse_id, w.name,
avg(o.shipping_delay_hours) as avg_shipping_delays_hours
from warehouses w
join orders o on w.warehouse_id = o.warehouse_id
group by w.warehouse_id,w.name
order by avg_shipping_delays_hours;







SELECT 
  w.warehouse_id, 
  w.name, 
  AVG(o.shipping_delay_hours) AS avg_shipping_delay_hours
FROM warehouses w
JOIN orders o ON w.warehouse_id = o.warehouse_id
GROUP BY w.warehouse_id, w.name
ORDER BY avg_shipping_delay_hours DESC;


--  Product-wise Sales Quantity and Revenue (in USD) for Last 3 Months
select p.product_id,p.name, sum(oi.quantity * oi.unit_price*er.rate_to_usd) as sales_Revenue
from products p
join order_items oi on p.product_id = oi.product_id
join orders o on oi.order_id = o.order_id
join exchange_rates er on o.currency = er.currency
WHERE o.order_datetime >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
group by product_id
order by sales_Revenue;









-- Customers with Most Returns and Their Return Rate
SELECT 
  c.customer_id,
  c.name,
  COUNT(r.return_id) AS total_returns,
  COUNT(DISTINCT o.order_id) AS total_orders,
  COUNT(r.return_id) / COUNT(DISTINCT o.order_id) AS return_rate_per_order
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN returns r ON o.order_id = r.order_id
GROUP BY c.customer_id, c.name
ORDER BY total_returns DESC
LIMIT 5;

--  Category-wise Product Count and Average Price
Select c.category_id , c.name,
avg(p.price_usd) as avg_price,count(p.product_id) as product_count_by_category
from categories c
join products p on c.category_id = p.category_id
group by c.category_id,c.name
order by product_count_by_category;

SELECT
  order_id,
  customer_id,
  order_datetime,
  total_amount,
  LAG(total_amount) OVER (PARTITION BY customer_id ORDER BY order_datetime) AS previous_order_amount
FROM orders
ORDER BY customer_id, order_datetime;


SELECT
  order_id,
  customer_id,
  order_datetime,
  total_amount,
  LAG(total_amount) OVER (PARTITION BY customer_id ORDER BY order_datetime) AS previous_order_amount,
  total_amount - LAG(total_amount) OVER (PARTITION BY customer_id ORDER BY order_datetime) AS amount_diff
FROM orders
ORDER BY customer_id, order_datetime;
