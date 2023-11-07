----------Процедура добавления P2P проверки----------
CREATE OR REPLACE PROCEDURE add_p2p_check 
	(IN pchecked_peer VARCHAR, IN pchecking_peer VARCHAR, IN ptask VARCHAR, IN pstate check_status, IN ptime TIME) AS $add_p2p$
		BEGIN
			IF pstate = 'Start' THEN
				INSERT INTO checks
				VALUES ((SELECT MAX(id)+1 FROM checks),
						pchecked_peer,
						ptask,
						CURRENT_DATE);
				INSERT INTO p2p
				VALUES ((SELECT MAX(id)+1 FROM p2p),
						(SELECT MAX(id) FROM checks),
						pchecking_peer,
						pstate,
						ptime);
			ELSE INSERT INTO p2p
				 VALUES ((SELECT MAX(id)+1 FROM p2p),
				 		 (SELECT "check"
						  FROM p2p
						  WHERE checking_peer = pchecking_peer AND state = 'Start'
						  ORDER BY "check" DESC
						  LIMIT 1),
						 pchecking_peer,
						 pstate,
						 ptime);
			END IF;			 
		END;
$add_p2p$ LANGUAGE plpgsql;

CALL add_p2p_check ('morozhenka', 'arbuzik', 'C3_s21_string+', 'Start', '13:20:00');
CALL add_p2p_check ('morozhenka', 'arbuzik', 'C3_s21_string+', 'Success', '14:15:00');

----------Процедура добавления проверки Verter'ом----------

CREATE OR REPLACE PROCEDURE add_verter_check 
	(IN pchecked_peer VARCHAR, IN ptask VARCHAR, IN pstate check_status, IN ptime TIME) AS $add_verter$
		BEGIN
			IF pstate = 'Start' THEN
				INSERT INTO verter
				VALUES ((SELECT MAX(id)+1 FROM verter),
						(SELECT ch.id
						 FROM checks ch
						 JOIN p2p ON ch.id = p2p."check"
						 WHERE p2p.state = 'Success' 
						 	AND ch.peer = pchecked_peer AND ch.task = ptask
						 ORDER BY id DESC
						 LIMIT 1),
						pstate,
						ptime);
			ELSE INSERT INTO verter
				 VALUES ((SELECT MAX(id)+1 FROM verter),
				 		 (SELECT "check"
						  FROM verter v
						  JOIN checks ch ON v."check" = ch.id
						  WHERE v.state = 'Start' 
						  	AND ch.peer = pchecked_peer AND ch.task = ptask
					      ORDER BY "check" DESC
						  LIMIT 1),
						 pstate,
						 ptime);
			END IF;			 
		END;
$add_verter$ LANGUAGE plpgsql;

CALL add_verter_check ('morozhenka', 'C3_s21_string+', 'Start', '13:20:05');
CALL add_verter_check ('morozhenka', 'C3_s21_string+', 'Failure', '13:21:05');

----------Триггер на заполнение таблицы transferred_points----------

CREATE OR REPLACE FUNCTION fnc_trg_transferred_points_insert_update() RETURNS TRIGGER AS $transferred_points_insert_update$
	BEGIN
		IF (TG_OP = 'INSERT') THEN
			IF NOT EXISTS (SELECT *
						   FROM transferred_points
						   WHERE checking_peer = NEW.checking_peer 
						   		AND checked_peer = (SELECT peer
				    								FROM checks
													WHERE id = NEW."check"))
			THEN INSERT INTO transferred_points
				 VALUES((SELECT MAX(id)+1 FROM transferred_points),
						NEW.checking_peer, 
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

CALL add_p2p_check ('pechenca', 'marmeladka', 'C5_s21_decimal', 'Start', '15:20:00');
CALL add_p2p_check ('pechenca', 'marmeladka', 'C5_s21_decimal', 'Success', '16:20:00');

----------Триггер на заполнение таблицы xp----------
CREATE OR REPLACE FUNCTION fnc_trg_xp_insert() RETURNS TRIGGER AS $xp_insert$
	BEGIN
		IF NEW.xp_amount > (SELECT max_xp
							FROM tasks
							JOIN checks ON title = checks.task
							WHERE checks.id = NEW."check")	
		THEN RAISE EXCEPTION 'Too many XP';
		END IF;						
		IF (SELECT state
			FROM p2p
			WHERE "check" = NEW."check"
			ORDER BY id DESC
			LIMIT 1) != 'Success'
		THEN RAISE EXCEPTION 'This check did not pass the peer review';
		END IF;
		IF NEW."check" IN (SELECT checks.id
						   FROM checks
						   JOIN tasks ON checks.task = tasks.title
						   WHERE tasks.title IN ('C2_SimpleBashUtils', 'C3_s21_string+', 'C4_s21_math', 'C5_s21_decimal', 'C6_s21_matrix')) THEN
			IF (SELECT state
				FROM verter
				WHERE "check" = NEW."check"
				ORDER BY id DESC
				LIMIT 1) != 'Success'
			THEN RAISE EXCEPTION 'This check did not pass the Verter';
			END IF;
		END IF;
	RETURN NEW;
	END;
$xp_insert$ LANGUAGE plpgsql;

CREATE TRIGGER trg_xp_insert
BEFORE INSERT ON xp
FOR EACH ROW 
EXECUTE FUNCTION fnc_trg_xp_insert();

CALL add_verter_check ('pechenca', 'C5_s21_decimal', 'Start', '16:20:05');
CALL add_verter_check ('pechenca', 'C5_s21_decimal', 'Success', '16:21:05');
INSERT INTO xp
VALUES ((SELECT MAX(id)+1 FROM xp),
		(SELECT "check"
		 FROM verter
		 WHERE state = 'Success'
		 ORDER BY id DESC
		 LIMIT 1),
		 350);