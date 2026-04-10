USE final_project;
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/Asylbek Delonghi/Downloads/transactions_info.csv'
INTO TABLE transactions_info
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

USE final_project;

-- Проверяем
SELECT COUNT(*) FROM transactions_info;
SELECT * FROM transactions_info LIMIT 5;

-- Исправляем формат даты
SET SQL_SAFE_UPDATES = 0;

ALTER TABLE transactions_info ADD COLUMN date_converted DATE;

UPDATE transactions_info
SET date_converted = STR_TO_DATE(date_new, '%d/%m/%Y');

ALTER TABLE transactions_info DROP COLUMN date_new;
ALTER TABLE transactions_info RENAME COLUMN date_converted TO date_new;

SET SQL_SAFE_UPDATES = 1;

-- Проверяем
SELECT * FROM transactions_info LIMIT 5;

ALTER TABLE transactions_info DROP COLUMN date_new;

ALTER TABLE transactions_info RENAME COLUMN date_converted TO date_new;

-- Проверяем
SELECT * FROM transactions_info LIMIT 5;
SELECT MIN(date_new), MAX(date_new) FROM transactions_info;

-- Задание 1: Клиенты с непрерывной историей за год
WITH period_transactions AS (
    SELECT *
    FROM transactions_info
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
),
client_months AS (
    SELECT
        ID_client,
        COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) AS active_months
    FROM period_transactions
    GROUP BY ID_client
),
continuous_clients AS (
    SELECT ID_client
    FROM client_months
    WHERE active_months = 12
)
SELECT
    t.ID_client,
    COUNT(t.Id_check)                           AS total_operations,
    ROUND(SUM(t.Sum_payment), 2)                AS total_sum,
    ROUND(AVG(t.Sum_payment), 2)                AS avg_check,
    ROUND(SUM(t.Sum_payment) / 12, 2)           AS avg_monthly_sum
FROM period_transactions t
JOIN continuous_clients c ON t.ID_client = c.ID_client
GROUP BY t.ID_client
ORDER BY total_sum DESC;

-- Задание 2.1-2.4: Анализ в разрезе месяцев
WITH period_t AS (
    SELECT *
    FROM transactions_info
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
),
yearly_totals AS (
    SELECT
        COUNT(Id_check)     AS year_ops,
        SUM(Sum_payment)    AS year_sum
    FROM period_t
)
SELECT
    DATE_FORMAT(t.date_new, '%Y-%m')            AS month,
    ROUND(AVG(t.Sum_payment), 2)                AS avg_check,
    COUNT(t.Id_check)                           AS total_ops,
    COUNT(DISTINCT t.ID_client)                 AS unique_clients,
    ROUND(COUNT(t.Id_check) /
          (SELECT year_ops FROM yearly_totals) * 100, 2) AS ops_share_pct,
    ROUND(SUM(t.Sum_payment) /
          (SELECT year_sum FROM yearly_totals) * 100, 2) AS sum_share_pct,
    ROUND(SUM(t.Sum_payment), 2)                AS total_sum
FROM period_t t
GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
ORDER BY month;


-- Задание 2.5: % соотношение M/F/NA по месяцам
WITH period_t AS (
    SELECT t.*, COALESCE(c.Gender, 'NA') AS Gender
    FROM transactions_info t
    LEFT JOIN customer_info c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
),
monthly_totals AS (
    SELECT
        DATE_FORMAT(date_new, '%Y-%m') AS month,
        COUNT(Id_check)                AS month_ops,
        SUM(Sum_payment)               AS month_sum
    FROM period_t
    GROUP BY DATE_FORMAT(date_new, '%Y-%m')
)
SELECT
    DATE_FORMAT(p.date_new, '%Y-%m')            AS month,
    p.Gender,
    COUNT(p.Id_check)                           AS ops_count,
    ROUND(COUNT(p.Id_check) /
          m.month_ops * 100, 2)                 AS ops_pct,
    ROUND(SUM(p.Sum_payment), 2)                AS total_sum,
    ROUND(SUM(p.Sum_payment) /
          m.month_sum * 100, 2)                 AS sum_pct
FROM period_t p
JOIN monthly_totals m
    ON DATE_FORMAT(p.date_new, '%Y-%m') = m.month
GROUP BY DATE_FORMAT(p.date_new, '%Y-%m'), p.Gender, m.month_ops, m.month_sum
ORDER BY month, Gender;


-- Задание 3: Возрастные группы — весь период
WITH period_t AS (
    SELECT
        t.*,
        CASE
            WHEN c.Age IS NULL                THEN 'NA'
            WHEN c.Age BETWEEN 0  AND 10      THEN '0-10'
            WHEN c.Age BETWEEN 11 AND 20      THEN '11-20'
            WHEN c.Age BETWEEN 21 AND 30      THEN '21-30'
            WHEN c.Age BETWEEN 31 AND 40      THEN '31-40'
            WHEN c.Age BETWEEN 41 AND 50      THEN '41-50'
            WHEN c.Age BETWEEN 51 AND 60      THEN '51-60'
            WHEN c.Age BETWEEN 61 AND 70      THEN '61-70'
            WHEN c.Age BETWEEN 71 AND 80      THEN '71-80'
            WHEN c.Age BETWEEN 81 AND 90      THEN '81-90'
            ELSE '90+'
        END AS age_group
    FROM transactions_info t
    LEFT JOIN customer_info c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
)
SELECT
    age_group,
    COUNT(Id_check)                                AS total_ops,
    ROUND(SUM(Sum_payment), 2)                     AS total_sum,
    ROUND(COUNT(Id_check) /
         (SELECT COUNT(*) FROM period_t) * 100, 2) AS ops_pct,
    ROUND(SUM(Sum_payment) /
         (SELECT SUM(Sum_payment) FROM period_t) * 100, 2) AS sum_pct
FROM period_t
GROUP BY age_group
ORDER BY age_group;

-- Задание 3: Возрастные группы поквартально
WITH period_t AS (
    SELECT
        t.*,
        YEAR(t.date_new)                        AS year,
        QUARTER(t.date_new)                     AS quarter,
        CASE
            WHEN c.Age IS NULL                  THEN 'NA'
            WHEN c.Age BETWEEN 0  AND 10        THEN '0-10'
            WHEN c.Age BETWEEN 11 AND 20        THEN '11-20'
            WHEN c.Age BETWEEN 21 AND 30        THEN '21-30'
            WHEN c.Age BETWEEN 31 AND 40        THEN '31-40'
            WHEN c.Age BETWEEN 41 AND 50        THEN '41-50'
            WHEN c.Age BETWEEN 51 AND 60        THEN '51-60'
            WHEN c.Age BETWEEN 61 AND 70        THEN '61-70'
            WHEN c.Age BETWEEN 71 AND 80        THEN '71-80'
            WHEN c.Age BETWEEN 81 AND 90        THEN '81-90'
            ELSE '90+'
        END AS age_group
    FROM transactions_info t
    LEFT JOIN customer_info c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
),
quarterly_totals AS (
    SELECT
        year, quarter,
        COUNT(Id_check)     AS q_ops,
        SUM(Sum_payment)    AS q_sum
    FROM period_t
    GROUP BY year, quarter
)
SELECT
    CONCAT(p.year, ' Q', p.quarter)             AS period,
    p.age_group,
    COUNT(p.Id_check)                           AS ops_count,
    ROUND(AVG(p.Sum_payment), 2)                AS avg_check,
    ROUND(SUM(p.Sum_payment), 2)                AS total_sum,
    ROUND(COUNT(p.Id_check) /
          q.q_ops * 100, 2)                     AS ops_pct,
    ROUND(SUM(p.Sum_payment) /
          q.q_sum * 100, 2)                     AS sum_pct
FROM period_t p
JOIN quarterly_totals q
    ON p.year = q.year AND p.quarter = q.quarter
GROUP BY p.year, p.quarter, p.age_group, q.q_ops, q.q_sum
ORDER BY p.year, p.quarter, p.age_group;