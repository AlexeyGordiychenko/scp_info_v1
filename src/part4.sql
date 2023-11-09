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


CREATE OR REPLACE FUNCTION fnc_gender(IN pgender VARCHAR DEFAULT 'female', IN page INTEGER DEFAULT 18) RETURNS SETOF person AS $$
SELECT *
FROM person
WHERE gender = pgender AND age >= page;
$$ LANGUAGE SQL;

SELECT *
FROM fnc_gender(pgender := 'male', page := 15);

CREATE OR REPLACE FUNCTION fnc_menu_price(IN pname VARCHAR DEFAULT 'cheese pizza') RETURNS NUMERIC AS $$
SELECT price 
FROM table_name_menu
WHERE pizza_name = pname;
$$ LANGUAGE SQL;

SELECT *
FROM fnc_menu_price();

CREATE OR REPLACE FUNCTION fnc_pizzeria_min_raiting() RETURNS NUMERIC AS $$
SELECT MIN(raiting)
FROM table_name_pizzeria
$$ LANGUAGE SQL;

SELECT *
FROM fnc_pizzeria_min_raiting();

----------1) Создать хранимую процедуру, которая, не уничтожая базу данных, уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'table_name'.----------

CREATE OR REPLACE PROCEDURE drop_tables_table_name() AS $drop_tables$
	DECLARE tablename NAME;
		BEGIN
			FOR tablename IN (SELECT table_name
									FROM information_schema.tables
									WHERE table_name LIKE 'table_name%')
			LOOP							
			EXECUTE concat('DROP TABLE IF EXISTS ', tablename, ' CASCADE;');
			END LOOP;
		END;
$drop_tables$ LANGUAGE plpgsql;

SELECT table_name 
FROM information_schema.tables
WHERE table_name LIKE 'table_name%';

CALL drop_tables_table_name();

----------2) Создать хранимую процедуру с выходным параметром, которая выводит список имен и параметров всех скалярных SQL функций пользователя в текущей базе данных. Имена функций без параметров не выводить. Имена и список параметров должны выводиться в одну строку. Выходной параметр возвращает количество найденных функций.----------

CREATE OR REPLACE PROCEDURE list_scalar_functions_and_parameters 
								(OUT count_functions INTEGER,
								OUT list_functions TEXT)  AS $list_functions$
DECLARE
	function_name record;
	BEGIN
		list_functions = '';
		count_functions := 0;
		FOR function_name IN
		SELECT concat(routine_name, ': ', string_agg(parameter_name, ', ')) AS list
			FROM information_schema.routines r
			JOIN information_schema.parameters p ON r.specific_name = p.specific_name
			WHERE r.specific_schema = 'public' AND routine_type = 'FUNCTION'
			GROUP BY routine_name
		LOOP
		count_functions := count_functions + 1;
		list_functions := concat(list_functions, function_name.list, '; ');
		END LOOP;	
	END;
$list_functions$ LANGUAGE plpgsql;

CALL list_scalar_functions_and_parameters(NULL, NULL);