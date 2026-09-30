	
--Change-Over-Time trends	
	---Finding the trend of sales over time. 
	--(it can be divided by year, month,have the year and month combined in DATETRUNC, or format how you want. 
	--Just uncomment what you want to use)
		Select
		FORMAT(order_date,'yyyy-MMM') as order_date,
		--DATETRUNC(month, order_date) as order_date,
		--year(order_date) as order_year,
		--month(order_date) as order_month,
		sum(sales_amount) as total_sales,
		count(distinct customer_key) as total_customers,
		sum(quantity) as total_quantity
		from gold.fact_sale
		where order_date is not null
		Group by --year(order_date),
		--month(order_date)
		--DATETRUNC(month, order_date)
		FORMAT(order_date,'yyyy-MMM') 
		order by --year(order_date),
		--month(order_date)
		--DATETRUNC(month, order_date)
		FORMAT(order_date,'yyyy-MMM') 

--Cumulative Analysis
		--The Cumulative measure by date dimension...keeping a running total. 
		--This uses a window function
		Select
		order_date,
		total_sales_month,
		sum(total_sales_month) over (order by order_date) as running_total_sales,
		AVG(average_price) over (order by order_date) as moving_average_price
		from 
		(
		Select 
		DATETRUNC(month,order_date) as order_date,
		sum(sales_amount) as total_sales_month,
		AVG(price) as average_price
		from gold.fact_sale
		where order_date is not null
		group by DATETRUNC(month,order_date)
		--Order by DATETRUNC(month,order_date) --Won't need the order by in the subquery. 
		--Also, can't use Format for the date because it couldn't process.
		) t


--Performance Analysis
		--Comparing the current value with a target value
		--current[measure]-target[measure]
		--current sales - average sales
		--current year sales - previous year sales
		--current sales - lowest sales


		--Analyze the yearly performance of products by comparing their sales to both the average sales
		--performance of the product and the previous year's sales.
		With Yearly_sales as (

		Select
		YEAR(s.order_date) as order_year,
		p.product_name,
		SUM(s.sales_amount) as current_sales
		from gold.fact_sale s
		left join gold.dim_product p
		on s.product_key = p.product_key
		Where order_date is not null
		Group by 
		year(s.order_date),
		product_name
		)

		Select
		order_year,
		product_name,
		current_sales,
		Avg(current_sales) over(partition by product_name) as avg_sales,
		current_sales-(Avg(current_sales) over(partition by product_name)) as diff_avg,
		case when current_sales-(Avg(current_sales) over(partition by product_name)) >0 then 'Above AVG'
			 when current_sales-(Avg(current_sales) over(partition by product_name)) = 0 then 'Average'
			 else 'Below Avg'
		end as status_avg,
		lag(current_sales) over (partition by product_name order by order_year) as previous_year,
		current_sales-(
		lag(current_sales) over (partition by product_name order by order_year)) as previous_years_comparison,
		Case When current_sales-(lag(current_sales) over (partition by product_name Order by order_year)) >0 then 'Increase'
			 When current_sales-(lag(current_sales) over (partition by product_name Order by order_year)) <0 then 'Decrease'
			 else 'No Change'
		end as py_change
		from Yearly_sales
		order by product_name, order_year

--Part-to-Whole Analysis
   ---Proportional  Analysis
   ---Analyze how an individual part is performing compared to the overall,
   ---allowing us to understand which category has the greatest impact on the business.


   --Which Categories contribute the most to overall sales?
With sales_percent as (
   Select 
	p.category,
	sum(sales_amount) as total_sales
	from gold.dim_product p
	left join gold.fact_sale s
	on p.product_key = s.product_key
	Group by
	p.category
	)

	Select
	category,
	total_sales,
	sum(total_sales) OVER() as ALL_sales,
	CONCAT(round((CAST(total_sales as FLOAT)/sum(total_sales) OVER())*100,2),'%') as percent_of_sales
	from sales_percent
	--Group By category,  total_sales
	order by category,  percent_of_sales



--Data Segmentation
	--Group the data based on a specific range 
	--to help understand the correlation between two measures.
	--[Measure] by [Measure]

	--Segement products in cost ranges and count how many products fall into each segment
with product_segment as (
	Select distinct
	product_key,
	product_name,
	cost,
	Case when cost <100 then 'Below 100'
		 When cost between 100 and 500 then '100-500'
		 when cost between 500 and 1000 then '500-1000'
		 else 'above 1000'
		end as cost_range
	from gold.dim_products
	)

	Select
	cost_range,
	count(product_key) as total_products
	from product_segment
	group by cost_range

