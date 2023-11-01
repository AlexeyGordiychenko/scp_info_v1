----------Cоздание базы данных----------
CREATE DATABASE school21;

----------Cоздание таблиц----------
CREATE TABLE peers
(
	nickname VARCHAR PRIMARY KEY,
	birthday DATE NOT NULL
);
CREATE TABLE tasks
(
	title VARCHAR PRIMARY KEY,
	parent_task VARCHAR REFERENCES tasks,
	max_xp INT NOT NULL
);
CREATE TABLE checks
(
	id SERIAL PRIMARY KEY,
	peer VARCHAR NOT NULL REFERENCES peers,
	task VARCHAR NOT NULL REFERENCES tasks,
	date DATE NOT NULL
);

----------Создание типа перечисления----------
CREATE TYPE check_status as ENUM ('Start', 'Success', 'Failure');

CREATE TABLE p2p
(
	id SERIAL PRIMARY KEY,
	"check" BIGINT NOT NULL REFERENCES checks,
	checking_peer VARCHAR NOT NULL REFERENCES peers,
	state check_status NOT NULL,
	time TIME NOT NULL
);

CREATE TABLE verter
(
	id SERIAL PRIMARY KEY,
	"check" BIGINT NOT NULL REFERENCES checks,
	state check_status NOT NULL,
	time TIME NOT NULL
);

CREATE TABLE transferred_points
(
	id SERIAL PRIMARY KEY,
	checking_peer VARCHAR NOT NULL REFERENCES peers,
	checked_peer VARCHAR NOT NULL REFERENCES peers,
	points_amount INTEGER DEFAULT 0 NOT NULL
);
CREATE TABLE friends
(
	id SERIAL PRIMARY KEY,
	peer1 VARCHAR NOT NULL REFERENCES peers,
	peer2 VARCHAR NOT NULL REFERENCES peers
);
CREATE TABLE recommendations
(
	id SERIAL PRIMARY KEY,
	peer VARCHAR NOT NULL REFERENCES peers,
	recommended_peer VARCHAR DEFAULT 0 NOT NULL REFERENCES peers
);
CREATE TABLE xp
(
	id SERIAL PRIMARY KEY,
	"check" BIGINT NOT NULL REFERENCES checks,
	xp_amount INTEGER NOT NULL
);
CREATE TABLE time_tracking
(
	id SERIAL PRIMARY KEY,
	peer VARCHAR NOT NULL REFERENCES peers,
	date DATE NOT NULL,
	time TIME NOT NULL,
	state CHAR NOT NULL
);

----------Cоздание ограничений для таблиц----------

----------В таблице p2p не может быть больше одной незавершенной P2P проверки, относящейся к конкретному заданию, пиру и проверяющему----------
CREATE OR REPLACE FUNCTION fnc_time_p2p(IN pcheck BIGINT, IN ppeer VARCHAR)
RETURNS TIME AS $time_p2p$
BEGIN
	RETURN time
	FROM
	(SELECT checking_peer, time
	 FROM
	 (SELECT *
	  FROM p2p
	  WHERE "check" IN (SELECT id
				  		FROM checks
				  		WHERE date = (SELECT DISTINCT date
									  FROM p2p
									  JOIN checks ON "check" = checks.id
									  WHERE "check" = pcheck)))
	 WHERE state != 'Start'	)
	WHERE checking_peer = ppeer
	ORDER BY time DESC
	LIMIT 1;	
END;
$time_p2p$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION fnc_trg_p2p_insert_update() RETURNS TRIGGER AS $p2p_insert_update$
	BEGIN
		IF NEW.state = 'Start' THEN
			IF (SELECT count(state)
				FROM p2p
				WHERE "check" = NEW."check" AND state = 'Start') > 
				(SELECT count(state)
				 FROM p2p
				 WHERE "check" = NEW."check" AND state != 'Start')
			THEN RAISE EXCEPTION 'The check already has the Start status';
			ELSEIF EXISTS (SELECT *
						   FROM p2p
						   WHERE "check" = NEW."check" AND state != 'Start')
			THEN RAISE EXCEPTION 'The check has already been completed';
			END IF;
			IF NEW.time <= (SELECT *
							FROM fnc_time_p2p(pcheck := NEW.check, ppeer := NEW.checking_peer))
			THEN RAISE EXCEPTION 'The peer checks another project';
			END IF;
		END IF;	
		IF NEW.state IN ('Success', 'Failure') THEN
			IF EXISTS (SELECT *
				 	   FROM p2p
				 	   WHERE "check" = NEW."check" AND state != 'Start')
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
$p2p_insert_update$ LANGUAGE plpgsql;

CREATE TRIGGER trg_p2p_insert_update
BEFORE INSERT OR UPDATE ON p2p
FOR EACH ROW 
EXECUTE FUNCTION fnc_trg_p2p_insert_update();

----------Проверка Verter'ом может ссылаться только на те проверки в таблице Checks, которые уже включают в себя успешную P2P проверку----------
CREATE OR REPLACE FUNCTION fnc_trg_verter_insert_update() RETURNS TRIGGER AS $verter_insert_update$
	BEGIN
		IF NEW."check" NOT IN (SELECT checks.id 
							   FROM checks
							   JOIN p2p ON checks.id = p2p."check"
							   WHERE state = 'Success')
		THEN RAISE EXCEPTION 'This check did not pass the peer review';
		END IF;
		IF NEW.state = 'Start' THEN
			IF (SELECT count(state)
				FROM verter
				WHERE "check" = NEW."check" AND state = 'Start') > 
				(SELECT count(state)
				 FROM verter
				 WHERE "check" = NEW."check" AND state != 'Start')
			THEN RAISE EXCEPTION 'The check already has the Start status';
			ELSEIF EXISTS (SELECT *
						   FROM verter
						   WHERE "check" = NEW."check" AND state != 'Start')
			THEN RAISE EXCEPTION 'The check has already been completed';
			END IF;
		END IF;	
		IF NEW.state IN ('Success', 'Failure') THEN
			IF EXISTS (SELECT *
				 	   FROM verter
				 	   WHERE "check" = NEW."check" AND state != 'Start')
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
$verter_insert_update$ LANGUAGE plpgsql;

CREATE TRIGGER trg_verter_insert_update
BEFORE INSERT OR UPDATE ON verter
FOR EACH ROW 
EXECUTE FUNCTION fnc_trg_verter_insert_update();

----------Индекс для обеспечения уникальности пар в таблице transferred_points----------
CREATE UNIQUE INDEX idx_transferred_points ON transferred_points(checking_peer, checked_peer);

----------Автоматическое заполнение таблицы transferred_points при добавлении записей в таблицу p2p со статусом Start----------

CREATE OR REPLACE FUNCTION fnc_trg_transferred_points_insert_update() RETURNS TRIGGER AS $transferred_points_insert_update$
	BEGIN
		IF (TG_OP = 'INSERT') THEN
			IF NOT EXISTS (SELECT *
						   FROM transferred_points
						   WHERE checking_peer = NEW.checking_peer 
						   		AND checked_peer = (SELECT peer
				    								FROM checks
													WHERE id = NEW."check"))
			THEN INSERT INTO transferred_points(checking_peer, checked_peer, points_amount)
			VALUES(NEW.checking_peer, 
				   (SELECT peer
				    FROM checks
					WHERE id = NEW."check"),
					1);
			ELSE UPDATE transferred_points 
				 SET points_amount = points_amount + 1
				 WHERE checking_peer = NEW.checking_peer 
					   AND checked_peer = (SELECT peer
				    					   FROM checks
										   WHERE id = NEW."check");		
        	END IF;
		END IF;
		RETURN NULL; 
    END;
$transferred_points_insert_update$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transferred_points_insert_update
AFTER INSERT ON p2p
FOR EACH ROW 
WHEN (NEW.state = 'Start')
EXECUTE FUNCTION fnc_trg_transferred_points_insert_update();