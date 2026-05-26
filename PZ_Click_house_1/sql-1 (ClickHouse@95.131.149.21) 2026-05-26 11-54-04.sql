SELECT version();

-- Задание 1. Создаём таблицу sales_13
CREATE TABLE sales_13 (
    sale_id        UInt64,
    sale_timestamp DateTime64(3),
    product_id     UInt32,
    category       LowCardinality(String),
    customer_id    UInt64,
    region         LowCardinality(String),
    quantity       UInt16,
    unit_price     Decimal64(2),
    discount_pct   Float32,
    is_online      UInt8,
    ip_address     IPv4
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(sale_timestamp)
ORDER BY (sale_timestamp, customer_id, product_id);

-- Вставляем данные за 3 месяца (Октябрь, Ноябрь, Декабрь 2024)
-- Всего 120 строк
INSERT INTO sales_13 
(sale_id, sale_timestamp, product_id, category, customer_id, region, quantity, unit_price, discount_pct, is_online, ip_address)
SELECT
    number + 13001 AS sale_id,
    toDateTime64('2024-10-01 00:00:00', 3) + INTERVAL (number % 90) DAY + INTERVAL (number % 24) HOUR,
    130 + (number % 20) AS product_id,
    CASE (number % 5)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Books'
        WHEN 3 THEN 'Home'
        ELSE 'Sports'
    END AS category,
    1300 + (number % 100) AS customer_id,
    CASE (number % 4)
        WHEN 0 THEN 'North'
        WHEN 1 THEN 'South'
        WHEN 2 THEN 'East'
        ELSE 'West'
    END AS region,
    (number % 18) + 1 AS quantity,      -- max quantity = 18
    23.00 + (number % 501) AS unit_price, -- от 23.00
    (number % 100) / 100.0 AS discount_pct,
    (number % 2) AS is_online,
    IPv4StringToNum(concat(toString(number % 256), '.', toString((number + 64) % 256), '.', toString((number + 128) % 256), '.', toString(number % 256))) AS ip_address
FROM numbers(120);

-- Задание 2. Аналитические запросы

-- 2.1 Общая выручка по категориям
SELECT
    category,
    round(SUM(quantity * unit_price * (1 - discount_pct)), 2) AS total_revenue
FROM sales_13
GROUP BY category
ORDER BY total_revenue DESC;

-- 2.2 Топ-3 клиента по количеству покупок
SELECT
    customer_id,
    COUNT(*) AS purchase_count,
    SUM(quantity) AS total_quantity
FROM sales_13
GROUP BY customer_id
ORDER BY purchase_count DESC
LIMIT 3;

-- 2.3 Средний чек по месяцам
SELECT
    toYYYYMM(sale_timestamp) AS month,
    round(AVG(quantity * unit_price), 2) AS avg_check
FROM sales_13
GROUP BY month
ORDER BY month;

-- 2.4 Фильтрация по партиции (октябрь)
SELECT *
FROM sales_13
WHERE sale_timestamp >= '2024-10-01' AND sale_timestamp < '2024-11-01';

-- Задание 3. ReplacingMergeTree — справочник товаров (8 товаров)
CREATE TABLE products_13 (
    product_id    UInt32,
    product_name  String,
    category      LowCardinality(String),
    supplier      String,
    base_price    Decimal64(2),
    weight_kg     Float32,
    is_available  UInt8,
    updated_at    DateTime,
    version       UInt64
)
ENGINE = ReplacingMergeTree(version)
ORDER BY (product_id);

-- Вставляем 8 товаров (13 % 10 + 5 = 3 + 5 = 8) с version = 1
INSERT INTO products_13 VALUES
(130, 'Ноутбук', 'Electronics', 'TechCorp', 999.99, 2.5, 1, now(), 1),
(131, 'Футболка', 'Clothing', 'FashionInc', 29.99, 0.2, 1, now(), 1),
(132, 'Книга SQL', 'Books', 'PubHouse', 49.99, 0.5, 1, now(), 1),
(133, 'Кофемашина', 'Home', 'HomeGoods', 79.99, 3.0, 1, now(), 1),
(134, 'Мяч', 'Sports', 'SportCo', 24.99, 0.45, 1, now(), 1),
(135, 'Смартфон', 'Electronics', 'TechCorp', 699.99, 0.18, 1, now(), 1),
(136, 'Джинсы', 'Clothing', 'FashionInc', 59.99, 0.7, 1, now(), 1),
(137, 'Тетрадь', 'Books', 'PubHouse', 12.99, 0.3, 1, now(), 1);

-- Для 3 товаров вставляем обновлённые записи с version = 2
INSERT INTO products_13 VALUES
(130, 'Ноутбук Pro', 'Electronics', 'TechCorp', 899.99, 2.5, 0, now(), 2),
(133, 'Кофемашина Lux', 'Home', 'HomeGoods', 69.99, 3.0, 0, now(), 2),
(135, 'Смартфон Pro', 'Electronics', 'TechCorp', 649.99, 0.18, 1, now(), 2);

-- Проверяем — видны обе версии
SELECT * FROM products_13;

-- Выполняем OPTIMIZE
OPTIMIZE TABLE products_13 FINAL;

-- Проверяем — осталась только версия 2
SELECT * FROM products_13 FINAL;

-- Задание 4. SummingMergeTree (6 дней, 3 кампании)
CREATE TABLE daily_metrics_13 (
    metric_date    Date,
    campaign_id    UInt32,
    channel        LowCardinality(String),
    impressions    UInt64,
    clicks         UInt64,
    conversions    UInt32,
    spend_cents    UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (metric_date, campaign_id, channel);

-- Вставляем данные за 6 дней для 3 кампаний, по 2 канала
INSERT INTO daily_metrics_13
SELECT
    toDate('2024-10-01') + INTERVAL (number % 6) DAY AS metric_date,
    131 + (number % 3) AS campaign_id,
    CASE (number % 2) WHEN 0 THEN 'Email' ELSE 'Social' END AS channel,
    1000 + (number % 5000) AS impressions,
    50 + (number % 300) AS clicks,
    1 + (number % 20) AS conversions,
    5000 + (number % 10000) AS spend_cents
FROM numbers(36);

-- Вставляем повторные строки
INSERT INTO daily_metrics_13
SELECT
    toDate('2024-10-01') + INTERVAL (number % 6) DAY AS metric_date,
    131 + (number % 3) AS campaign_id,
    CASE (number % 2) WHEN 0 THEN 'Email' ELSE 'Social' END AS channel,
    500 + (number % 1000) AS impressions,
    10 + (number % 100) AS clicks,
    1 + (number % 10) AS conversions,
    1000 + (number % 5000) AS spend_cents
FROM numbers(18);

-- OPTIMIZE
OPTIMIZE TABLE daily_metrics_13 FINAL;

-- CTR по каналам
SELECT
    channel,
    SUM(clicks) AS total_clicks,
    SUM(impressions) AS total_impressions,
    round(SUM(clicks) / SUM(impressions), 4) AS CTR
FROM daily_metrics_13
GROUP BY channel;

-- Задание 5. Комплексный анализ

-- 5.1 Проверка партиций
SELECT 
    toYYYYMM(sale_timestamp) AS partition,
    COUNT(*) AS total_rows
FROM sales_13
GROUP BY partition
ORDER BY partition;

-- 5.2 JOIN
SELECT
    p.product_name,
    p.category,
    round(sum(s.quantity * s.unit_price * (1 - s.discount_pct)), 2) AS revenue
FROM sales_13 AS s
INNER JOIN products_13 AS p
    ON s.product_id = p.product_id
GROUP BY p.product_name, p.category
ORDER BY revenue DESC
LIMIT 5;

-- 5.3 Типы данных
DESCRIBE TABLE sales_13;
DESCRIBE TABLE products_13;
DESCRIBE TABLE daily_metrics_13;

-- 5.4 Запрос с массивом
CREATE TABLE tags_13 (
    item_id  UInt32,
    item_name String,
    tags     Array(String)
) ENGINE = MergeTree()
ORDER BY item_id;

INSERT INTO tags_13 VALUES
(1, 'Item A', ['sale', 'popular', 'new']),
(2, 'Item B', ['premium', 'limited']),
(3, 'Item C', ['sale', 'clearance']);

SELECT
    arrayJoin(tags) AS tag,
    count() AS items_count
FROM tags_13
GROUP BY tag
ORDER BY items_count DESC;

-- 5.5 Контрольная сумма
SELECT 'sales' AS tbl, count() AS rows, sum(quantity) AS check_sum FROM db_13.sales_13
UNION ALL
SELECT 'products', count(), sum(toUInt64(product_id)) FROM db_13.products_13 FINAL
UNION ALL
SELECT 'metrics', count(), sum(clicks) FROM daily_metrics_13;