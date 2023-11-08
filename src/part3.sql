-- @block
-- @conn school21
-- Write a function that returns the TransferredPoints table in a more
-- human-readable form
CREATE
OR REPLACE FUNCTION fnc_transferred_points() RETURNS TABLE(
    peer1 VARCHAR,
    peer2 VARCHAR,
    points_amount INTEGER
) AS $$ WITH transfer_sum AS (
    SELECT checking_peer,
        checked_peer,
        SUM(points_amount) AS points_amount,
        -- min ID (to recognize the first appearance of a pair later)
        MIN(id) AS id,
        -- peers pairs (peer1-peer2 and peer2-peer1 will always have
        -- peer1-peer2 pair)
        CONCAT(
            LEAST(checking_peer, checked_peer),
            '_',
            GREATEST(checking_peer, checked_peer)
        ) AS pair
    FROM transferred_points
    GROUP BY checking_peer,
        checked_peer
)
SELECT t1.checking_peer,
    t1.checked_peer,
    t1.points_amount - COALESCE(t2.points_amount, 0) AS points_amounts
FROM transfer_sum AS t1
    INNER JOIN (
        -- to remove the duplicates of forward and backward transfers
        SELECT pair,
            MIN(id) AS min_id
        FROM transfer_sum
        GROUP BY pair
    ) AS first_pair ON t1.pair = first_pair.pair
    AND t1.id = first_pair.min_id
    LEFT JOIN transfer_sum AS t2 -- to subtract the amount of a backward transfer
    ON t1.checking_peer = t2.checked_peer
    AND t1.checked_peer = t2.checking_peer
    AND t1.checked_peer = t2.checking_peer
WHERE t1.points_amount - COALESCE(t2.points_amount, 0) <> 0;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Write a function that returns a table of the following form: user name, name
-- of the checked task, number of XP received
CREATE
OR REPLACE FUNCTION fnc_checked_tasks_xp() RETURNS TABLE(
    peer1 VARCHAR,
    task VARCHAR,
    XP INTEGER
) AS $$
SELECT checks.peer AS peer,
    SPLIT_PART(checks.task, '_', 1) AS task,
    xp.xp_amount AS XP
FROM xp
    JOIN checks ON xp. "check" = checks.id
ORDER BY peer,
    task;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Write a function that finds the peers who have not left campus for the whole
-- day
CREATE
OR REPLACE FUNCTION fnc_peers_all_day_in_campus(pdate DATE) RETURNS TABLE(peer VARCHAR) AS $$
SELECT peer
FROM time_tracking AS tt
WHERE DATE = pdate
    AND state = 2
GROUP BY peer
HAVING COUNT(state) = 1
ORDER BY peer;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Calculate the change in the number of peer points of each peer using the
-- TransferredPoints table
CREATE
OR REPLACE FUNCTION fnc_points_change() RETURNS TABLE(peer VARCHAR, points_change INTEGER) AS $$
SELECT peer,
    SUM(points_amount) AS points_change
FROM (
        SELECT checking_peer AS peer,
            points_amount
        FROM transferred_points
        UNION
        ALL
        SELECT checked_peer AS peer,
            points_amount * (-1)
        FROM transferred_points
    ) AS d
GROUP BY peer
ORDER BY points_change DESC;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Calculate the change in the number of peer points of each peer using the
-- table returned by the first function
CREATE
OR REPLACE FUNCTION fnc_points_change2() RETURNS TABLE(peer VARCHAR, points_change INTEGER) AS $$
SELECT peer,
    SUM(points_amount) AS points_change
FROM (
        SELECT peer1 AS peer,
            points_amount
        FROM fnc_transferred_points()
        UNION
        ALL
        SELECT peer2 AS peer,
            points_amount * (-1)
        FROM fnc_transferred_points()
    ) AS d
GROUP BY peer
ORDER BY points_change DESC;

$$ LANGUAGE SQL;