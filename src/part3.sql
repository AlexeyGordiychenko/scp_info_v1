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

-- @block
-- @conn school21
-- Find the most frequently checked task for each day
CREATE
OR REPLACE FUNCTION fnc_most_frequently_checked_tasks() RETURNS TABLE(DAY VARCHAR, task VARCHAR) AS $$ WITH d AS (
    SELECT SPLIT_PART(checks.task, '_', 1) AS task,
        checks.date AS day,
        COUNT(*) AS n
    FROM checks
        INNER JOIN (
            SELECT "check"
            FROM p2p
            WHERE state = 'Start'
            UNION
            ALL
            SELECT "check"
            FROM verter
            WHERE state = 'Start'
        ) AS started_checks ON checks.id = started_checks.check
    GROUP BY checks.date,
        SPLIT_PART(checks.task, '_', 1)
)
SELECT TO_CHAR(day, 'DD.MM.YYYY'),
    task
FROM (
        SELECT day,
            task,
            n,
            RANK() OVER (
                PARTITION BY day
                ORDER BY n DESC
            )
        FROM d
    ) AS r
WHERE r.rank = 1
ORDER BY day;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Find all peers who have completed the whole given block of tasks and the
-- completion date of the last task
CREATE
OR REPLACE FUNCTION fnc_completed_blocks(block VARCHAR) RETURNS TABLE(peer VARCHAR, day VARCHAR) AS $$ WITH block_tasks AS (
    -- All tasks of a block
    SELECT title
    FROM tasks
    WHERE SUBSTRING(
            title
            FROM '^[^0-9]*'
        ) = block
),
peers AS (
    -- Number of completed tasks and the max date of completion
    SELECT peer,
        MAX(date) AS day,
        COUNT(DISTINCT task) AS completed_tasks
    FROM checks
        INNER JOIN block_tasks ON checks.task = block_tasks.title
        INNER JOIN xp ON checks.id = xp.check
    GROUP BY peer
) -- Peers with number of completed tasks equal to number of tasks in a block
SELECT peer,
    TO_CHAR(day, 'DD.MM.YYYY')
FROM peers
WHERE completed_tasks = (
        SELECT COUNT(*)
        FROM block_tasks
    )
ORDER BY day DESC;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Determine which peer each student should go to for a check
CREATE
OR REPLACE FUNCTION fnc_recommended_peer() RETURNS TABLE(peer VARCHAR, recommended_peer VARCHAR) AS $$ WITH f AS (
    -- Peer and their friends
    SELECT peer1 AS peer,
        peer2 AS friend
    FROM friends
    UNION
    SELECT peer2,
        peer1
    FROM friends
),
r AS (
    -- All recommended peers
    SELECT f.peer,
        r.recommended_peer AS recommended_peer,
        COUNT(*) AS n
    FROM f
        INNER JOIN recommendations AS r ON f.friend = r.peer
    GROUP BY f.peer,
        r.recommended_peer
) -- Final querty to get peers and recommendations filtered by rank
SELECT peer,
    recommended_peer
FROM (
        -- Rank recommendations to find the most recommended
        SELECT peer,
            recommended_peer,
            n,
            RANK() OVER (
                PARTITION BY peer
                ORDER BY n DESC
            )
        FROM r
    ) AS most_recommended
WHERE most_recommended.rank = 1
ORDER BY peer;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Determine the percentage of peers who:
--     Started only block 1
--     Started only block 2
--     Started both
--     Have not started any of them
CREATE
OR REPLACE FUNCTION fnc_percentage_peers_blocks(block1 VARCHAR, block2 VARCHAR) RETURNS TABLE(
    StartedBlock1 FLOAT,
    StartedBlock2 FLOAT,
    StartedBothBlocks FLOAT,
    DidntStartAnyBlock FLOAT
) AS $$ WITH blocks_tasks AS (
    -- Info about peers, number of blocks and block's name if it's the only
    -- block
    SELECT peer,
        COUNT(DISTINCT block) AS blocks_count,
        MAX(block) max_block
    FROM (
            SELECT peer,
                SUBSTRING(
                    task
                    FROM '^[^0-9]*'
                ) AS block
            FROM checks
        ) AS blocks
    WHERE block IN (block1, block2)
    GROUP BY peer
),
all_peers AS (
    -- Total number of peers (with division by 100 for the percent calculation
    -- later)
    SELECT COUNT(*)::float / 100 AS peers_count
    FROM peers
)
SELECT (
        -- Started only block 1
        SELECT COUNT(*)
        FROM blocks_tasks
        WHERE blocks_count = 1
            AND max_block = block1
    ) / peers_count AS block1,
    (
        -- Started only block 2
        SELECT COUNT(*)
        FROM blocks_tasks
        WHERE blocks_count = 1
            AND max_block = block2
    ) / peers_count AS block2,
    (
        -- Started both blocks
        SELECT COUNT(*)
        FROM blocks_tasks
        WHERE blocks_count = 2
    ) / peers_count AS block_both,
    (
        -- Have not started any of the blocks
        SELECT COUNT(*)
        FROM peers
            LEFT JOIN blocks_tasks ON nickname = peer
        WHERE peer IS NULL
    ) / peers_count AS other
FROM all_peers;

$$ LANGUAGE SQL;

-- @block
-- @conn school21
-- Determine the percentage of peers who have ever successfully passed a check
-- on their birthday
CREATE
OR REPLACE FUNCTION fnc_checks_on_bday() RETURNS TABLE(
    successful_checks FLOAT,
    unsuccessful_checks FLOAT
) AS $$ WITH checks_on_bday AS (
    SELECT checks.id,
        CASE
            WHEN p2p.state = 'Success'
            AND COALESCE(verter.state, 'Success') = 'Success' THEN 1.0
            ELSE 0.0
        END AS state
    FROM checks
        INNER JOIN p2p ON checks.id = p2p.check
        AND p2p.state <> 'Start'
        LEFT JOIN verter ON checks.id = verter.check
        AND verter.state <> 'Start'
        INNER JOIN peers ON checks.peer = peers.nickname
    WHERE DATE_PART('day', checks.date) = DATE_PART('day', peers.birthday)
        AND DATE_PART('month', checks.date) = DATE_PART('month', peers.birthday)
)
SELECT ROUND(AVG(state) * 100, 2) AS successful_checks,
    ROUND(AVG(1 - state) * 100, 2) AS unsuccessful_checks
FROM checks_on_bday;

$$ LANGUAGE SQL;