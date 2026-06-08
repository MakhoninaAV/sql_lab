-- =====================================================
-- ПРАКТИЧЕСКОЕ ЗАНЯТИЕ №2
-- Вариант 13
-- Анализ данных в ClickHouse (набор данных о поездках такси Нью-Йорка)
-- =====================================================

-- =====================================================
-- 1. Создание таблицы trips
-- =====================================================

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


-- =====================================================
-- 2. Загрузка данных из S3
-- =====================================================

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


-- =====================================================
-- 3. Проверка вставки
-- =====================================================

SELECT count() FROM trips;


-- =====================================================
-- 4. Аналитические запросы
-- =====================================================

-- 4.1 Средняя сумма чаевых
SELECT round(avg(tip_amount), 2) FROM trips;


-- 4.2 Средняя стоимость поездки в зависимости от количества пассажиров
SELECT
    passenger_count,
    ceil(avg(total_amount), 2) AS average_total_amount
FROM trips
GROUP BY passenger_count
ORDER BY passenger_count;


-- 4.3 Ежедневное число посадок такси по районам
SELECT
    pickup_date,
    pickup_ntaname,
    COUNT() AS number_of_trips
FROM trips
WHERE pickup_ntaname != ''
GROUP BY pickup_date, pickup_ntaname
ORDER BY pickup_date ASC
LIMIT 50;


-- 4.4 Продолжительность поездки в минутах и группировка
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


-- 4.5 Количество посадок такси в каждом районе с разбивкой по часам суток
SELECT
    pickup_ntaname,
    toHour(pickup_datetime) AS pickup_hour,
    COUNT() AS pickups
FROM trips
WHERE pickup_ntaname != ''
GROUP BY pickup_ntaname, pickup_hour
ORDER BY pickup_ntaname, pickup_hour
LIMIT 50;


-- 4.6 Поездки в аэропорты (LGA или JFK)
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
LIMIT 50;


-- =====================================================
-- 5. Работа со словарями
-- =====================================================

-- 5.1 Создание словаря
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


-- 5.2 Проверка работы словаря
SELECT * FROM taxi_zone_dictionary LIMIT 10;


-- 5.3 Получение района по LocationID (вместо dictGet)
SELECT Borough, Zone FROM taxi_zone_dictionary WHERE LocationID = 132;
SELECT Borough, Zone FROM taxi_zone_dictionary WHERE LocationID = 138;


-- 5.4 Проверка наличия ключа в словаре (вместо dictHas)
SELECT COUNT(*) AS exists FROM taxi_zone_dictionary WHERE LocationID = 132;
SELECT COUNT(*) AS exists FROM taxi_zone_dictionary WHERE LocationID = 4567;


-- 5.5 Анализ поездок в аэропорты с названиями районов (вместо dictGetOrDefault)
SELECT
    count(1) AS total,
    COALESCE(tz.Borough, 'Unknown') AS borough_name
FROM trips AS t
LEFT JOIN taxi_zone_dictionary AS tz ON toUInt64(t.pickup_nyct2010_gid) = tz.LocationID
WHERE t.dropoff_nyct2010_gid IN (132, 138)
GROUP BY borough_name
ORDER BY total DESC;


-- =====================================================
-- 6. Выполнение соединений (JOIN)
-- =====================================================

-- 6.1 Простой JOIN
SELECT
    count(1) AS total,
    Borough
FROM trips
JOIN taxi_zone_dictionary ON toUInt64(trips.pickup_nyct2010_gid) = taxi_zone_dictionary.LocationID
WHERE dropoff_nyct2010_gid IN (132, 138)
GROUP BY Borough
ORDER BY total DESC;


-- 6.2 JOIN для 1000 поездок с наибольшими чаевыми
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
LIMIT 1000;


-- =====================================================
-- 7. Индивидуальная часть (вариант 13)
-- =====================================================

-- 7.1 Топ-10 районов посадки с максимальной средней суммой чаевых
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


-- 7.2 Анализ поездок по периодам дня
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