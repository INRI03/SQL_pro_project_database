Задание 1.
-Используя запросы из презентации создайте базу данных магазина по продаже цветов
-Проанализируйте, все ли отношения и атрибуты удовлетворяют требованиям
-Добавьте все необходимые связи между отношениями / атрибутами
И тут позвонил Заказчик. В разработку запустили интернет магазин.
Задание 2.
-Масштабируйте существующую базу используя вертикальный шардинг, добавив возможность хранения информации с интернет магазина:

создайте необходимые отношения (пользователь, заказ)
создайте необходимые атрибуты
создайте необходимые связи
создайте подключение к удаленному серверу используя postgres_fdw и сделайте возможность работы с данными на основном сервере (три запроса на получение данных и 2 запроса на модификацию данных).
Дополнительное задание:
-Напишите необходимые функции и триггеры для автоматизации работы с данными (творческое задание).


--Задание 1
```sql
create schema flowers

set search_path to flowers

create table products(
product_id serial primary key,
product_name varchar(50) not null unique,
product_amount decimal(10, 2) not null,
--product_color varchar(30) not null -- цвет товара выносить в отдельный атрибут не стоит, лучше сделать на каждый цвет отдельный id
product_count int not null
)

create table expenses( --таблица расходов не будет иметь связей с другими таблицами, часть данных в нее будет вноситься по триггерам
expense_id serial primary key,
expense_name varchar(50) not null,
expense_amount decimal(10, 2) not null,
expense_date timestamp not null default now()-- нужно добавить атрибут "дата расхода"
)


create table workers(
worker_id serial primary key,
last_name varchar(50) not null,
first_name varchar(30) not null,
--age integer not null, -- атрибут "возраст" в таблице работников не имеет смысла, вряд ли он может пригодиться в данной базе
salary decimal(10, 2) not null,
address varchar(100) not null,
phone varchar(15) not null -- атрибут "контактный телефон" может пригодиться
)

create table purchases( --добавляем еще 2 товара на случай, если в закупке будет несколько товаров, а не один
purchase_id serial primary key,
product_1 int not null references products(product_id), -- создаем ключ для связки с товарами
amount_1 decimal(10, 2) not null, -- как минимум один товар будет в закупке, поэтому атрибуты первого товара обязательно not null
--purchase_color varchar(30) not null, -- убираем цвет, посколько в "товарах" я захотел сделать на каждый цвет отдельный id
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
--order_product json not null, -- вместо json лучше использовать разбивку на отдельные атрибуты, чтоб создать внешний ключ на id продукта
product_1 int not null references products(product_id), -- как минимум один товар будет в заказе, поэтому первый обязательно not null
count_1 int not null,
product_2 int references products(product_id),
count_2 int,
product_3 int references products(product_id),
count_3 int, -- трех продуктов пока достаточно, в противном случае можно создать отдельный id покупки и прописать это в комментарии, это всяко лучше чем json
order_address text not null,
worker_id int not null references workers(worker_id), -- добавляем атрибут id работника для связки с таблицей работников
any_comment text --поле с комментарием всегда нужно, мало ли что потребуется прописать дополнительно
)

create table payments(
payment_id serial primary key,
payment_amount decimal(10, 2) not null,
payment_date timestamp default now(),
order_id int not null references orders(order_id), -- добавляем id заказа для связки с заказами
tax_amount decimal(10, 2) -- также будет информация по уплаченному налогу
)
```


--Задание 2

```sql
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

create table first_order_user( -- вертикальный шардинг, в этой таблице будут самые важные данные, в second - все остальное
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

create or replace function foo1() returns trigger as $$ --разносим по обеим таблицам более важные и менее важные данные
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
```

--Запросы на получение данных из удаленной базы
```sql
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
```

--Дополнительное задание
```sql
create or replace function update_product_count() returns trigger as $$ -- функция для обновления количества товара на складе после продаж
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


create or replace function update_product_count_2() returns trigger as $$ -- функция для обновления количества товара на складе после закупок
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


create or replace function update_product_amount() returns trigger as $$ --функция для установки отгрузочной цены товара на складе, исходя из последней закупки, с наценкой 30%
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


create or replace function insert_expenses_purchases() returns trigger as $$ --функция для внесения данных в таблицу расходов, исходя из затрат на закупки
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


create or replace function insert_expenses_tax() returns trigger as $$ --функция для внесения данных в таблицу расходов по сумме налога
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
```
