CREATE DATABASE info21_part4;

CREATE TABLE person
(
	id BIGINT PRIMARY KEY,
	name VARCHAR NOT NULL,
	age INTEGER NOT NULL,
	gender VARCHAR NOT NULL
);
CREATE TABLE table_name_menu
(
	id BIGINT PRIMARY KEY,
	pizza_name VARCHAR NOT NULL,
	price NUMERIC NOT NULL
);
CREATE TABLE table_name_pizzeria
(
	id BIGINT PRIMARY KEY,
	pizzeria_name VARCHAR NOT NULL,
	raiting NUMERIC NOT NULL
);

CREATE OR REPLACE PROCEDURE import_data 
	(IN table_name VARCHAR, IN file_path TEXT, IN separator CHAR) AS $import$
		BEGIN
			EXECUTE format('COPY %s FROM ''%s'' DELIMITER ''%s'' CSV HEADER;', table_name, file_path, separator);
		END;
$import$ LANGUAGE plpgsql;	

CALL import_data ('person', '/tmp/person.csv', ',');
CALL import_data ('table_name_menu', '/tmp/table_name_menu.csv', ',');
CALL import_data ('table_name_pizzeria', '/tmp/table_name_pizzeria.csv', ',');

----------1) Создать хранимую процедуру, которая, не уничтожая базу данных, уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'table_name'.----------

CREATE OR REPLACE PROCEDURE drop_tables_table_name() AS $drop_tables$
	DECLARE tablename NAME;
		BEGIN
			FOR tablename IN (SELECT table_name
									FROM information_schema.tables
									WHERE table_name LIKE 'table_name%')
			LOOP							
			EXECUTE concat('DROP TABLE IF EXISTS ', table_name_drop, ' CASCADE;');
			END LOOP;
		END;
$drop_tables$ LANGUAGE plpgsql;

SELECT table_name 
FROM information_schema.tables
WHERE table_name LIKE 'table_name%';

CALL drop_table_table_name();