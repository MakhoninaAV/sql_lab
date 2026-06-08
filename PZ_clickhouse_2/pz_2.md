
# Практическое занятие №2. Анализ данных в ClickHouse

**Вариант:** 13  
**Студент:** Махонина Анна  
**Группа:** ЦИБ-241

---

## Цель работы

Углубленное изучение аналитических возможностей ClickHouse на примере реального набора данных о поездках такси Нью-Йорка (более 1.9 млн записей).

---

## Задание 1. Создание таблицы `trips`

```sql
CREATE TABLE trips
(
    `trip_id` UInt32,
    `vendor_id` Enum8('1' = 1, '2' = 2, '3' = 3, '4' = 4, 'CMT' = 5, 'VTS' = 6, 'DDS' = 7, 'B02512' = 10, 'B02598' = 11, 'B02617' = 12, 'B02682' = 13, 'B02764' = 14, '' = 15),
    `pickup_date` Date,
    `pickup_datetime` DateTime,
    `dropoff_date` Date,
    `dropoff_datetime` DateTime,
    `store_and_fwd_flag` UInt8,
    `rate_code_id` UInt8,
    `pickup_longitude` Float64,
    `pickup_latitude` Float64,
    `dropoff_longitude` Float64,
    `dropoff_latitude` Float64,
    `passenger_count` UInt8,
    `trip_distance` Float64,
    `fare_amount` Float32,
    `extra` Float32,
    `mta_tax` Float32,
    `tip_amount` Float32,
    `tolls_amount` Float32,
    `ehail_fee` Float32,
    `improvement_surcharge` Float32,
    `total_amount` Float32,
    `payment_type` Enum8('UNK' = 0, 'CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4),
    `trip_type` UInt8,
    `pickup` FixedString(25),
    `dropoff` FixedString(25),
    `cab_type` Enum8('yellow' = 1, 'green' = 2, 'uber' = 3),
    `pickup_nyct2010_gid` Int8,
    `pickup_ctlabel` Float32,
    `pickup_borocode` Int8,
    `pickup_ct2010` String,
    `pickup_boroct2010` String,
    `pickup_cdeligibil` String,
    `pickup_ntacode` FixedString(4),
    `pickup_ntaname` String,
    `pickup_puma` UInt16,
    `dropoff_nyct2010_gid` UInt8,
    `dropoff_ctlabel` Float32,
    `dropoff_borocode` UInt8,
    `dropoff_ct2010` String,
    `dropoff_boroct2010` String,
    `dropoff_cdeligibil` String,
    `dropoff_ntacode` FixedString(4),
    `dropoff_ntaname` String,
    `dropoff_puma` UInt16
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(pickup_date)
ORDER BY pickup_datetime;
```

---

## Задание 2. Загрузка данных из S3

```sql
INSERT INTO trips
SELECT * FROM s3(
    'https://datasets-documentation.s3.eu-west-3.amazonaws.com/nyc-taxi/trips_{1..2}.gz',
    'TabSeparatedWithNames', "
    `trip_id` UInt32,
    `vendor_id` Enum8('1' = 1, '2' = 2, '3' = 3, '4' = 4, 'CMT' = 5, 'VTS' = 6, 'DDS' = 7, 'B02512' = 10, 'B02598' = 11, 'B02617' = 12, 'B02682' = 13, 'B02764' = 14, '' = 15),
    `pickup_date` Date,
    `pickup_datetime` DateTime,
    `dropoff_date` Date,
    `dropoff_datetime` DateTime,
    `store_and_fwd_flag` UInt8,
    `rate_code_id` UInt8,
    `pickup_longitude` Float64,
    `pickup_latitude` Float64,
    `dropoff_longitude` Float64,
    `dropoff_latitude` Float64,
    `passenger_count` UInt8,
    `trip_distance` Float64,
    `fare_amount` Float32,
    `extra` Float32,
    `mta_tax` Float32,
    `tip_amount` Float32,
    `tolls_amount` Float32,
    `ehail_fee` Float32,
    `improvement_surcharge` Float32,
    `total_amount` Float32,
    `payment_type` Enum8('UNK' = 0, 'CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4),
    `trip_type` UInt8,
    `pickup` FixedString(25),
    `dropoff` FixedString(25),
    `cab_type` Enum8('yellow' = 1, 'green' = 2, 'uber' = 3),
    `pickup_nyct2010_gid` Int8,
    `pickup_ctlabel` Float32,
    `pickup_borocode` Int8,
    `pickup_ct2010` String,
    `pickup_boroct2010` String,
    `pickup_cdeligibil` String,
    `pickup_ntacode` FixedString(4),
    `pickup_ntaname` String,
    `pickup_puma` UInt16,
    `dropoff_nyct2010_gid` UInt8,
    `dropoff_ctlabel` Float32,
    `dropoff_borocode` UInt8,
    `dropoff_ct2010` String,
    `dropoff_boroct2010` String,
    `dropoff_cdeligibil` String,
    `dropoff_ntacode` FixedString(4),
    `dropoff_ntaname` String,
    `dropoff_puma` UInt16
") SETTINGS input_format_try_infer_datetimes = 0;
```

---

## Задание 3. Проверка вставки

```sql
SELECT count() FROM trips;
```

**Результат:**

[click2.1.png](https://github.com/MakhoninaAV/sql_files/blob/main/click2.1.png?raw=true)

В таблицу загружено **1 999 657** строк.

---

## Задание 4. Аналитические запросы

### 4.1 Средняя сумма чаевых

```sql
SELECT round(avg(tip_amount), 2) FROM trips;
```

**Результат:**

![avg(tip_amount)](https://github.com/MakhoninaAV/sql_files/blob/main/click2.2.png?raw=true)

Средняя сумма чаевых составляет **1.68**.

---

### 4.2 Средняя стоимость поездки в зависимости от количества пассажиров

```sql
SELECT
    passenger_count,
    ceil(avg(total_amount), 2) AS average_total_amount
FROM trips
GROUP BY passenger_count
ORDER BY passenger_count;
```

**Результат:**

![passenger_count](https://github.com/MakhoninaAV/sql_files/blob/main/click2.3.png?raw=true)

| passenger_count | average_total_amount |
|----------------|----------------------|
| 0 | 22.69 |
| 1 | 15.97 |
| 2 | 17.15 |
| 3 | 16.76 |
| 4 | 17.33 |
| 5 | 16.35 |
| 6 | 16.04 |
| 7 | 59.80 |
| 8 | 36.41 |
| 9 | 9.81 |

---

### 4.3 Ежедневное число посадок такси по районам

```sql
SELECT
    pickup_date,
    pickup_ntaname,
    COUNT() AS number_of_trips
FROM trips
WHERE pickup_ntaname != ''
GROUP BY pickup_date, pickup_ntaname
ORDER BY pickup_date ASC
LIMIT 22;
```

**Результат:**

![daily_trips](https://github.com/MakhoninaAV/sql_files/blob/main/click2.4.png?raw=true)

---

### 4.4 Продолжительность поездки в минутах и группировка

```sql
SELECT
    avg(tip_amount) AS avg_tip,
    avg(fare_amount) AS avg_fare,
    avg(passenger_count) AS avg_passenger,
    count() AS count,
    truncate(date_diff('second', pickup_datetime, dropoff_datetime) / 60) AS trip_minutes
FROM trips
WHERE date_diff('second', pickup_datetime, dropoff_datetime) / 60 > 0
GROUP BY trip_minutes
ORDER BY trip_minutes DESC
LIMIT 20;
```

**Результат:**

![trip_minutes](https://github.com/MakhoninaAV/sql_files/blob/main/click2.5.png?raw=true)

---

### 4.5 Количество посадок такси в каждом районе с разбивкой по часам суток

```sql
SELECT
    pickup_ntaname,
    toHour(pickup_datetime) AS pickup_hour,
    COUNT() AS pickups
FROM trips
WHERE pickup_ntaname != ''
GROUP BY pickup_ntaname, pickup_hour
ORDER BY pickup_ntaname, pickup_hour
LIMIT 12;
```

**Результат:**

![pickups_by_hour](https://github.com/MakhoninaAV/sql_files/blob/main/click2.6.png?raw=true)

---

### 4.6 Поездки в аэропорты (LGA или JFK)

```sql
SELECT
    pickup_datetime,
    dropoff_datetime,
    total_amount,
    pickup_nyct2010_gid,
    dropoff_nyct2010_gid,
    CASE
        WHEN dropoff_nyct2010_gid = 138 THEN 'LGA'
        WHEN dropoff_nyct2010_gid = 132 THEN 'JFK'
    END AS airport_code,
    EXTRACT(YEAR FROM pickup_datetime) AS year,
    EXTRACT(DAY FROM pickup_datetime) AS day,
    EXTRACT(HOUR FROM pickup_datetime) AS hour
FROM trips
WHERE dropoff_nyct2010_gid IN (132, 138)
ORDER BY pickup_datetime
LIMIT 12;
```

**Результат:**

![airport_trips](https://github.com/MakhoninaAV/sql_files/blob/main/click2.7.png?raw=true)

---

## Задание 5. Работа со словарями

### 5.1 Создание словаря

```sql
CREATE DICTIONARY taxi_zone_dictionary
(
    `LocationID` UInt16 DEFAULT 0,
    `Borough` String,
    `Zone` String,
    `service_zone` String
)
PRIMARY KEY LocationID
SOURCE(HTTP(URL 'https://datasets-documentation.s3.eu-west-3.amazonaws.com/nyc-taxi/taxi_zone_lookup.csv' FORMAT 'CSVWithNames'))
LIFETIME(MIN 0 MAX 0)
LAYOUT(HASHED_ARRAY());
```

**Результат:**

![create_dictionary](https://github.com/MakhoninaAV/sql_files/blob/main/click2.8.png?raw=true)

---

### 5.2 Проверка работы словаря

```sql
SELECT * FROM taxi_zone_dictionary LIMIT 10;
```

**Результат:**

![dictionary_content](https://github.com/MakhoninaAV/sql_files/blob/main/click2.9.png?raw=true)

---

### 5.3 Получение района по LocationID

```sql
SELECT Borough, Zone FROM taxi_zone_dictionary WHERE LocationID = 132;
```

**Результат:**

![location_132](https://github.com/MakhoninaAV/sql_files/blob/main/click2.10.png?raw=true)

| Borough | Zone |
|---------|------|
| Queens | JFK Airport |

```sql
SELECT Borough, Zone FROM taxi_zone_dictionary WHERE LocationID = 138;
```

**Результат:**

| Borough | Zone |
|---------|------|
| Queens | LaGuardia Airport |

---

### 5.4 Проверка наличия ключа в словаре

```sql
SELECT COUNT(*) AS exists FROM taxi_zone_dictionary WHERE LocationID = 132;
```

**Результат:** 1

```sql
SELECT COUNT(*) AS exists FROM taxi_zone_dictionary WHERE LocationID = 4567;
```

**Результат:** 0

![key_exists](https://github.com/MakhoninaAV/sql_files/blob/main/click2.12.png?raw=true)

---

### 5.5 Анализ поездок в аэропорты с названиями районов

```sql
SELECT
    count(1) AS total,
    COALESCE(tz.Borough, 'Unknown') AS borough_name
FROM trips AS t
LEFT JOIN taxi_zone_dictionary AS tz ON toUInt64(t.pickup_nyct2010_gid) = tz.LocationID
WHERE t.dropoff_nyct2010_gid IN (132, 138)
GROUP BY borough_name
ORDER BY total DESC;
```

**Результат:**

![airport_analysis](https://github.com/MakhoninaAV/sql_files/blob/main/click2.13.png?raw=true)

| total | borough_name |
|-------|--------------|
| 23683 | |
| 7053 | Manhattan |
| 6828 | Brooklyn |
| 4458 | Queens |
| 2670 | Bronx |
| 554 | Staten Island |
| 53 | EWR |

---

## Задание 6. Выполнение соединений (JOIN)

### 6.1 Простой JOIN

```sql
SELECT
    count(1) AS total,
    Borough
FROM trips
JOIN taxi_zone_dictionary ON toUInt64(trips.pickup_nyct2010_gid) = taxi_zone_dictionary.LocationID
WHERE dropoff_nyct2010_gid IN (132, 138)
GROUP BY Borough
ORDER BY total DESC;
```

**Результат:**

![simple_join](https://github.com/MakhoninaAV/sql_files/blob/main/click2.14.png?raw=true)

| total | Borough |
|-------|---------|
| 7053 | Manhattan |
| 6828 | Brooklyn |
| 4458 | Queens |
| 2670 | Bronx |
| 554 | Staten Island |
| 53 | EWR |

---

### 6.2 JOIN для 1000 поездок с наибольшими чаевыми

```sql
SELECT
    trips.trip_id,
    trips.pickup_datetime,
    trips.dropoff_datetime,
    trips.total_amount,
    trips.tip_amount,
    taxi_zone_dictionary.Zone AS dropoff_zone,
    taxi_zone_dictionary.Borough AS dropoff_borough
FROM trips
JOIN taxi_zone_dictionary ON trips.dropoff_nyct2010_gid = taxi_zone_dictionary.LocationID
WHERE tip_amount > 0
ORDER BY tip_amount DESC
LIMIT 10;
```

**Результат:**

![top_tips_join](https://github.com/MakhoninaAV/sql_files/blob/main/click2.15.png?raw=true)

---

## Задание 7. Индивидуальная часть (вариант 13)

### 7.1 Топ-10 районов посадки с максимальной средней суммой чаевых

```sql
SELECT
    COALESCE(tz.Zone, 'Unknown') AS pickup_zone,
    round(avg(t.tip_amount), 2) AS avg_tip,
    count() AS trips_count
FROM trips AS t
LEFT JOIN taxi_zone_dictionary AS tz ON toUInt64(t.pickup_nyct2010_gid) = tz.LocationID
WHERE t.pickup_nyct2010_gid > 0 AND t.tip_amount > 0
GROUP BY tz.Zone
ORDER BY avg_tip DESC
LIMIT 10;
```

**Результат:**

![top_zones_by_tip](https://github.com/MakhoninaAV/sql_files/blob/main/click2.16.png?raw=true)

| pickup_zone | avg_tip | trips_count |
|-------------|---------|-------------|
| Arrochar | 18.35 | 8 |
| Highbridge | 13.34 | 148 |
| Astoria Park | 9.73 | 24726 |
| Astoria | 9.65 | 107 |
| Elmhurst/Maspeth | 7.46 | 28 |
| Clinton East | 7.21 | 35479 |
| Eltingville/Tottenville | 6.80 | 32 |
| Fort Greene | 6.61 | 10 |
| East Flushing | 6.58 | 149 |
| Homecrest | 6.44 | 13 |

---

### 7.2 Анализ поездок по периодам дня

```sql
SELECT
    CASE
        WHEN toHour(pickup_datetime) BETWEEN 6 AND 11 THEN 'Утро (6-11)'
        WHEN toHour(pickup_datetime) BETWEEN 12 AND 17 THEN 'День (12-17)'
        WHEN toHour(pickup_datetime) BETWEEN 18 AND 23 THEN 'Вечер (18-23)'
        ELSE 'Ночь (0-5)'
    END AS time_period,
    count() AS total_trips,
    round(avg(tip_amount), 2) AS avg_tip,
    round(avg(total_amount), 2) AS avg_total
FROM trips
GROUP BY time_period
ORDER BY total_trips DESC;
```

**Результат:**

![time_periods](https://github.com/MakhoninaAV/sql_files/blob/main/click2.17.png?raw=true)

| time_period | total_trips | avg_tip | avg_total |
|-------------|-------------|---------|-----------|
| Вечер (18-23) | 686314 | 1.73 | 16.06 |
| День (12-17) | 578946 | 1.64 | 16.68 |
| Утро (6-11) | 477890 | 1.66 | 15.59 |
| Ночь (0-5) | 256507 | 1.69 | 16.83 |

---

## Вывод

В ходе выполнения практической работы были получены следующие результаты:

1. Создана таблица `trips` для хранения данных о поездках такси Нью-Йорка с оптимальной структурой (партиционирование по месяцам, сортировка по времени посадки).
2. Загружено **1 999 657** записей из S3-хранилища.
3. Выполнены аналитические запросы:
   - средняя сумма чаевых составила **1.68**;
   - выявлена зависимость средней стоимости поездки от количества пассажиров;
   - получено распределение посадок по районам и часам суток;
   - выделены поездки в аэропорты JFK и LGA.
4. Создан внешний словарь `taxi_zone_dictionary`, содержащий **265** записей с информацией о районах Нью-Йорка.
5. Освоены операции JOIN со словарём для обогащения аналитических данных.
6. Выполнена индивидуальная аналитика для варианта 13:
   - определены районы с наибольшими средними чаевыми (лидеры: Arrochar, Highbridge, Astoria Park);
   - проведён анализ по периодам дня (наибольшее количество поездок приходится на вечернее время).

