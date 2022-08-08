##############################################################################################################################################################
-- Ch. 14: Views
##############################################################################################################################################################

-- views are simply mechanisms for querying data
-- views don't involve data storage, won't fill up disk space
-- users can use views to access data just as they would querying tables directly
-- a method for exposing public interface wile keeping private details intact
-- allowing end users to access data only through a set of views

##############################################################################################################################################################

-- for example, creating a view to mask the email address of customers
-- this allows users to query just like they would a table

CREATE VIEW customer_vw
	(customer_id,
     first_name,
     last_name,
     email) AS 
SELECT
	customer_id,
    first_name,
    last_name,
    CONCAT(SUBSTR(email,1,2),"#####", SUBSTR(email, -4))
FROM customer;

##############################################################################################################################################################

-- some columns in a view are attached to functions or subqueries unlike tables
-- from a user standpoint it looks exactly like a table

DESC customer;
DESC customer_vw;

##############################################################################################################################################################

-- you can use any clause of the select statement when querying through a view as shown here

SELECT
	first_name,
    COUNT(*),
    MIN(last_name),
    MAX(last_name)
FROM customer_vw
WHERE first_name LIKE 'J%'
GROUP BY 1
HAVING COUNT(*) > 1;

##############################################################################################################################################################

-- and can join views to other tables

SELECT
	cv.first_name, cv.last_name, p.amount
FROM customer_vw AS cv
INNER JOIN payment p
ON cv.customer_id = p.customer_id
WHERE p.amount >= 11;

###### Why use views? ########################################################################################################################################

-- Data security --

-- a table may contain sensitive information (identification numbers, credit card info etc.)
-- exposing all users to this may be against company policy, state or federal laws
-- you can grant select permission to only some users on the table
-- then create a view of that table that omits or obscures sensitive information for other users to query off of

##############################################################################################################################################################

-- additionally you can create a view that constains which rows a user can assess using the WHERE clause while creating a view
-- in this created view we don't even include the column specifying if they're active
-- we filter it from the customer table and omit it from the view

CREATE VIEW customer_vw_active
	(customer_id,
     first_name,
     last_name,
     email) AS 
SELECT
	customer_id,
    first_name,
    last_name,
    CONCAT(SUBSTR(email,1,2),"#####", SUBSTR(email, -4))
FROM customer
WHERE active = 1;

##############################################################################################################################################################

-- Data aggregation --

-- views are a great way to make it appear as if data is being preaggregated and stored in the database
-- rather than allowing the developers to write queries against the base tables, provide them with a view

CREATE VIEW sales_by_film_category
AS
SELECT
	c.name AS category,
    SUM(p.amount) AS total_sales
FROM payment AS p
INNER JOIN rental AS r ON p.rental_id = r.rental_id
INNER JOIN inventory AS i ON r.inventory_id = i.inventory_id
INNER JOIN film_category AS fc ON i.film_id = fc.film_id
INNER JOIN category AS c ON fc.category_id = c.category_id
GROUP BY 1
ORDER BY 2 DESC;

##############################################################################################################################################################

-- Hiding complexity --

-- common to use views in order to shield end users from complexities of a query
-- create a view of joined tables, so the end user doesn't have to in order to gather the necessary data

-- in this table you're looking at a view with summary information about each film coming from several other tables
-- subquerying in the select column
-- to get the category name joined with film table, you needed to join with film_category first, because category doesn't have a key linked to film
-- why did you need to join rental table to inventory if inventory and film had a common key

-- data from the 5 tables is generated using scalar subqueries
-- this approach allows the view to be used for supplying descriptive info from the film table without unnecessary joins to the other tables

CREATE VIEW film_stats
AS
SELECT f.film_id, f.title, f.description, f.rating, 
	(SELECT c.name
	 FROM category c
		INNER JOIN film_category fc
        ON c.category_id = fc.category_id
	 WHERE fc.film_id = f.film_id) AS category_name,
	(SELECT COUNT(*)
     FROM film_actor fa
     WHERE fa.film_id = f.film_id) AS num_actors,
	(SELECT COUNT(*)
     FROM inventory i
     WHERE i.film_id = f.film_id) AS inventory_count,
	(SELECT COUNT(*)
     FROM inventory i
		INNER JOIN rental r
		ON i.inventory_id = r.inventory_id
     WHERE i.film_id = f.film_id) AS num_rentals
FROM film f;

##############################################################################################################################################################

-- joining partitioned data --

-- some database designs break up large tables into multiple pieces based on some element to improve performance
-- for example a payment table breaking up into payment_current and payment_historic
-- a view can be created that combines records from both those broken up tables if an end user needs current and historic
-- here in the CREATE VIEW before the AS, we are specifying what columns we want to bring to the view (all of them)

CREATE VIEW payment_all
	(payment_id,
     customer_id,
     staff_id,
     rental_id,
     amount,
     payment_date,
     last_update)
AS
SELECT 
	payment_id,
    customer_id,
    staff_id,
    rental_id,
    payment_date,
    last_update
FROM payment_current
UNION ALL 
SELECT 
	payment_id,
    customer_id,
    staff_id,
    rental_id,
    payment_date,
    last_update
FROM payment_current;

###### Updatable views ########################################################################################################################################

-- you can modify data with update statement as long as you follow certain restrictions
-- for mysql the following conditions allow for updating views:
		-- no aggregate functions used
        -- no goup by or having
        -- no subqueries exist 
        -- no unions or distinct
        -- the from clause includes at least one table or updatable view
        -- the from clause uses inner joins only if theres more than one table or view
        
-- updating simple views --

CREATE VIEW customer_vw
	(customer_id,
     first_name,
     last_name,
     email) AS 
SELECT
	customer_id,
    first_name,
    last_name,
    CONCAT(SUBSTR(email,1,2),"#####", SUBSTR(email, -4))
FROM customer;

-- we can modify data from a view that's not derived from an expression (like the concat email)	

UPDATE customer_vw
SET last_name = 'SMITH-ALLEN'
WHERE customer_id = 1;

-- and the change we make, effect the customer table our view derived from as well

SELECT customer_id, first_name, last_name
FROM customer
WHERE customer_id = 1;

-- but if we try to modify a derived column, it won't work

UPDATE customer_vw
SET email = 'MAY.SMITH-ALLEN@sakilacustomer.org'
WHERE customer_id = 1;

-- if a view has derived columns in it, you cannot insert data into the view, even if you're only trying to insert into the non derived columns

INSERT INTO customer_vw
	(customer_id, first_name, last_name)
VALUES
	(99999,'ROBERT', 'SIMPSON')
    
-- updating complex views --

-- this creates a view of multiple combined tables that provides a lot of information without the user having to query with joining

CREATE VIEW customer_details
AS
SELECT
	c.customer_id,
    c.store_id,
    c.first_name,
    c.last_name,
    c.address_id,
    c.active,
    c.create_date,
    a.address,
    ct.city,
    cn.country,
    a.postal_code
FROM customer c
	INNER JOIN address a
    ON c.address_id = a.address_id
	INNER JOIN city ct
    ON ct.city_id = a.city_id
    INNER JOIN country cn
    ON cn.country_id = ct.country_id
ORDER BY 1
    
-- this view can be used to update information from multiple tables

UPDATE customer_details
SET last_name = 'SMITH-ALLEN', active = 0
WHERE customer_id = 1

UPDATE customer_details
SET address = '999 Mockingbird Lane'
WHERE customer_id = 1

-- but if you try to make updates to multiple tables at once in a single view statement, if won't work

UPDATE customer_details
SET last_name = 'SMITH-ALLEN', 
	active = 0,
    address = '999 Mockingbird Lane'
WHERE customer_id = 1

-- the same rules apply to inserting new data into views instead of updating existing records
-- you can do an insert statement only if all the new values derived from the same column

###### exercise 1 #############################################################################################################################################

# create a view defiition that can be used by the follwoing query to generate the given results:

CREATE VIEW fawcett
AS
SELECT 
	f.title,
    c.name AS category_name,
    a.first_name,
    a.last_name
FROM film f
INNER JOIN film_actor fa
	ON f.film_id = fa.film_id
INNER JOIN film_category fc
	ON f.film_id = fc.film_id
INNER JOIN actor a
	ON fa.actor_id = a.actor_id
INNER JOIN category c
	ON fc.category_id = c.category_id
WHERE a.last_name = 'Fawcett'
ORDER BY a.first_name 

###### exercise 2 #############################################################################################################################################

# the film rental company manager would like to have a report that includes the name of every country
# along with the total payments for all customer who live in each country
# generate a view definition that queries the country table and uses a scaler subquery to calculate a value for a column named tot_payments

# these are two methods for the same results

# subquerying in the select clause allows you to have one less join and use the last join from country to city in the where clause
# i think since you're starting with the city table and working to payment instead of the other way around,
# there's a chance you don't get the correct aggregate sum amount if there's nulls
# if you start with a bigger table like payments and join your way down, you won't be inner joining out some of those records

SELECT
	country,
    SUM(amount) AS tot_payments
FROM
(SELECT 
	p.payment_id,
	p.customer_id,
    p.amount,
    cn.country
FROM payment p
INNER JOIN customer c
	ON p.customer_id = c.customer_id
INNER JOIN address a
	ON a.address_id = c.address_id
INNER JOIN city ct
	ON ct.city_id = a.city_id
INNER JOIN country cn
	ON cn.country_id = ct.country_id) a
GROUP BY 1
ORDER BY 2 DESC

##############################################################################################################################################################

SELECT
	cn.country,
    (SELECT SUM(p.amount)
	 FROM city ct
	 INNER JOIN address a
		ON a.city_id = ct.city_id
	 INNER JOIN customer c
		ON a.address_id = c.address_id
	 INNER JOIN payment p
		ON p.customer_id = c.customer_id
	 WHERE cn.country_id = ct.country_id) tot_payments
FROM country cn
ORDER BY 2 DESC
    
##############################################################################################################################################################