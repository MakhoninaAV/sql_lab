# Практическая работа №1
## Геопространственный анализ данных. Аналитика с использованием сложных типов данных

**Выполнила:** Махонина Анна, ЦИБ-241

**Выбранные задания:**
- Блок А. 5. Сезонность продуктов
- Блок Б. 6. Ближайший дилер
- Блок В. 15. Тэгирование

---

# Цель работы

Научиться применять продвинутые возможности PostgreSQL для анализа данных, выходящих за рамки стандартных чисел и строк. Освоить работу с временными рядами, геопространственными данными, массивами, JSON/JSONB структурами и полнотекстовым поиском.

---

# Задачи

- Использовать `DATE_TRUNC` и оконную функцию `ROW_NUMBER` для определения месяца с максимальной суммой продаж для каждого типа продукта.
- Применить расширения `cube` и `earthdistance` для вычисления расстояний и поиска ближайшего дилерского центра для каждого клиента из Нью-Йорка.
- Реализовать автоматическое добавление тега 'VIP' в массив-поле `tags` для клиентов с общей суммой покупок более 50000.

---

# Индивидуальные задания

## Задание 1. Сезонность продуктов

**Условие:**  
Для каждого типа продукта (`product_type`) определите месяц, в котором он продаётся лучше всего (максимальная сумма продаж). Выведите тип продукта, месяц (в формате ГГГГ-ММ) и максимальную сумму.

**SQL-код:**

```sql
WITH monthly_sales AS (
    SELECT 
        p.product_type,
        DATE_TRUNC('month', s.sales_transaction_date) AS month_date,
        SUM(s.sales_amount) AS total_sales
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY p.product_type, DATE_TRUNC('month', s.sales_transaction_date)
),
ranked AS (
    SELECT 
        product_type,
        month_date,
        total_sales,
        ROW_NUMBER() OVER (PARTITION BY product_type ORDER BY total_sales DESC) AS rn
    FROM monthly_sales
)
SELECT 
    product_type,
    TO_CHAR(month_date, 'YYYY-MM') AS best_month,
    total_sales AS max_sales_amount
FROM ranked
WHERE rn = 1
ORDER BY product_type;
```

**Скриншот результата:**  

[ВСТАВИТЬ СКРИНШОТ РЕЗУЛЬТАТА]

**Пояснение:**  
- `DATE_TRUNC('month', ...)` усекает дату до первого дня месяца, позволяя группировать продажи по месяцам.  
- Оконная функция `ROW_NUMBER()` с `PARTITION BY product_type` нумерует месяцы для каждого типа продукта по убыванию суммы продаж.  
- Ранг 1 соответствует месяцу с максимальной суммой.  
- `TO_CHAR` форматирует дату в читаемый вид ГГГГ-ММ.

---

## Задание 2. Ближайший дилер

**Условие:**  
Для каждого клиента из города 'New York City' найдите ближайший дилерский центр (`dealerships`) и расстояние до него. Выведите идентификатор клиента, имя, фамилию, идентификатор дилера, адрес, город дилера и расстояние в милях.

**SQL-код:**

```sql
WITH customer_location AS (
    SELECT 
        customer_id,
        first_name,
        last_name,
        point(longitude, latitude) AS customer_point
    FROM customers
    WHERE city = 'New York City'
),
dealer_distance AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        d.dealership_id,
        d.street_address,
        d.city AS dealer_city,
        (c.customer_point <@> point(d.longitude, d.latitude)) AS distance_miles,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id 
            ORDER BY c.customer_point <@> point(d.longitude, d.latitude)
        ) AS rn
    FROM customer_location c
    CROSS JOIN dealerships d
)
SELECT 
    customer_id,
    first_name,
    last_name,
    dealership_id,
    street_address AS dealer_address,
    dealer_city,
    ROUND(distance_miles::numeric, 2) AS distance_miles
FROM dealer_distance
WHERE rn = 1
ORDER BY distance_miles;
```

**Скриншот результата:**  

[ВСТАВИТЬ СКРИНШОТ РЕЗУЛЬТАТА]

**Пояснение:**  
- Расширения `cube` и `earthdistance` позволяют использовать оператор `<@>` для вычисления расстояния в милях между двумя географическими точками, заданными через конструкцию `point(longitude, latitude)`.  
- `CROSS JOIN` создаёт декартово произведение клиентов из Нью-Йорка и всех дилеров.  
- `ROW_NUMBER()` с `PARTITION BY customer_id` нумерует дилеров для каждого клиента по возрастанию расстояния.  
- Ранг 1 соответствует ближайшему дилеру.  
- `ROUND` округляет расстояние до двух знаков после запятой.

---

## Задание 3. Тэгирование

**Условие:**  
Добавьте к таблице `customers` текстовое поле-массив `tags`. Напишите запрос, который добавляет тег 'VIP' всем клиентам, совершившим покупки на сумму более 50000.

**SQL-код:**

```sql
ALTER TABLE customers ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

UPDATE customers c
SET tags = array_append(
    COALESCE(c.tags, '{}'),
    'VIP'
)
WHERE (
    SELECT COALESCE(SUM(s.sales_amount), 0)
    FROM sales s
    WHERE s.customer_id = c.customer_id
) > 50000;

SELECT 
    customer_id,
    first_name,
    last_name,
    tags
FROM customers
WHERE 'VIP' = ANY(tags)
ORDER BY customer_id;
```

**Скриншот результата:**  

[ВСТАВИТЬ СКРИНШОТ РЕЗУЛЬТАТА]

**Пояснение:**  
- `ALTER TABLE ADD COLUMN` добавляет новое поле-массив `tags` с типом `TEXT[]` и значением по умолчанию пустой массив.  
- `array_append` добавляет элемент в конец массива.  
- `COALESCE` обрабатывает случай, когда поле `tags` содержит NULL, подставляя пустой массив.  
- Подзапрос в `WHERE` суммирует все покупки клиента и выбирает тех, чья сумма превышает 50000.  
- `'VIP' = ANY(tags)` проверяет, содержит ли массив тег VIP, для выборочной проверки результата.

---

# Вывод

В ходе выполнения практической работы были реализованы три аналитических запроса с использованием сложных типов данных и специализированных расширений PostgreSQL.

Было выполнено:

- С использованием `DATE_TRUNC` и оконной функции `ROW_NUMBER` для каждого типа продукта определён месяц с максимальной суммой продаж.
- С применением расширений `cube` и `earthdistance` для каждого клиента из Нью-Йорка найден ближайший дилерский центр и расстояние до него.
- С помощью типа `TEXT[]` и функций работы с массивами (`array_append`) реализовано автоматическое добавление тега 'VIP' клиентам с суммой покупок более 50000.

Все запросы оформлены в файле [practical_work_01.sql](practical_work_01.sql).
