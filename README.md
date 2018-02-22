# Postgres-Scripts
Various plpgsql routines

These scripts are mostly to demonstrate ideas, though they might have some utility in skilled hands :)

## pgrep

Sometimes you're troubleshooting a PostgreSQL-backed application, and trying to figure out where some piece of data came from.
If your application has hundreds of tables, it may take a while. Consider this approach though :

```sql
db=# create table some_obscure_table(a varchar, b varchar, c varchar);
CREATE TABLE
db=# insert into some_obscure_table values('stuff', 'this is a test', 'more stuff');
INSERT 0 1
db=# select * from pgrep('%', '%is a%', 100) as pgrep(table_name varchar, rowdata varchar);
        table_name         |                rowdata                
---------------------------+---------------------------------------
 public.some_obscure_table | (stuff,"this is a test","more stuff")
(1 row)

db=# 
```

Now you can find anything in your database :)

## sync_table

This is a precursor demonstrator to my https://github.com/xba1k/PgSynchronizer. It synchronizes two tables of the same structure. It might be useful during database experimentation, or perhaps can be used to build a larger server-side synchronization solution, especially when coupled with Foreign Data Wrappers.

```sql
db=# create table table1(a bigint, b varchar);
CREATE TABLE
db=# insert into table1 values(1, 'hello');
INSERT 0 1
db=# insert into table1 values(2, 'world');
INSERT 0 1
db=# insert into table1 values(3, 'foo');
INSERT 0 1
db=# insert into table1 values(4, 'bar');
INSERT 0 1
db=# create table table2 as select * from table1;
SELECT 4
db=# delete from table2;
DELETE 4
db=# select sync_table('table1', 'table2', 'a');
           sync_table            
---------------------------------
 4 inserts, 0 updates, 0 deletes
(1 row)

db=# delete from table1 where a = 3;
DELETE 1
db=# select sync_table('table1', 'table2', 'a');
           sync_table            
---------------------------------
 0 inserts, 0 updates, 1 deletes
(1 row)

db=# update table1 set b = 'folks' where a = 2;
UPDATE 1
db=# select sync_table('table1', 'table2', 'a');
           sync_table            
---------------------------------
 1 inserts, 0 updates, 1 deletes
(1 row)

db=# select sync_table('table1', 'table2', 'a');
           sync_table            
---------------------------------
 0 inserts, 0 updates, 0 deletes
(1 row)

db=# update table1 set b = 'world' where a = 2;
UPDATE 1
db=# select sync_table('table1', 'table2', 'a');
           sync_table            
---------------------------------
 0 inserts, 1 updates, 0 deletes
(1 row)

db=# select * from table1;
 a |   b   
---+-------
 1 | hello
 4 | bar
 2 | world
(3 rows)

db=# select * from table2;
 a |   b   
---+-------
 1 | hello
 4 | bar
 2 | world
(3 rows)

db=# 
```

Obviously it takes a naive approach, given it's only an idea demonstrator, but you can extend it using some techniques from PgSynchronizer (such as PK and CTID handling).
