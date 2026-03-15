-- №1 

select * 
from products
where year between '2015' and '2019';

-- №2

select *
from dealerships 
where city in ('Houston', 'Dallas', 'Austin');

-- №3

create table old_stock as 
select 
product_id as old_stock_id,
model,
year,
product_type,
base_msrp,
production_start_date,
production_end_date
from products
where year < 2020;

alter table old_stock
add column discount numeric(3,1);

update old_stock
set discount = 0.5;

delete from old_stock
where base_msrp > 20000.00;

select *
from old_stock;


