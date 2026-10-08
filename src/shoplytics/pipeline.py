from pathlib import Path

import pandas as pd


BASE_DIR = Path(__file__).resolve().parents[2]
DATA_DIR = BASE_DIR / "data" / "sample"
OUTPUT_DIR = BASE_DIR / "output"


def _load_data() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    customers = pd.read_csv(DATA_DIR / "customers.csv", parse_dates=["signup_date"])
    products = pd.read_csv(DATA_DIR / "products.csv")
    orders = pd.read_csv(DATA_DIR / "orders.csv", parse_dates=["order_date", "ship_date"])
    order_items = pd.read_csv(DATA_DIR / "order_items.csv")
    return customers, products, orders, order_items


def _build_order_fact(
    customers: pd.DataFrame,
    products: pd.DataFrame,
    orders: pd.DataFrame,
    order_items: pd.DataFrame,
) -> pd.DataFrame:
    fact = (
        order_items.merge(orders, on="order_id", how="left")
        .merge(customers, on="customer_id", how="left")
        .merge(products, on="product_id", how="left", suffixes=("_sale", "_product"))
    )
    fact["gross_revenue"] = fact["quantity"] * fact["unit_price_sale"]
    fact["net_revenue"] = fact["gross_revenue"] - fact["discount_amount"]
    fact["gross_profit"] = fact["net_revenue"] - (fact["quantity"] * fact["unit_cost"])
    fact["order_month"] = fact["order_date"].dt.to_period("M").dt.to_timestamp()
    fact["signup_month"] = fact["signup_date"].dt.to_period("M").dt.to_timestamp()
    return fact


def _export_kpi_summary(fact: pd.DataFrame) -> pd.DataFrame:
    orders = fact["order_id"].nunique()
    customers = fact["customer_id"].nunique()
    revenue = fact["net_revenue"].sum()
    profit = fact["gross_profit"].sum()
    avg_order_value = revenue / orders if orders else 0

    summary = pd.DataFrame(
        [
            {"metric": "Total Revenue", "value": round(revenue, 2)},
            {"metric": "Gross Profit", "value": round(profit, 2)},
            {"metric": "Total Orders", "value": orders},
            {"metric": "Active Customers", "value": customers},
            {"metric": "Average Order Value", "value": round(avg_order_value, 2)},
        ]
    )
    summary.to_csv(OUTPUT_DIR / "kpi_summary.csv", index=False)
    return summary


def _export_monthly_revenue(fact: pd.DataFrame) -> pd.DataFrame:
    monthly = (
        fact.groupby("order_month", as_index=False)
        .agg(
            revenue=("net_revenue", "sum"),
            gross_profit=("gross_profit", "sum"),
            orders=("order_id", "nunique"),
            customers=("customer_id", "nunique"),
        )
        .sort_values("order_month")
    )
    monthly["average_order_value"] = (monthly["revenue"] / monthly["orders"]).round(2)
    monthly.to_csv(OUTPUT_DIR / "monthly_revenue.csv", index=False)
    return monthly


def _export_cohort_retention(fact: pd.DataFrame) -> pd.DataFrame:
    customer_months = (
        fact[["customer_id", "signup_month", "order_month"]]
        .drop_duplicates()
        .sort_values(["customer_id", "order_month"])
    )
    customer_months["cohort_index"] = (
        (customer_months["order_month"].dt.year - customer_months["signup_month"].dt.year) * 12
        + (customer_months["order_month"].dt.month - customer_months["signup_month"].dt.month)
        + 1
    )

    cohort_size = (
        customer_months.groupby("signup_month")["customer_id"]
        .nunique()
        .rename("cohort_size")
        .reset_index()
    )
    retention = (
        customer_months.groupby(["signup_month", "cohort_index"])["customer_id"]
        .nunique()
        .rename("active_customers")
        .reset_index()
        .merge(cohort_size, on="signup_month", how="left")
    )
    retention["retention_rate"] = (
        retention["active_customers"] / retention["cohort_size"] * 100
    ).round(2)
    retention.to_csv(OUTPUT_DIR / "cohort_retention.csv", index=False)
    return retention


def _export_category_performance(fact: pd.DataFrame) -> pd.DataFrame:
    category = (
        fact.groupby("category", as_index=False)
        .agg(
            revenue=("net_revenue", "sum"),
            gross_profit=("gross_profit", "sum"),
            units_sold=("quantity", "sum"),
            orders=("order_id", "nunique"),
        )
        .sort_values("revenue", ascending=False)
    )
    category["profit_margin_pct"] = (
        category["gross_profit"] / category["revenue"] * 100
    ).round(2)
    category.to_csv(OUTPUT_DIR / "category_performance.csv", index=False)
    return category


def _export_customer_churn_signals(fact: pd.DataFrame) -> pd.DataFrame:
    last_order_date = fact["order_date"].max()
    churn = (
        fact.groupby(
            ["customer_id", "customer_name", "region", "acquisition_channel"],
            as_index=False,
        ).agg(
            total_orders=("order_id", "nunique"),
            total_revenue=("net_revenue", "sum"),
            last_order_date=("order_date", "max"),
        )
    )
    churn["days_since_last_order"] = (last_order_date - churn["last_order_date"]).dt.days
    churn["churn_risk"] = pd.cut(
        churn["days_since_last_order"],
        bins=[-1, 30, 60, 10_000],
        labels=["Low", "Medium", "High"],
    )
    churn.to_csv(OUTPUT_DIR / "customer_churn_signals.csv", index=False)
    return churn


def _export_restock_recommendations(fact: pd.DataFrame) -> pd.DataFrame:
    recent_cutoff = fact["order_date"].max() - pd.Timedelta(days=45)
    recent_sales = (
        fact.loc[fact["order_date"] >= recent_cutoff]
        .groupby(["product_id", "product_name", "category", "inventory_on_hand"], as_index=False)
        .agg(
            units_last_45_days=("quantity", "sum"),
            revenue_last_45_days=("net_revenue", "sum"),
        )
    )
    recent_sales["restock_priority"] = pd.cut(
        recent_sales["inventory_on_hand"],
        bins=[-1, 25, 60, 10_000],
        labels=["Critical", "Monitor", "Healthy"],
    )
    recommendations = recent_sales.sort_values(
        ["restock_priority", "units_last_45_days"], ascending=[True, False]
    )
    recommendations.to_csv(OUTPUT_DIR / "restock_recommendations.csv", index=False)
    return recommendations


def run_pipeline() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    customers, products, orders, order_items = _load_data()
    fact = _build_order_fact(customers, products, orders, order_items)

    _export_kpi_summary(fact)
    _export_monthly_revenue(fact)
    _export_cohort_retention(fact)
    _export_category_performance(fact)
    _export_customer_churn_signals(fact)
    _export_restock_recommendations(fact)

    print(f"Dashboard-ready datasets exported to {OUTPUT_DIR}")
