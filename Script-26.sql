--������� 1

create schema flowers


set search_path to flowers

create table products(
product_id serial primary key,
product_name varchar(50) not null unique,
product_amount decimal(10, 2) not null,
--product_color varchar(30) not null -- ���� ������ �������� � ��������� ������� �� �����, ����� ������� �� ������ ���� ��������� id
product_count int not null
)

create table expenses( --������� �������� �� ����� ����� ������ � ������� ���������, ����� ������ � ��� ����� ��������� �� ���������
expense_id serial primary key,
expense_name varchar(50) not null,
expense_amount decimal(10, 2) not null,
expense_date timestamp not null default now()-- ����� �������� ������� "���� �������"
)


create table workers(
worker_id serial primary key,
last_name varchar(50) not null,
first_name varchar(30) not null,
--age integer not null, -- ������� "�������" � ������� ���������� �� ����� ������, ���� �� �� ����� ����������� � ������ ����, ����� ���
salary decimal(10, 2) not null,
address varchar(100) not null,
phone varchar(15) not null -- ������� "���������� �������" ����� �����������, ������� ���
)

create table purchases( --��������� ��� 2 ������ �� ������, ���� � ������� ����� ��������� �������, � �� ����
purchase_id serial primary key,
product_1 int not null references products(product_id), -- ������� ���� ��� ������ � �������� 
amount_1 decimal(10, 2) not null, -- ��� ������� ���� ����� ����� � �������, ������� �������� ������� ������ ����������� not null
--purchase_color varchar(30) not null, -- ������� ����, ��������� � "�������" � ������� ������� �� ������ ���� ��������� id
count_1 int not null,
product_2 int references products(product_id),
amount_2 decimal(10, 2),
count_2 int,
product_3 int references products(product_id),
amount_3 decimal(10, 2),
count_3 int,
payment_date timestamp not null default now()
)

create table orders(
order_id serial primary key,
--order_product json not null, -- ������ json ����� ������������ �������� �� ��������� ��������, ���� ������� ������� ���� �� id ��������
product_1 int not null references products(product_id), -- ��� ������� ���� ����� ����� � ������, ������� ������ ����������� not null
count_1 int not null, 
product_2 int references products(product_id),
count_2 int,
product_3 int references products(product_id),
count_3 int, -- ���� ��������� ���� ����������, � ��������� ������ ����� ������� ��������� id ������� � ��������� ��� � �����������, ��� ����� ����� ��� json
order_address text not null,
worker_id int not null references workers(worker_id), -- ��������� ������� id ��������� ��� ������ � �������� ����������
any_comment text --���� � ������������ ������ �����, ���� �� ��� ����������� ��������� �������������
)

create table payments(
payment_id serial primary key,
payment_amount decimal(10, 2) not null,
payment_date timestamp default now(),
order_id int not null references orders(order_id), -- ��������� id ������ ��� ������ � ��������
tax_amount decimal(10, 2) -- ����� ����� ���������� �� ����������� ������
)



--������� 2


create schema remote_flowers 

set search_path to remote_flowers


create table users(
user_id int primary key,
last_name varchar(30) not null,
first_name varchar(30) not null,
email varchar(30) not null,
phone varchar(15) not null
)

create table orders(
order_id serial primary key,
user_id int not null references users(user_id),
product_1 int not null,
count_1 int not null, 
product_2 int,
count_2 int,
product_3 int,
count_3 int, 
worker_id int not null,
any_comment text
)


set search_path to flowers

create extension postgres_fdw


create server remote_flowers
foreign data wrapper postgres_fdw
options (host 'localhost', port '5432', dbname 'postgres')

create user mapping for postgres
server remote_flowers
options (user 'postgres', password '5012003vvv')


create foreign table remote_users(
user_id int,
last_name varchar(30),
first_name varchar(30),
email varchar(30),
phone varchar(15)
)
server remote_flowers
options (schema_name 'remote_flowers', table_name 'users')

create foreign table remote_orders(
order_id int,
user_id int,
product_1 int,
count_1 int, 
product_2 int,
count_2 int,
product_3 int,
count_3 int,
worker_id int,
any_comment text
)
server remote_flowers
options (schema_name 'remote_flowers', table_name 'orders')

create table first_order_user( -- ������������ �������, � ���� ������� ����� ����� ������ ������, � second - ��� ���������
order_id int not null,
user_id int not null,
worker_id int not null,
any_comment text,
constraint pkey primary key (order_id, user_id)
)

create table second_order_user(
order_id int primary key, 
product_1 int not null,
count_1 int not null, 
product_2 int,
count_2 int,
product_3 int,
count_3 int, 
user_last_name varchar(30) not null,
user_first_name varchar(30) not null,
user_email varchar(30) not null,
user_phone varchar(15) not null
)

create or replace function foo1() returns trigger as $$ --�������� �� ����� �������� ����� ������ � ����� ������ ������
begin
	insert into first_order_user values	(new.order_id, new.user_id,	new.worker_id, new.any_comment);
	insert into second_order_user values
		(new.order_id, new.product_1, new.count_1, new.product_2, new.count_2, new.product_3, new.count_3,
		(select last_name, first_name, email, phone from remote_users where user_id = new.user_id));
end;
$$ language plpgsql

create trigger insert_user
after insert on remote_orders
for each row execute function foo1()


--������� �� ��������� ������ �� ��������� ����

select user_id, phone
from remote_users
where user_id between '100' and '130' and first_name = 'Kate'

select order_id, user_id, any_comment
from remote_orders
where product_2 is not null and product_3 is not null

select order_id, ro.user_id
from remote_orders ro
join remote_users ru on ru.user_id = ro.user_id
where any_comment is not null and length(any_comment) < 20


--������� �� ����������� ������ �� ��������� ����

alter table remote_users alter column email type varchar(40)

alter table remote_orders add column order_date timestamp default (now() - interval '2 minutes')
-- ����� ���� ��������, � �� ���� ������ � �����, ������ ��� �� ��������. ��� ������ ������� �� ����������� � ��������� remote_users
-- � ������� users �� ������� remote_flowers, ������� ��� ��������� ���� ������� ���� ������, ����� ���� �� ����������. �������������
-- ������ �� ��������. �� ������� ������� �� ����������� � ��������� remote_orders ���� �� ����������� ������. � ��������� ����� ������� 
-- remote_orders ���������� ���� order_date, � ��� �������� �� ������� "������" ����� "������: ������� "order_date" �� ����������."
-- ����� ��� � � ������� orders ���������� ������� remote_flowers ���� ������ �� ����������. ��� � ����� �� ���? ������ ��������.


--�������������� �������

create or replace function update_product_count() returns trigger as $$ -- ������� ��� ���������� ���������� ������ �� ������ ����� ������
begin
	update products set product_count = product_count - new.count_1
		where product_id = new.product_1;
	if new.count_2 is not null
		then update products set product_count = product_count - new.count_2
		where product_id = new.product_2;
	elseif new.count_3 is not null
		then update products set product_count = product_count - new.count_3
		where product_id = new.product_3;
	end if;
end;
$$ language plpgsql

create trigger prod_count
after insert on orders 
for each row execute function update_product_count()



create or replace function update_product_count_2() returns trigger as $$ -- ������� ��� ���������� ���������� ������ �� ������ ����� �������
begin
	update products set product_count = product_count - new.count_1
		where product_id = new.product_1;
	if new.count_2 is not null
		then update products set product_count = product_count - new.count_2
		where product_id = new.product_2;
	elseif new.count_3 is not null
		then update products set product_count = product_count - new.count_3
		where product_id = new.product_3;
	end if;
end;
$$ language plpgsql

create trigger prod_count_2
after insert on purchases
for each row execute function update_product_count_2()


create or replace function update_product_amount() returns trigger as $$ --������� ��� ��������� ����������� ���� ������ �� ������, ������ �� ��������� �������, � �������� 30%
begin 
	update products set product_amount = new.amount_1 * 1.3
		where product_id = new.product_1;
	if new.amount_2 is not null
		then update products set product_amount = new.amount_2 * 1.3
		where product_id = new.product_2;
	elseif new.amount_3 is not null
		then update products set product_amount = new.amount_3 * 1.3
		where product_id = new.product_3;
	end if;
end;
$$ language plpgsql

create trigger prod_amount
after insert on purchases
for each row execute function update_product_amount()


create or replace function insert_expenses_purchases() returns trigger as $$ --������� ��� �������� ������ � ������� ��������, ������ �� ������ �� �������
begin 
	insert into expenses(expense_name, expense_amount) values ('purchase' || ' ' || new.purchase_id, new.amount_1 * new.count_1);
	if new.amount_2 is not null
		then insert into expenses(expense_name, expense_amount) values ('purchase' || ' ' || new.purchase_id, new.amount_2 * new.count_2);
	elseif new.amount_3 is not null
		then insert into expenses(expense_name, expense_amount) values ('purchase' || ' ' || new.purchase_id, new.amount_3 * new.count_3);
    end if;
end;
$$ language plpgsql

create trigger expenses_purchases
after insert on purchases
for each row execute function insert_expenses_purchases()


create or replace function insert_expenses_tax() returns trigger as $$ --������� ��� �������� ������ � ������� �������� �� ����� ������
begin 
	insert into expenses(expense_name, expense_amount) values
	('tax from payment' || ' ' || (select payment_id from payments where tax_amount = new.tax_amount), new.tax_amount);
	end;
$$ language plpgsql

create trigger expenses_tax
after insert on payments
for each row
when (new.tax_amount is not null)
execute function insert_expenses_tax()

