/*
====================================================================
CUSTOMER REPORT
====================================================================
Purpose:
	- This report consolidates key customer metrics and behaviors.

Highlights:
	1. Gather essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
		-total orders
		-total sales
		-total quantity purchased
		-total products
		-lifespan (in months)
	4. Calculates valuable KPIs:
		-recency (months since last order)
		-average order value
		-average monthly spend
====================================================================
*/

/*------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
-------------------------------------------------------------------*/
Create view gold.report_customers as 

With base_query as(
Select
order_number,
product_key,
order_date,
sales_amount,
quantity,
c.customer_key,
customer_number,
concat(first_name,' ',last_name) as customer_name,
Datediff(year,birthdate, GETDATE()) as age
from gold.fact_sale s
left join gold.dim_customer c
on s.customer_key = c.customer_key
where order_date is not null
)


, customer_aggregation as (
/*----------------------------------------------------------------------
2) Customer Aggregations: Summarizes key metrics at the customer level
-----------------------------------------------------------------------*/
Select
customer_key,
customer_number,
customer_name,
age,
Count(Distinct order_number) as total_orders,
Sum(sales_amount) as total_sales,
SUM(quantity) as total_quantity,
count(distinct product_key) as total_products,
MAX(order_date) as last_order,
DATEDIFF(month, min(order_date), MAX(order_date)) lifespan
From base_query
Group by
customer_key,
customer_number,
customer_name,
age)


Select
customer_key,
customer_number,
customer_name,
age,
Case when age < 20 then 'under 20'
	 when age between 20 and 29 then '20-29'
	 when age between 30 and 39 then '30-39'
	 when age between 40 and 49 then '40-49'
	 else '50 and above'
	 end as age_group,
case when LIFESPAN >11 and total_sales >= 5000 then 'VIP'
	  when LIFESPAN >11 and total_sales < 5000 then 'REGULAR'
	  else 'New'
	  end as customer_segment,
total_orders,
total_sales,
--Compute average order value (AVO)
Case when LIFESPAN = 0 then total_sales
    else (total_sales/LIFESPAN)
end as avg_monthly_spend,
total_quantity,
total_products,
last_order,
DATEDIFF(Month,last_order, GETDATE()) as recency,
--Compute averag order value (AVO)
Case when total_orders = 0 then 0
    else (total_sales/total_orders)
end as avg_order_value,
lifespan
from customer_aggregation
/*------------------------------------------------------------*/

Select * from gold.report_customers



/*
==========================================================================
Product Report
==========================================================================
Purpose:
	-This report consolidates key prodcut metrics and behaviors.

Highlights:
	1) Gathers essential fields such as product_name, category, subcategory and cost.
	2) Segments products by revenue to identify High-Performers, Mid-Range or Low-Performers.
	3) Aggregates product-level metrics:
		-total orders
		-total sales
		-total quantity sold
		-total customers (unique)
		-Lifespan (in months)
	4) calculates valuable KPIs:
		-recency (months since last sale)
		-average order revenue (AOR)
		-average monthly revenue
=============================================================================
*/

Create view gold.report_products as 

With product_details as (

/*----------------------------------------------------------------------------
1) Base query: Retrieves core columns from fact_sale and dim_products
----------------------------------------------------------------------------*/
Select
p.product_key,
product_name,
category,
subcategory,
cost,
DateDiff(month, start_date, GETDATE()) as LifeSpan,
order_date,
order_number,
sales_amount,
quantity,
customer_key
from gold.fact_sale s
left join gold.dim_product p
on p.product_key = s.product_key
Where order_date is not null  --only consider valid sales dates
)

, product_aggregates as (
/*-----------------------------------------------------------------------------
2) aggregate query: summarizes key metrics at the product level
------------------------------------------------------------------------------*/
Select
product_key,
product_name,
category,
subcategory,
cost,
LifeSpan,
Max(order_date) as last_order,
count(distinct order_number) as total_orders,
sum(sales_amount) as total_sales,
sum(quantity) as total_quantity_sold,
count(distinct customer_key) as total_customers
from product_details
Group by 
product_key,
product_name,
category,
subcategory,
cost,
LifeSpan
)

Select
product_key,
product_name,
category,
subcategory,
cost,
LifeSpan,
DateDiff(month,last_order, GETDATE()) as order_recency,
total_orders,
total_sales,
total_quantity_sold,
total_customers,
Case when total_orders = 0 then 0
	else total_sales/total_orders
	end as avg_order_revenue,
Case when LifeSpan = 0 then total_sales
	else avg(total_sales/LifeSpan)
	end as avg_monthly_revenue,
Case when total_sales>50000 then 'High Performer'
	  when total_sales >= 10000 then 'Mid-Range'
	  Else 'Low-Performer'
end as product_segment
from product_aggregates
Group By
product_key,
product_name,
category,
subcategory,
cost,
LifeSpan,
last_order,
total_orders,
total_sales,
total_quantity_sold,
total_customers

Select * from gold.report_products
