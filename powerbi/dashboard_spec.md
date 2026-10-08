# Shoplytics Power BI Dashboard Specification

## Design Direction

- Layout style: clean executive analytics workspace with strong whitespace and card-based hierarchy
- Palette: slate, deep teal, warm coral, amber, and soft neutrals
- Typography: Segoe UI Semibold for titles, Segoe UI for body and labels
- Visual behavior: minimal borders, soft backgrounds, consistent left alignment, selective use of accent color

## Page 1: Executive Overview

- KPI cards: Total Revenue, Gross Profit, Total Orders, Active Customers, Average Order Value
- Line chart: Monthly revenue trend

## Page 2: Revenue Growth

- Horizontal bar chart: revenue by category
- Horizontal bar chart: units sold by category
- Line chart: monthly gross profit trend
- Horizontal bar chart: profit margin by category

## Page 3: Customer Segmentation

- Cohort matrix: signup month vs cohort index retention rate
- Line chart: retention trend by customer cohort
- Horizontal bar chart: customers by acquisition channel

## Page 4: Churn Signals

- Donut chart: customer count by churn-risk classification
- Scatter plot: days since last order vs total customer revenue, sized by order count
- Customer details table: customer, region, acquisition channel, orders, revenue, recency, and risk

## Production Polish

- Use consistent 8px spacing rhythm
- Pin primary KPIs in the top fold
- Keep one analytical question per major visual
- Prefer muted backgrounds with only one strong accent per page
- Use consistent risk colors across the churn visuals
