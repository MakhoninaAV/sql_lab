# Практическое занятие №1. Основы ClickHouse: установка, типы данных, движки таблиц

**Вариант:** 13  
**Студент:** Махонина А. В.  
**Группа:** ЦИБ-241

---

## Цель работы

Получить практические навыки работы с колоночной СУБД ClickHouse: подключиться к облачному серверу, освоить создание баз данных и таблиц с правильным выбором типов данных и движков семейства MergeTree.

---

## Задание 1. Создание базы данных и таблицы продаж

### SQL-запрос на создание таблицы `sales_13`

```sql
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
```

### Вставка данных (120 строк за октябрь, ноябрь, декабрь 2024)

```sql
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
    (number % 18) + 1 AS quantity,
    23.00 + (number % 501) AS unit_price,
    (number % 100) / 100.0 AS discount_pct,
    (number % 2) AS is_online,
    IPv4StringToNum(concat(toString(number % 256), '.', toString((number + 64) % 256), '.', toString((number + 128) % 256), '.', toString(number % 256))) AS ip_address
FROM numbers(120);
```

### Проверка количества строк

```sql
SELECT count() FROM sales_13;
```

## Задание 2. Аналитические запросы

### 2.1 Общая выручка по категориям

```sql
SELECT
    category,
    round(SUM(quantity * unit_price * (1 - discount_pct)), 2) AS total_revenue
FROM sales_13
GROUP BY category
ORDER BY total_revenue DESC;
```

**Результат:**

[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_2.1.png)


### 2.2 Топ-3 клиента по количеству покупок

```sql
SELECT
    customer_id,
    COUNT(*) AS purchase_count,
    SUM(quantity) AS total_quantity
FROM sales_13
GROUP BY customer_id
ORDER BY purchase_count DESC
LIMIT 3;
```

**Результат:**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_2.2.png)


### 2.3 Средний чек по месяцам

```sql
SELECT
    toYYYYMM(sale_timestamp) AS month,
    round(AVG(quantity * unit_price), 2) AS avg_check
FROM sales_13
GROUP BY month
ORDER BY month;
```

**Результат:**

[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_2.3.png)

### 2.4 Фильтрация по партиции (октябрь 2024)

```sql
SELECT *
FROM sales_13
WHERE sale_timestamp >= '2024-10-01' AND sale_timestamp < '2024-11-01';
```

**Результат (первые 5 строк):**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_2.4.png)

## Задание 3. ReplacingMergeTree — справочник товаров

### Создание таблицы `products_13`

```sql
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
```

### Вставка 8 товаров (version = 1)

```sql
INSERT INTO products_13 VALUES
(130, 'Ноутбук', 'Electronics', 'TechCorp', 999.99, 2.5, 1, now(), 1),
(131, 'Футболка', 'Clothing', 'FashionInc', 29.99, 0.2, 1, now(), 1),
(132, 'Книга SQL', 'Books', 'PubHouse', 49.99, 0.5, 1, now(), 1),
(133, 'Кофемашина', 'Home', 'HomeGoods', 79.99, 3.0, 1, now(), 1),
(134, 'Мяч', 'Sports', 'SportCo', 24.99, 0.45, 1, now(), 1),
(135, 'Смартфон', 'Electronics', 'TechCorp', 699.99, 0.18, 1, now(), 1),
(136, 'Джинсы', 'Clothing', 'FashionInc', 59.99, 0.7, 1, now(), 1),
(137, 'Тетрадь', 'Books', 'PubHouse', 12.99, 0.3, 1, now(), 1);
```

### Обновление 3 товаров (version = 2)

```sql
INSERT INTO products_13 VALUES
(130, 'Ноутбук Pro', 'Electronics', 'TechCorp', 899.99, 2.5, 0, now(), 2),
(133, 'Кофемашина Lux', 'Home', 'HomeGoods', 69.99, 3.0, 0, now(), 2),
(135, 'Смартфон Pro', 'Electronics', 'TechCorp', 649.99, 0.18, 1, now(), 2);
```

### Проверка — видны обе версии (до OPTIMIZE)

```sql
SELECT * FROM products_13;
```

**Результат:**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_3.1%20до%20оптимайз.png)


### Принудительное слияние

```sql
OPTIMIZE TABLE products_13 FINAL;
```

### Проверка — осталась только версия 2

```sql
SELECT * FROM products_13 FINAL;
```

**Результат:**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_3.2%20после%20оптимайз.png)


## Задание 4. SummingMergeTree — агрегация метрик

### Создание таблицы `daily_metrics_13`

```sql
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
```

### Вставка данных за 6 дней, 3 кампании, 2 канала

```sql
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
```

### Вставка повторных строк (для проверки суммирования)

```sql
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
```

### Принудительное слияние

```sql
OPTIMIZE TABLE daily_metrics_13 FINAL;
```

### CTR (Click-Through Rate) по каналам

```sql
SELECT
    channel,
    SUM(clicks) AS total_clicks,
    SUM(impressions) AS total_impressions,
    round(SUM(clicks) / SUM(impressions), 4) AS CTR
FROM daily_metrics_13
GROUP BY channel;
```

**Результат:**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_4.png)

## Задание 5. Комплексный анализ и самопроверка

### 5.1 Проверка партиций таблицы `sales_13`

```sql
SELECT 
    toYYYYMM(sale_timestamp) AS partition,
    COUNT(*) AS total_rows
FROM sales_13
GROUP BY partition
ORDER BY partition;
```

**Результат:**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_5.1.png)


### 5.2 JOIN между `sales_13` и `products_13` (топ-5 товаров по выручке)

```sql
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
```

**Результат:**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_5.2.png)


### 5.3 Типы данных таблиц

#### DESCRIBE TABLE sales_13
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_5.3.png)


#### DESCRIBE TABLE products_13
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_5.4.png)

#### DESCRIBE TABLE daily_metrics_13
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_5.5.png)

---

### 5.4 Запрос с массивом (Array(String))

```sql
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
```

**Результат:**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_5.6.png)


### 5.5 Контрольная сумма

```sql
SELECT 'sales' AS tbl, count() AS rows, sum(quantity) AS check_sum FROM db_13.sales_13
UNION ALL
SELECT 'products', count(), sum(toUInt64(product_id)) FROM db_13.products_13 FINAL
UNION ALL
SELECT 'metrics', count(), sum(clicks) FROM daily_metrics_13;
```

**Результат:**
[СКРИНШОТ](https://github.com/MakhoninaAV/sql_files/blob/main/pz_5.7.png)

---

## Ответы на контрольные вопросы

### 1. Почему LowCardinality(String) эффективнее обычного String для столбца category?

`LowCardinality(String)` хранит уникальные значения отдельно в словаре и заменяет их на числовые идентификаторы. Это значительно уменьшает объём данных на диске и ускоряет выполнение запросов за счёт лучшего сжатия. Особенно эффективно для столбцов с небольшим количеством уникальных значений, таких как категории товаров.

### 2. В чём разница между ORDER BY и PRIMARY KEY в ClickHouse?

- **ORDER BY** определяет физический порядок сортировки данных на диске. Данные хранятся именно в этом порядке.
- **PRIMARY KEY** — это подмножество ORDER BY, которое задаёт разреженный индекс для ускорения поиска. Если PRIMARY KEY не указан явно, он совпадает с ORDER BY.

### 3. Когда следует использовать ReplacingMergeTree вместо MergeTree?

`ReplacingMergeTree` следует использовать, когда нужно хранить только последнюю актуальную версию строки для каждого ключа сортировки. Например, в справочниках, профилях пользователей, статусах заказов. Для хранения неизменяемых событий (логов, транзакций) используется обычный `MergeTree`.

### 4. Почему SummingMergeTree не заменяет GROUP BY в аналитических запросах?

`SummingMergeTree` суммирует числовые значения только в момент фонового слияния кусков данных и не гарантирует полную агрегацию всех строк таблицы в реальном времени. Запрос с `GROUP BY` всё равно необходим для получения точных и актуальных результатов.

### 5. Что произойдёт, если не выполнить OPTIMIZE TABLE FINAL для ReplacingMergeTree?

Если не выполнить `OPTIMIZE TABLE FINAL`, в таблице могут оставаться несколько версий одной строки в разных кусках данных. Запрос `SELECT` может показать все эти версии. Фоновое слияние произойдёт автоматически, но когда именно — неизвестно, поэтому без принудительного слияния результаты могут быть некорректными.

---

## Вывод

В ходе выполнения практической работы были получены следующие результаты:

1. Создана база данных `db_13` и таблица продаж `sales_13` с партиционированием по месяцам.
2. Выполнены аналитические запросы для расчёта выручки, среднего чека и определения топ-клиентов.
3. Освоена работа с движком `ReplacingMergeTree` для хранения актуальных версий товаров.
4. Изучен движок `SummingMergeTree` для автоматической агрегации метрик.
5. Выполнены комплексные проверки: партиционирование, JOIN, контрольная сумма.
6. Закреплено понимание различий между движками семейства MergeTree.

Все задания выполнены в полном объёме, полученные результаты соответствуют ожидаемым.
```


Или просто перетащите файл с изображением в редактор GitHub — он сам создаст ссылку.

---

Если нужна помощь с конкретными скриншотами — пишите!
