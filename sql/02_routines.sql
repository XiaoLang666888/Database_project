-- =============================================================================
-- 02_routines.sql — 学生管理系统 · 函数与存储过程
-- =============================================================================
-- 数据库：MySQL 8.x
-- 包含：1 个函数 + 7 个存储过程
--   函数：fn_score_to_gp_43          — 百分制 → 4.3 绩点
--   过程：sp_calc_gpa_43             — 计算 GPA/均分/学分
--         sp_enroll_student          — 选课（事务，FOR UPDATE 行锁）
--         sp_approve_transfer        — 审批转专业（事务，双表原子更新）
--         sp_approve_abandon         — 审批放弃成绩（事务，双表原子更新）
--         sp_student_gpa_rank        — 学生 GPA + 学院排名（合并查询）
--         sp_teacher_course_stats    — 教师课程统计
-- 作者：肖烺 | 学号：PB23111650 | 更新：2026-06-04
-- =============================================================================

DELIMITER //

-- =============================================================================
-- 函数：fn_score_to_gp_43 — 百分制成绩 → 4.3 分制绩点 (USTC 标准)
-- =============================================================================
CREATE FUNCTION fn_score_to_gp_43(score DECIMAL(5,2))
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE gp DECIMAL(5,2);
    IF score IS NULL THEN SET gp = NULL;
    ELSEIF score < 60 THEN SET gp = 0.0;
    ELSEIF score = 60 THEN SET gp = 1.0;
    ELSEIF score BETWEEN 61 AND 63 THEN SET gp = 1.3;
    ELSEIF score = 64 THEN SET gp = 1.5;
    ELSEIF score BETWEEN 65 AND 67 THEN SET gp = 1.7;
    ELSEIF score BETWEEN 68 AND 71 THEN SET gp = 2.0;
    ELSEIF score BETWEEN 72 AND 74 THEN SET gp = 2.3;
    ELSEIF score BETWEEN 75 AND 77 THEN SET gp = 2.7;
    ELSEIF score BETWEEN 78 AND 81 THEN SET gp = 3.0;
    ELSEIF score BETWEEN 82 AND 84 THEN SET gp = 3.3;
    ELSEIF score BETWEEN 85 AND 89 THEN SET gp = 3.7;
    ELSEIF score BETWEEN 90 AND 94 THEN SET gp = 4.0;
    ELSE SET gp = 4.3;
    END IF;
    RETURN gp;
END //


-- =============================================================================
-- 存储过程：sp_calc_gpa_43 — 计算学生 4.3制GPA + 算术均分 + 加权均分 + 已修学分
-- =============================================================================
CREATE PROCEDURE sp_calc_gpa_43(
    IN  p_sno          VARCHAR(20),
    OUT p_gpa          DECIMAL(5,2),
    OUT p_avg_score    DECIMAL(5,2),
    OUT p_avg_score_w  DECIMAL(5,2),
    OUT p_total_credits INT
)
BEGIN
    DECLARE total_points      DECIMAL(10,2) DEFAULT 0;
    DECLARE total_credits_val INT DEFAULT 0;
    DECLARE total_score       DECIMAL(10,2) DEFAULT 0;
    DECLARE total_score_w     DECIMAL(10,2) DEFAULT 0;
    DECLARE cnt               INT DEFAULT 0;
    DECLARE done              INT DEFAULT 0;
    DECLARE v_score           DECIMAL(5,2);
    DECLARE v_credit          INT;

    DECLARE cur CURSOR FOR
        SELECT sc.score, c.credit
        FROM sc JOIN course c ON sc.cno = c.cno
        WHERE sc.sno = p_sno AND sc.status = 'normal' AND sc.score IS NOT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_score, v_credit;
        IF done THEN LEAVE read_loop; END IF;
        SET total_points      = total_points + fn_score_to_gp_43(v_score) * v_credit;
        SET total_credits_val = total_credits_val + v_credit;
        SET total_score       = total_score + v_score;
        SET total_score_w     = total_score_w + v_score * v_credit;
        SET cnt               = cnt + 1;
    END LOOP;
    CLOSE cur;

    IF total_credits_val > 0 THEN
        SET p_gpa         = ROUND(total_points / total_credits_val, 2);
        SET p_avg_score_w = ROUND(total_score_w / total_credits_val, 2);
    ELSE
        SET p_gpa = NULL; SET p_avg_score_w = NULL;
    END IF;
    IF cnt > 0 THEN
        SET p_avg_score = ROUND(total_score / cnt, 2);
    ELSE
        SET p_avg_score = NULL;
    END IF;
    SET p_total_credits = total_credits_val;
END //


-- =============================================================================
-- 事务存储过程：sp_enroll_student — 为学生选课（替代 app.py 事务1）
-- =============================================================================
-- 使用 FOR UPDATE 行锁防止并发问题，验证失败时 SIGNAL 触发 Python 端 rollback
CREATE PROCEDURE sp_enroll_student(
    IN p_sno VARCHAR(20),
    IN p_cno INT
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    START TRANSACTION;
    -- 验证学生存在（FOR UPDATE 行锁）
    SELECT COUNT(*) INTO v_exists FROM student WHERE sno = p_sno FOR UPDATE;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '学生不存在';
    END IF;
    -- 验证课程存在
    SELECT COUNT(*) INTO v_exists FROM course WHERE cno = p_cno FOR UPDATE;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '课程不存在';
    END IF;

    -- 检查是否已选
    SELECT COUNT(*) INTO v_exists FROM sc WHERE sno = p_sno AND cno = p_cno;
    IF v_exists > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该学生已选此课程';
    END IF;
    INSERT INTO sc(sno, cno) VALUES(p_sno, p_cno);
    COMMIT;
END //


-- =============================================================================
-- 事务存储过程：sp_approve_transfer — 审批转专业申请（替代 app.py 事务2）
-- =============================================================================
-- 批准时原子更新 major_transfer + student 两张表
-- 拒绝时仅更新 major_transfer 状态
CREATE PROCEDURE sp_approve_transfer(
    IN p_tid      INT,
    IN p_action   VARCHAR(10),    -- 'approve' 或 'reject'
    IN p_comment  VARCHAR(500),
    IN p_reviewer INT
)
BEGIN
    DECLARE v_sno       VARCHAR(20);
    DECLARE v_to_class  INT;
    START TRANSACTION;
    IF p_action = 'approve' THEN
        SELECT sno, to_class_id INTO v_sno, v_to_class
        FROM major_transfer WHERE transfer_id = p_tid FOR UPDATE;

        IF v_sno IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '转专业申请不存在';
        END IF;
        UPDATE major_transfer
        SET status = 'approved', review_date = NOW(),
            review_comment = p_comment, reviewed_by = p_reviewer
        WHERE transfer_id = p_tid;
        UPDATE student SET class_id = v_to_class WHERE sno = v_sno;
    ELSE
        UPDATE major_transfer
        SET status = 'rejected', review_date = NOW(),
            review_comment = p_comment, reviewed_by = p_reviewer
        WHERE transfer_id = p_tid;
    END IF;
    COMMIT;
END //


-- =============================================================================
-- 事务存储过程：sp_approve_abandon — 审批放弃成绩申请（替代 app.py 事务3）
-- =============================================================================
-- 批准时原子更新 score_abandon + sc 两张表
-- 拒绝时仅更新 score_abandon 状态
CREATE PROCEDURE sp_approve_abandon(
    IN p_aid      INT,
    IN p_action   VARCHAR(10),    -- 'approve' 或 'reject'
    IN p_comment  VARCHAR(500),
    IN p_reviewer INT
)
BEGIN
    DECLARE v_sno VARCHAR(20);
    DECLARE v_cno INT;
    START TRANSACTION;
    IF p_action = 'approve' THEN
        SELECT sno, cno INTO v_sno, v_cno
        FROM score_abandon WHERE abandon_id = p_aid FOR UPDATE;
        IF v_sno IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '放弃成绩申请不存在';
        END IF;
        UPDATE score_abandon
        SET status = 'approved', review_date = NOW(),
            review_comment = p_comment, reviewed_by = p_reviewer
        WHERE abandon_id = p_aid;
        UPDATE sc SET status = 'abandoned' WHERE sno = v_sno AND cno = v_cno;
    ELSE
        UPDATE score_abandon
        SET status = 'rejected', review_date = NOW(),
            review_comment = p_comment, reviewed_by = p_reviewer
        WHERE abandon_id = p_aid;
    END IF;
    COMMIT;
END //


-- =============================================================================
-- 存储过程：sp_student_gpa_rank — 学生 GPA + 同学院同年级排名
-- =============================================================================
-- 内部调用 sp_calc_gpa_43，然后查询学院内同入学年份排名
-- 6 个 OUT 参数，一个调用替代原来的 2 个存储过程调用 + 4 条查询
CREATE PROCEDURE sp_student_gpa_rank(
    IN  p_sno           VARCHAR(20),
    OUT o_gpa           DECIMAL(5,2),
    OUT o_avg_score     DECIMAL(5,2),
    OUT o_avg_score_w   DECIMAL(5,2),
    OUT o_total_credits INT,
    OUT o_college_total INT,
    OUT o_college_rank  INT
)
BEGIN
    DECLARE v_enroll_year INT;
    DECLARE v_college_id  INT;
    -- Step 1: 计算 GPA（复用已有存储过程）
    CALL sp_calc_gpa_43(p_sno, o_gpa, o_avg_score, o_avg_score_w, o_total_credits);
    -- Step 2: 获取学生所在学院和入学年份
    SELECT c.enroll_year, m.college_id
    INTO v_enroll_year, v_college_id
    FROM student s
    JOIN class c ON s.class_id = c.class_id
    JOIN major m ON c.major_id = m.major_id
    WHERE s.sno = p_sno;
    -- Step 3: 同学院同年级总人数
    IF v_college_id IS NOT NULL THEN
        SELECT COUNT(*) INTO o_college_total
        FROM student s
        JOIN class c ON s.class_id = c.class_id
        JOIN major m ON c.major_id = m.major_id
        WHERE m.college_id = v_college_id AND c.enroll_year = v_enroll_year;
        -- Step 4: 排名（GPA 比自己高的同学院同年级人数 + 1）
        IF o_gpa IS NOT NULL THEN
            SELECT COUNT(*) + 1 INTO o_college_rank
            FROM (
                SELECT s2.sno,
                    IFNULL((
                        SELECT ROUND(SUM(fn_score_to_gp_43(sc2.score) * co2.credit)
                                     / NULLIF(SUM(co2.credit), 0), 2)
                        FROM sc sc2 JOIN course co2 ON sc2.cno = co2.cno
                        WHERE sc2.sno = s2.sno
                          AND sc2.status = 'normal'
                          AND sc2.score IS NOT NULL
                    ), 0) AS gpa_calc
                FROM student s2
                JOIN class c2 ON s2.class_id = c2.class_id
                JOIN major m2 ON c2.major_id = m2.major_id
                WHERE m2.college_id = v_college_id
                  AND c2.enroll_year = v_enroll_year
            ) t WHERE t.gpa_calc > o_gpa;
        ELSE
            SET o_college_rank = NULL;
        END IF;
    ELSE
        SET o_college_total = 0;
        SET o_college_rank = NULL;
    END IF;
END //


-- =============================================================================
-- 存储过程：sp_student_major_rank — 学生专业内同年级排名
-- =============================================================================
CREATE PROCEDURE sp_student_major_rank(
    IN  p_sno          VARCHAR(20),
    OUT o_major_total  INT,
    OUT o_major_rank   INT
)
BEGIN
    DECLARE v_enroll_year INT;
    DECLARE v_major_id   INT;
    DECLARE v_gpa        DECIMAL(5,2);
    -- 获取学生的专业和入学年份
    SELECT c.enroll_year, c.major_id
    INTO v_enroll_year, v_major_id
    FROM student s JOIN class c ON s.class_id = c.class_id
    WHERE s.sno = p_sno;
    -- 复用已有存储过程计算 GPA
    CALL sp_calc_gpa_43(p_sno, v_gpa, @_, @_, @_);
    IF v_major_id IS NOT NULL THEN
        -- 同专业同年级总人数
        SELECT COUNT(*) INTO o_major_total
        FROM student s
        JOIN class c ON s.class_id = c.class_id
        WHERE c.major_id = v_major_id AND c.enroll_year = v_enroll_year;
        -- 排名
        IF v_gpa IS NOT NULL THEN
            SELECT COUNT(*) + 1 INTO o_major_rank
            FROM (
                SELECT s2.sno,
                    IFNULL((
                        SELECT ROUND(SUM(fn_score_to_gp_43(sc2.score) * co2.credit)
                                     / NULLIF(SUM(co2.credit), 0), 2)
                        FROM sc sc2 JOIN course co2 ON sc2.cno = co2.cno
                        WHERE sc2.sno = s2.sno
                          AND sc2.status = 'normal'
                          AND sc2.score IS NOT NULL
                    ), 0) AS gpa_calc
                FROM student s2
                JOIN class c2 ON s2.class_id = c2.class_id
                WHERE c2.major_id = v_major_id
                  AND c2.enroll_year = v_enroll_year
            ) t WHERE t.gpa_calc > v_gpa;
        ELSE
            SET o_major_rank = NULL;
        END IF;
    ELSE
        SET o_major_total = 0;
        SET o_major_rank = NULL;
    END IF;
END //


-- =============================================================================
-- 存储过程：sp_teacher_course_stats — 教师课程成绩统计
-- =============================================================================
-- 返回课程的总人数/已评分/平均分/最高/最低/通过率/优秀率(≥85)
CREATE PROCEDURE sp_teacher_course_stats(
    IN  p_cno            INT,
    IN  p_tno            VARCHAR(10),
    OUT o_total          INT,
    OUT o_scored         INT,
    OUT o_avg            DECIMAL(5,1),
    OUT o_max            DECIMAL(5,1),
    OUT o_min            DECIMAL(5,1),
    OUT o_pass_rate      DECIMAL(5,1),
    OUT o_excellent_rate DECIMAL(5,1)
)
BEGIN
    SELECT
        COUNT(*),
        COUNT(score),
        ROUND(AVG(score), 1),
        MAX(score),
        MIN(score),
        ROUND(SUM(CASE WHEN score >= 60 THEN 1 ELSE 0 END) * 100.0
              / NULLIF(COUNT(score), 0), 1),
        ROUND(SUM(CASE WHEN score >= 85 THEN 1 ELSE 0 END) * 100.0
              / NULLIF(COUNT(score), 0), 1)
    INTO o_total, o_scored, o_avg, o_max, o_min, o_pass_rate, o_excellent_rate
    FROM sc
    WHERE cno = p_cno AND status = 'normal';
END //

DELIMITER ;
