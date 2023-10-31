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
	id BIGINT PRIMARY KEY,
	peer VARCHAR NOT NULL REFERENCES peers,
	task VARCHAR NOT NULL REFERENCES tasks,
	date DATE NOT NULL
);
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
	points_amount INTEGER DEFAULT 0 NOT NULL
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
	recommended_peer VARCHAR DEFAULT 0 NOT NULL REFERENCES peers
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

CREATE OR REPLACE FUNCTION fnc_trg_p2p_insert() RETURNS TRIGGER AS $p2p_insert$
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
BEFORE INSERT OR UPDATE ON p2p
FOR EACH ROW 
EXECUTE PROCEDURE fnc_trg_p2p_insert();