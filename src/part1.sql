----------Cоздание базы данных----------
CREATE DATABASE school21;

----------Cоздание таблиц----------
CREATE TABLE peers
(
	nickname VARCHAR UNIQUE PRIMARY KEY,
	birthday DATE NOT NULL
);
CREATE TABLE tasks
(
	title VARCHAR UNIQUE PRIMARY KEY,
	parent_task VARCHAR REFERENCES tasks,
	max_xp INT NOT NULL
);
CREATE TABLE checks
(
	id BIGINT PRIMARY KEY,
	peer VARCHAR NOT NULL REFERENCES peers,
	task VARCHAR NOT NULL REFERENCES tasks,
	date DATE NOT NULL
);

----------Создание типа перечисления----------
CREATE TYPE check_status as ENUM ('Start', 'Success', 'Failure');

CREATE TABLE p2p
(
	id BIGINT PRIMARY KEY,
	"check" BIGINT NOT NULL REFERENCES checks,
	checking_peer VARCHAR NOT NULL REFERENCES peers,
	state check_status NOT NULL,
	time TIME NOT NULL
);
CREATE TABLE verter
(
	id BIGINT PRIMARY KEY,
	"check" BIGINT NOT NULL REFERENCES checks,
	state check_status NOT NULL,
	time TIME NOT NULL
);
CREATE TABLE transferred_points
(
	id BIGINT PRIMARY KEY,
	checking_peer VARCHAR NOT NULL REFERENCES peers,
	checked_peer VARCHAR NOT NULL REFERENCES peers,
	points_amount INTEGER NOT NULL
);
CREATE TABLE friends
(
	id BIGINT PRIMARY KEY,
	peer1 VARCHAR NOT NULL REFERENCES peers,
	peer2 VARCHAR NOT NULL REFERENCES peers
);
CREATE TABLE recommendations
(
	id BIGINT PRIMARY KEY,
	peer VARCHAR NOT NULL REFERENCES peers,
	recommended_peer VARCHAR NOT NULL REFERENCES peers
);
CREATE TABLE xp
(
	id BIGINT PRIMARY KEY,
	"check" BIGINT NOT NULL REFERENCES checks,
	xp_amount INTEGER NOT NULL
);
CREATE TABLE time_tracking
(
	id BIGINT PRIMARY KEY,
	peer VARCHAR NOT NULL REFERENCES peers,
	date DATE NOT NULL,
	time TIME NOT NULL,
	state INTEGER NOT NULL CHECK (state IN (1, 2))
);

----------Cоздание ограничений для таблиц----------

----------В таблице p2p не может быть больше одной незавершенной P2P проверки, относящейся к конкретному заданию, пиру и проверяющему----------

CREATE OR REPLACE FUNCTION fnc_trg_p2p_insert() RETURNS TRIGGER AS $p2p_insert$
	BEGIN
		IF NEW.state = 'Start' THEN
			IF (SELECT state
				FROM p2p
				WHERE "check" = NEW."check"
				ORDER BY id DESC
				LIMIT 1) = 'Start'
			THEN RAISE EXCEPTION 'The check already has the Start status';
			ELSEIF (SELECT state
					FROM p2p
					WHERE "check" = NEW."check"
					ORDER BY id DESC
					LIMIT 1) IN ('Success', 'Failure')
			THEN RAISE EXCEPTION 'The check has already been completed';
			END IF;	
			IF (SELECT state
				FROM p2p
				WHERE checking_peer = NEW.checking_peer 
				ORDER BY id DESC
				LIMIT 1) = 'Start'		
			THEN RAISE EXCEPTION 'The peer checks another project';
			END IF;
		END IF;	
		IF NEW.state IN ('Success', 'Failure') THEN
			IF (SELECT state
				FROM p2p
				WHERE "check" = NEW."check"
				ORDER BY id DESC
				LIMIT 1) IN ('Success', 'Failure')
			THEN RAISE EXCEPTION 'The check has already been completed';
			END IF;
			IF NOT EXISTS (SELECT *
						   FROM p2p
						   WHERE "check" = NEW."check")
			THEN RAISE EXCEPTION 'Tne check cannot be completed earlier than it started';
			ELSIF NEW.time <= (SELECT time
							   FROM p2p
							   WHERE "check" = NEW."check") 
			THEN RAISE EXCEPTION 'Tne check cannot be completed earlier than it started';
			END IF;	
			IF NEW.checking_peer != (SELECT checking_peer
									 FROM p2p
									 WHERE "check" = NEW."check")
			THEN RAISE EXCEPTION 'Tne checking_peer does not match the one who started the check';
			END IF;
		END IF;
		IF NEW.checking_peer = (SELECT peer
								FROM checks
								WHERE id = NEW."check")
		THEN RAISE EXCEPTION 'The peer cannot check himself';
		END IF;						
	RETURN NEW;
	END;
$p2p_insert$ LANGUAGE plpgsql;

CREATE TRIGGER trg_p2p_insert
BEFORE INSERT ON p2p
FOR EACH ROW 
EXECUTE FUNCTION fnc_trg_p2p_insert();


----------Проверка Verter'ом может ссылаться только на те проверки в таблице Checks, которые уже включают в себя успешную P2P проверку----------
CREATE OR REPLACE FUNCTION fnc_trg_verter_insert() RETURNS TRIGGER AS $verter_insert$
	BEGIN
		IF NEW."check" NOT IN (SELECT checks.id 
							   FROM checks
							   JOIN p2p ON checks.id = p2p."check"
							   WHERE state = 'Success')
		THEN RAISE EXCEPTION 'This check did not pass the peer review';
		END IF;
		IF NEW.state = 'Start' THEN
			IF (SELECT state
					FROM verter
					WHERE "check" = NEW."check"
					ORDER BY id DESC
					LIMIT 1) = 'Start'
			THEN RAISE EXCEPTION 'The check already has the Start status';
			ELSEIF (SELECT state
					FROM verter
					WHERE "check" = NEW."check"
					ORDER BY id DESC
					LIMIT 1) IN ('Success', 'Failure')
			THEN RAISE EXCEPTION 'The check has already been completed';
			END IF;
		END IF;		
		IF NEW.state IN ('Success', 'Failure') THEN
			IF (SELECT state
				FROM verter
				WHERE "check" = NEW."check"
				ORDER BY id DESC
				LIMIT 1) IN ('Success', 'Failure')
			THEN RAISE EXCEPTION 'The check has already been completed';
			END IF;
			IF NOT EXISTS (SELECT *
						   FROM verter
						   WHERE "check" = NEW."check")
			THEN RAISE EXCEPTION 'Tne check cannot be completed earlier than it started';
			ELSIF NEW.time <= (SELECT time
					   		FROM verter
					   		WHERE "check" = NEW."check") 
			THEN RAISE EXCEPTION 'Tne check cannot be completed earlier than it started';
			END IF;
		END IF;					
	RETURN NEW;
	END;
$verter_insert$ LANGUAGE plpgsql;

CREATE TRIGGER trg_verter_insert
BEFORE INSERT ON verter
FOR EACH ROW 
EXECUTE FUNCTION fnc_trg_verter_insert();

----------Индекс для обеспечения уникальности пар в таблице transferred_points----------
CREATE UNIQUE INDEX idx_transferred_points ON transferred_points(checking_peer, checked_peer);

----------В таблице time_tracking в течение одного дня должно быть одинаковое количество записей с состоянием 1 и состоянием 2 для каждого пира----------

CREATE VIEW last_date AS
(SELECT DISTINCT date
FROM time_tracking
ORDER BY date DESC
LIMIT 1);

CREATE OR REPLACE FUNCTION fnc_trg_time_tracking() RETURNS TRIGGER AS $time_tracking$
	BEGIN
		IF NEW.date > (SELECT * FROM last_date) THEN
			IF (SELECT count(state)
				FROM time_tracking
				WHERE state = 1 AND "date" = (SELECT * FROM last_date)) >
				(SELECT count(state)
				FROM time_tracking
				WHERE state = 2 AND "date" = (SELECT * FROM last_date))
			THEN RAISE EXCEPTION 'Not all peers have gone home %', (SELECT * FROM last_date);
			END IF;
		END IF;
		IF NEW.state = 2 THEN 
			IF NOT EXISTS (SELECT *
						  FROM time_tracking
						  WHERE peer = NEW.peer AND date = NEW.date AND state = 1)	
			THEN RAISE EXCEPTION 'This peer has not entered the campus yet';
			END IF;
			IF NEW.time < (SELECT time 
			FROM time_tracking
			WHERE peer = NEW.peer AND date = NEW.date AND state = 1
			ORDER BY time DESC
			LIMIT 1)
			THEN RAISE EXCEPTION 'The exit time cannot be less than the entry time';
			END IF;
		END IF;	
	RETURN NEW;
	END;
$time_tracking$ LANGUAGE plpgsql;

CREATE TRIGGER trg_time_tracking
BEFORE INSERT ON time_tracking
FOR EACH ROW 
EXECUTE FUNCTION fnc_trg_time_tracking();

----------Процедуры, позволяющие импортировать и экспортировать данные для каждой таблицы из файла/в файл с расширением .csv----------

CREATE OR REPLACE PROCEDURE import_data 
	(IN table_name VARCHAR, IN file_path TEXT, IN separator CHAR) AS $import$
		BEGIN
			EXECUTE format('COPY %s FROM ''%s'' DELIMITER ''%s'' CSV HEADER;', table_name, file_path, separator);
		END;
$import$ LANGUAGE plpgsql;			
CREATE OR REPLACE PROCEDURE export_data 
	(IN table_name VARCHAR, IN file_path TEXT, IN separator CHAR) AS $import$
		BEGIN
			EXECUTE format('COPY %s TO ''%s'' DELIMITER ''%s'' CSV HEADER;', table_name, file_path, separator);
		END;
$import$ LANGUAGE plpgsql;		

----------Заполнение таблиц----------

CALL import_data ('peers', '/tmp/peers.csv', ',');
CALL import_data ('tasks', '/tmp/tasks.csv', ',');
CALL import_data ('checks', '/tmp/checks.csv', ',');
CALL import_data ('p2p', '/tmp/p2p.csv', ',');
CALL import_data ('verter', '/tmp/verter.csv', ',');
CALL import_data ('transferred_points', '/tmp/transferred_points.csv', ',');
CALL import_data ('friends', '/tmp/friends.csv', ',');
CALL import_data ('recommendations', '/tmp/recommendations.csv', ',');
CALL import_data ('xp', '/tmp/xp.csv', ',');
CALL import_data ('time_tracking', '/tmp/time_tracking.csv', ',');