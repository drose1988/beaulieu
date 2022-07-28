##############################################################################################################################################################
-- Ch. 16: Analytic Functions
##############################################################################################################################################################

-- data analysis has traditionally been done outside the database server in tool and languages like Excel, Python, R
-- however sql language includes a robust set of functions for analytic processing
-- ex. generating rankings, calculate percentage differences between one time period and another

###### Window Functions ######################################################################################################################################

-- windows effectively partition the data for use by the analytic function without changing the overall result set
-- windows are defined with the OVER clause and have an optional PARTITION BY and ORDER BY clause
-- if you leave the OVER clause empty, it tells sql the window should include the entire result set

##############################################################################################################################################################

-- simply the sum of sales per month (grouping on quarter and month)


SELECT
	QUARTER(payment_date) AS quarter,
    MONTHNAME(payment_date) AS month_nm,
    SUM(amount) AS monthly_sales
FROM payment
WHERE year(payment_date) = 2005
GROUP BY 1,2;

##############################################################################################################################################################

-- window function here take the largest value of SUM(amount) grouped by quarter and month
-- that value stays constant down the whole data set
-- the same window function partitioned by quarter, our max value of each quarter will stay constant down the data set, changing according to the quarter

SELECT
	QUARTER(payment_date) AS quarter,
    MONTHNAME(payment_date) AS month_nm,
    SUM(amount) AS monthly_sales,
    MAX(SUM(amount)) OVER () AS max_overall_sales,
    MAX(SUM(amount)) OVER (PARTITION BY QUARTER(payment_date)) AS max_qrt_sales
FROM payment
WHERE year(payment_date) = 2005
GROUP BY 1,2;

###### Localized Sorting #####################################################################################################################################

-- window functions to specify a sort order
-- used for ranking a set of values, creates a new column with the rank
-- with PARTITION BY and ORDER BY you specify the level your ranking will generate

SELECT
	QUARTER(payment_date) AS quarter,
    MONTHNAME(payment_date) AS month_nm,
    SUM(amount) AS monthly_sales,
    RANK() OVER (PARTITION BY QUARTER(payment_date) ORDER BY SUM(amount)) AS max_overall_sales
FROM payment
WHERE year(payment_date) = 2005
GROUP BY 1,2;

###### Ranking Functions #####################################################################################################################################

-- ROW_NUMBER() - when two values are the same, the function will arbitrarily assign ranks to them
-- RANK() - same values will share a rank number and the next value will be have the followed rank number
-- DENSE_RANK() - when two values are the same, they share a rank and the next value will

##############################################################################################################################################################

SELECT 
	customer_id,
    COUNT(*) AS num_rentals
FROM rental
GROUP BY 1
ORDER BY 2 DESC;

##############################################################################################################################################################

-- here we can see how the ranking functions differ

SELECT 
	customer_id,
    COUNT(*) AS num_rentals,
    ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS row_num_rnk,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk,
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS dense_rnk
FROM rental
GROUP BY 1
ORDER BY 2 DESC;

###### Generating Multiple Rankings ##########################################################################################################################

-- use PARTITION BY to split the rankings up into multiple lists depending on the values in a specified column 

##############################################################################################################################################################

SELECT 
	customer_id,
    MONTHNAME(rental_date) AS month,
    COUNT(*) AS num_rentals,
    RANK() OVER(PARTITION BY MONTHNAME(rental_date) ORDER BY COUNT(*) DESC) AS rank_rnk
FROM rental 
GROUP BY 1,2
ORDER BY 2,3 DESC;

##############################################################################################################################################################

-- throw it in a subquery and limit the results to just the top 5 customers per month

SELECT *
FROM
		(SELECT 
			customer_id,
			MONTHNAME(rental_date) AS month,
			COUNT(*) AS num_rentals,
			RANK() OVER(PARTITION BY MONTHNAME(rental_date) ORDER BY COUNT(*) DESC) AS rank_rnk
		FROM rental 
		GROUP BY 1,2
		ORDER BY 2,3 DESC) a
WHERE rank_rnk <= 5
ORDER BY 2, 3 DESC, 4;

###### Reporting Functions ###################################################################################################################################

-- finding outliers (MIN, MAX) or generating SUMs or AVGs

SELECT
    MONTHNAME(payment_date) AS month_nm,
    amount,
    SUM(amount) OVER(PARTITION BY MONTHNAME(payment_date)) AS monthly_total,
    SUM(amount) OVER() AS grand_total
FROM payment
WHERE amount >= 10
ORDER BY 1;

##############################################################################################################################################################

-- having this total fields generated from window functions makes calculating each record very easy

SELECT
    MONTHNAME(payment_date) AS month_nm,
    SUM(amount) AS month_total,
    ROUND(SUM(amount) / SUM(SUM(amount)) OVER () * 100 ,2) AS pct_of_total
FROM payment
GROUP BY 1
ORDER BY 1;
	
##############################################################################################################################################################

SELECT
    MONTHNAME(payment_date) AS month_nm,
    SUM(amount) AS month_total,
    CASE WHEN SUM(amount) = MAX(SUM(amount)) OVER () THEN 'highest'
		 WHEN SUM(amount) = MIN(SUM(amount)) OVER () THEN 'lowest'
         ELSE 'middle' END AS descriptor
FROM payment
GROUP BY 1
ORDER BY 1;

###### Window Frames #########################################################################################################################################

-- if you need finer control over which rows to include in a data window
-- a frame subclause defines exaclty which rows to include in the data window
-- ROWS UNBOUNDED PRECEDING: says the data window is defined from the beginning of the result set up to and including the current row
-- 

SELECT 
	YEARWEEK(payment_date) AS payment_week,
    SUM(amount) AS week_total,
    SUM(SUM(amount)) OVER (ORDER BY YEARWEEK(payment_date) ROWS UNBOUNDED PRECEDING) AS rolling_sum
FROM payment
GROUP BY 1
ORDER BY 1;

##############################################################################################################################################################

-- the rolling 3 week average is the average of current row, previous row, next row

SELECT 
	YEARWEEK(payment_date) AS payment_week,
    SUM(amount) AS week_total,
    AVG(SUM(amount)) OVER (ORDER BY YEARWEEK(payment_date) ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS rolling_3_wk_avg
FROM payment
GROUP BY 1
ORDER BY 1;

##############################################################################################################################################################

-- range is the alternative to rows if you're looking for specific date invervals rather than a number of rows
-- this is helpful if there are gaps in your data
-- here, the 7 day average takes the sum amount of the current date along with the 3 days before and 3 day after it
-- then averages that number

SELECT
	DATE(payment_date),
    SUM(amount),
    AVG(SUM(amount)) OVER (ORDER BY DATE(payment_date) RANGE BETWEEN INTERVAL 3 DAY PRECEDING AND INTERVAL 3 DAY FOLLOWING) AS 7_day_average
FROM payment
WHERE payment_date BETWEEN '2005-07-01' AND '2005-09-01'
GROUP BY 1
ORDER BY 1;

###### Lag and Lead ##########################################################################################################################################

-- another common task is comparing values from one row to another
-- LEAD and LAG retrieve a column values from the previous and next row in the resulting set
-- we can specify how many rows to go back or forward, but it defaults to 1

SELECT
	YEARWEEK(payment_date) AS payment_week,
    SUM(amount) AS week_tot,
    LAG(SUM(amount), 1) OVER (ORDER BY YEARWEEK(payment_date)) AS prev_week_tot,
    LEAD(SUM(amount), 1) OVER (ORDER BY YEARWEEK(payment_date)) AS next_week_tot
FROM payment
GROUP BY 1
ORDER BY 1;

##############################################################################################################################################################

-- to calculate percent difference from previous week
-- you take week_total and minus prev_week_total
-- take that number and divide by prev_week_total
-- multiply by 100
-- that final number should be rounded to 1 decimal

SELECT
	YEARWEEK(payment_date) AS payment_week,
    SUM(amount) AS week_tot,
    ROUND((SUM(amount) - LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date))) / 
    LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date)) * 100, 1) AS pct_diff
FROM payment
GROUP BY 1
ORDER BY 1;

##############################################################################################################################################################

-- here are the steps broken down

SELECT
	YEARWEEK(payment_date) AS payment_week,
    SUM(amount) AS week_tot,
    SUM(amount) - LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date)) AS stp_1,
    (SUM(amount) - LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date))) / LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date)) AS stp_2,
    (SUM(amount) - LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date))) / LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date)) AS stp_3,
    (SUM(amount) - LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date))) / LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date)) * 100 AS stp_4,
	ROUND((SUM(amount)-LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date))) / LAG(SUM(amount),1) OVER (ORDER BY YEARWEEK(payment_date))*100,1) stp_5
FROM payment
GROUP BY 1
ORDER BY 1;

###### Column Value Concatenation ############################################################################################################################

-- GROUP_CONCAT: used to pivot a set of column values into a single delimited string
-- were taking the actors' last names grouped by the movie title, specifying the order, and specifying the delimited
-- the HAVING is looking at the number of actors grouped together in each movie, and only returns the movies with 3 actors

SELECT
	f.title,
    GROUP_CONCAT(a.last_name ORDER BY a.last_name DESC SEPARATOR ', ') AS actors
FROM actor a
INNER JOIN film_actor fa
	ON a.actor_id = fa.actor_id
INNER JOIN film f
	ON f.film_id = fa.film_id
GROUP BY 1
HAVING COUNT(*) = 3

##############################################################################################################################################################