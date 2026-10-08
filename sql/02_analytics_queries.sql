-- Monthly revenue and order trends
SELECT
    DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS active_customers,
    SUM((oi.quantity * oi.unit_price) - oi.discount_amount) AS net_revenue,
    AVG((oi.quantity * oi.unit_price) - oi.discount_amount) AS avg_line_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
ORDER BY order_month;

-- Category performance with profitability
SELECT
    p.category,
    SUM(oi.quantity) AS units_sold,
    SUM((oi.quantity * oi.unit_price) - oi.discount_amount) AS net_revenue,
    SUM(((oi.quantity * oi.unit_price) - oi.discount_amount) - (oi.quantity * p.unit_cost)) AS gross_profit,
    COUNT(DISTINCT o.order_id) AS orders
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY net_revenue DESC;

-- Cohort retention by signup month
WITH customer_orders AS (
    SELECT DISTINCT
        c.customer_id,
        DATEFROMPARTS(YEAR(c.signup_date), MONTH(c.signup_date), 1) AS cohort_month,
        DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS order_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
),
cohort_activity AS (
    SELECT
        cohort_month,
        order_month,
        DATEDIFF(MONTH, cohort_month, order_month) + 1 AS cohort_index,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM customer_orders
    GROUP BY cohort_month, order_month
),
cohort_size AS (
    SELECT
        DATEFROMPARTS(YEAR(signup_date), MONTH(signup_date), 1) AS cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customers
    GROUP BY DATEFROMPARTS(YEAR(signup_date), MONTH(signup_date), 1)
)
SELECT
    ca.cohort_month,
    ca.cohort_index,
    cs.cohort_size,
    ca.active_customers,
    CAST((ca.active_customers * 100.0) / cs.cohort_size AS DECIMAL(5, 2)) AS retention_rate
FROM cohort_activity ca
JOIN cohort_size cs ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month, ca.cohort_index;

-- Customer churn signal by recency
WITH customer_summary AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.region,
        c.acquisition_channel,
        MAX(o.order_date) AS last_order_date,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM((oi.quantity * oi.unit_price) - oi.discount_amount) AS total_revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.customer_name, c.region, c.acquisition_channel
)
SELECT
    *,
    DATEDIFF(DAY, last_order_date, (SELECT MAX(order_date) FROM orders)) AS days_since_last_order,
    CASE
        WHEN DATEDIFF(DAY, last_order_date, (SELECT MAX(order_date) FROM orders)) > 60 THEN 'High'
        WHEN DATEDIFF(DAY, last_order_date, (SELECT MAX(order_date) FROM orders)) > 30 THEN 'Medium'
        ELSE 'Low'
    END AS churn_risk
FROM customer_summary
ORDER BY days_since_last_order DESC;

-- Restocking opportunities using recent sales velocity
WITH recent_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.inventory_on_hand,
        SUM(oi.quantity) AS units_last_45_days
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_date >= DATEADD(DAY, -45, (SELECT MAX(order_date) FROM orders))
    GROUP BY p.product_id, p.product_name, p.category, p.inventory_on_hand
)
SELECT
    *,
    CASE
        WHEN inventory_on_hand < 25 AND units_last_45_days > 20 THEN 'Critical'
        WHEN inventory_on_hand < 60 AND units_last_45_days > 10 THEN 'Monitor'
        ELSE 'Healthy'
    END AS restock_priority
FROM recent_sales
ORDER BY units_last_45_days DESC, inventory_on_hand ASC;
