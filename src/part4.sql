CREATE DATABASE info_part4;

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


CREATE OR REPLACE FUNCTION fnc_gender(IN pgender VARCHAR DEFAULT 'female', IN page INTEGER DEFAULT 18) RETURNS INTEGER AS $$
SELECT COUNT(name)
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

CREATE OR REPLACE FUNCTION fnc_pizzeria_raiting(IN praiting NUMERIC) 
RETURNS TABLE (pizzeria_name VARCHAR, raiting NUMERIC) AS $$
SELECT pizzeria_name, raiting
FROM table_name_pizzeria
WHERE raiting >= praiting
$$ LANGUAGE SQL;

SELECT *
FROM fnc_pizzeria_raiting(4.5);

CREATE OR REPLACE FUNCTION fnc_trg_pizzeria_insert() RETURNS TRIGGER AS $pizzeria_insert$
	BEGIN
		IF NEW.raiting > 5.0
		THEN RAISE EXCEPTION 'The raiting cannot be higher than 5.0';
		END IF;
    RETURN NEW; 
    END;
$pizzeria_insert$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pizzeria_insert
BEFORE INSERT ON table_name_pizzeria
FOR EACH ROW 
EXECUTE FUNCTION fnc_trg_pizzeria_insert();

CREATE OR REPLACE FUNCTION fnc_trg_person_check_age() RETURNS TRIGGER AS $person_check_age$
	BEGIN
		IF NEW.age < 14
		THEN RAISE EXCEPTION 'The age must be over 14';
		END IF;
    RETURN NEW; 
    END;
$person_check_age$ LANGUAGE plpgsql;

CREATE TRIGGER trg_person_check_age
BEFORE INSERT ON person
FOR EACH ROW 
EXECUTE FUNCTION fnc_trg_person_check_age();

CREATE PROCEDURE insert_pizzeria(IN pname VARCHAR, IN praiting NUMERIC) AS $insert_pizzeria$
INSERT INTO table_name_pizzeria 
VALUES ((SELECT COALESCE (MAX(id)+1, 1) FROM table_name_pizzeria),
		pname,
		praiting);
$insert_pizzeria$ LANGUAGE SQL;

SELECT *
FROM table_name_pizzeria;

CALL insert_pizzeria ('NewYork Pizza', 4.4);


----------1) Создать хранимую процедуру, которая, не уничтожая базу данных, уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'table_name'.----------

CREATE OR REPLACE PROCEDURE drop_tables_table_name() AS $drop_tables$
	DECLARE 
		tablename NAME;
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
			JOIN pg_proc pr ON r.routine_name = pr.proname
			WHERE r.specific_schema = 'public' 
				AND routine_type = 'FUNCTION' AND proretset = 'false'
			GROUP BY routine_name
		LOOP
		count_functions := count_functions + 1;
		list_functions := concat(list_functions, function_name.list, '; ');
		END LOOP;	
	END;
$list_functions$ LANGUAGE plpgsql;

SELECT routine_name, string_agg(parameter_name, ', ')
FROM information_schema.routines r
JOIN information_schema.parameters p ON r.specific_name = p.specific_name
JOIN pg_proc pr ON r.routine_name = pr.proname
WHERE r.specific_schema = 'public' AND routine_type = 'FUNCTION' AND proretset = 'false'
GROUP BY routine_name;

CALL list_scalar_functions_and_parameters(NULL, NULL);

----------3) Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных. Выходной параметр возвращает количество уничтоженных триггеров.----------

CREATE OR REPLACE PROCEDURE drop_triggers (OUT count_triggers INTEGER)  AS $drop_triggers$
	DECLARE 
		triggername record;
		BEGIN
			count_triggers := 0;
			FOR triggername IN (SELECT trigger_name, event_object_table
								FROM information_schema.triggers)
			LOOP							
				EXECUTE concat('DROP TRIGGER IF EXISTS ', triggername.trigger_name, ' ON ', triggername.event_object_table, ' CASCADE;');
				count_triggers := count_triggers +1;
			END LOOP;
		END;
$drop_triggers$ LANGUAGE plpgsql;

SELECT trigger_name, event_object_table
FROM information_schema.triggers;

CALL drop_triggers(NULL);

----------4) Создать хранимую процедуру с входным параметром, которая выводит имена и описания типа объектов (только хранимых процедур и скалярных функций), в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.----------

CREATE OR REPLACE PROCEDURE output_names_and_descriptions_of_object_types (IN pstring TEXT, OUT poutput TEXT)  AS $names_and_descriptions$
	DECLARE 
		routinename record;
		BEGIN
			poutput = '';
			FOR routinename IN 
			SELECT concat(routine_name, ': ', routine_type) AS list
			FROM information_schema.routines r
			JOIN pg_proc pr ON r.routine_name = pr.proname
			WHERE routine_schema = 'public' 
				AND routine_definition LIKE concat('%', pstring, '%')
				AND external_language = 'SQL' 
				AND proretset = 'false'
			LOOP							
				poutput := concat(poutput, routinename.list, '; ');
			END LOOP;
		END;
$names_and_descriptions$ LANGUAGE plpgsql;

SELECT routine_name, routine_type
FROM information_schema.routines r
JOIN pg_proc pr ON r.routine_name = pr.proname
WHERE routine_schema = 'public'
	AND routine_definition LIKE '%table_name%'
	AND external_language = 'SQL' 
	AND proretset = 'false'

CALL output_names_and_descriptions_of_object_types('table_name', NULL);