-- =============================================================================
-- 03_triggers.sql — 学生管理系统 · 触发器
-- =============================================================================
-- 数据库：MySQL 8.0.45
-- 共 5 个触发器：
--   trg_score_insert_check    — INSERT 时校验成绩范围 0-100
--   trg_score_update_check    — UPDATE 时校验成绩范围 0-100
--   trg_score_insert_log      — INSERT 时自动记录成绩日志
--   trg_score_update_log      — UPDATE 时自动记录成绩变更日志
--   trg_award_to_reward       — 奖项审批通过后自动同步到奖惩表
-- =============================================================================

DELIMITER //

-- 成绩范围约束（INSERT）
CREATE TRIGGER trg_score_insert_check
BEFORE INSERT ON sc FOR EACH ROW
BEGIN
    IF NEW.score IS NOT NULL AND (NEW.score < 0 OR NEW.score > 100) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '成绩必须在 0-100 之间';
    END IF;
END //

-- 成绩范围约束（UPDATE）
CREATE TRIGGER trg_score_update_check
BEFORE UPDATE ON sc FOR EACH ROW
BEGIN
    IF NEW.score IS NOT NULL AND (NEW.score < 0 OR NEW.score > 100) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '成绩必须在 0-100 之间';
    END IF;
END //

-- 成绩插入自动日志
CREATE TRIGGER trg_score_insert_log
AFTER INSERT ON sc FOR EACH ROW
BEGIN
    IF NEW.score IS NOT NULL THEN
        INSERT INTO score_log(sno, cno, old_score, new_score, change_time)
        VALUES (NEW.sno, NEW.cno, NULL, NEW.score, NOW());
    END IF;
END //

-- 成绩修改自动日志（捕获 NULL→值 / 值→NULL / 值→值 三种变更）
CREATE TRIGGER trg_score_update_log
AFTER UPDATE ON sc FOR EACH ROW
BEGIN
    IF (OLD.score IS NULL AND NEW.score IS NOT NULL)
       OR (OLD.score IS NOT NULL AND NEW.score IS NULL)
       OR (OLD.score IS NOT NULL AND NEW.score IS NOT NULL AND OLD.score <> NEW.score) THEN
        INSERT INTO score_log(sno, cno, old_score, new_score, change_time)
        VALUES (NEW.sno, NEW.cno, OLD.score, NEW.score, NOW());
    END IF;
END //

-- 奖项审批通过 → 自动写入奖惩记录
-- 说明：当 award_application.status 从 pending 变为 approved 时，
--       自动在 reward_punishment 表中插入一条 type='reward' 的记录
CREATE TRIGGER trg_award_to_reward
AFTER UPDATE ON award_application FOR EACH ROW
BEGIN
    IF NEW.status = 'approved' AND (OLD.status = 'pending' OR OLD.status IS NULL OR OLD.status <> 'approved') THEN
        INSERT INTO reward_punishment(sno, type, title, description, rp_date, created_by)
        VALUES (NEW.sno, 'reward', NEW.title, NEW.description, CURDATE(), NEW.reviewed_by);
    END IF;
END //

DELIMITER ;
