-- =============================================================================
-- 01_tables.sql — 学生管理系统 · 数据表定义 (DDL)
-- =============================================================================
-- 数据库：MySQL 8.x | 字符集：utf8mb4
-- 共 15 张表，均满足 3NF
-- 外键关系：college → major → class → student
--           college → teacher → course → sc ← student
-- 作者：肖烺 | 学号：PB23111650 | 更新：2026-06-04
-- =============================================================================

-- 1. 学院表
CREATE TABLE college (
    college_id  INT AUTO_INCREMENT,
    name        VARCHAR(80) NOT NULL,
    dean        VARCHAR(50),
    description TEXT,
    PRIMARY KEY (college_id),
    UNIQUE KEY (name)
) ENGINE=InnoDB;

-- 2. 专业表 (FK → college)
CREATE TABLE major (
    major_id    INT AUTO_INCREMENT,
    name        VARCHAR(50) NOT NULL,
    college_id  INT,
    PRIMARY KEY (major_id),
    UNIQUE KEY (name),
    FOREIGN KEY (college_id) REFERENCES college(college_id)
) ENGINE=InnoDB;

-- 3. 班级表 (FK → major)
CREATE TABLE class (
    class_id    INT AUTO_INCREMENT,
    name        VARCHAR(50) NOT NULL,
    major_id    INT NOT NULL,
    enroll_year INT COMMENT '入学年份',
    PRIMARY KEY (class_id),
    FOREIGN KEY (major_id) REFERENCES major(major_id)
) ENGINE=InnoDB;

-- 4. 学生表 (FK → class)
CREATE TABLE student (
    sno         VARCHAR(20) NOT NULL,
    name        VARCHAR(50) NOT NULL,
    gender      CHAR(1) NOT NULL,
    birth       DATE,
    status      ENUM('active','suspended','withdrawn','graduated') NOT NULL DEFAULT 'active',
    enroll_year INT,
    phone       VARCHAR(20),
    email       VARCHAR(100),
    photo_path  VARCHAR(255),
    class_id    INT,
    PRIMARY KEY (sno),
    FOREIGN KEY (class_id) REFERENCES class(class_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 5. 教师表 (FK → college)
CREATE TABLE teacher (
    tno         INT AUTO_INCREMENT,
    name        VARCHAR(50) NOT NULL,
    gender      CHAR(1) NOT NULL,
    title       VARCHAR(20),
    college_id  INT,
    PRIMARY KEY (tno),
    FOREIGN KEY (college_id) REFERENCES college(college_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 6. 课程表 (FK → teacher)
CREATE TABLE course (
    cno      INT AUTO_INCREMENT,
    name     VARCHAR(50) NOT NULL,
    credit   INT NOT NULL,
    hours    INT,
    tno      INT,
    semester VARCHAR(20) NOT NULL DEFAULT '2025-2026-2',
    type     VARCHAR(20) NOT NULL DEFAULT '专业必修',
    PRIMARY KEY (cno),
    FOREIGN KEY (tno) REFERENCES teacher(tno) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 7. 选课/成绩表 (FK → student + course)
CREATE TABLE sc (
    sno     VARCHAR(20) NOT NULL,
    cno     INT NOT NULL,
    score   FLOAT,
    status  ENUM('normal','abandoned') NOT NULL DEFAULT 'normal',
    PRIMARY KEY (sno, cno),
    FOREIGN KEY (sno) REFERENCES student(sno) ON DELETE CASCADE,
    FOREIGN KEY (cno) REFERENCES course(cno) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 8. 账号表（统一认证）
CREATE TABLE account (
    account_id    INT AUTO_INCREMENT,
    username      VARCHAR(50) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('admin','teacher','student') NOT NULL,
    ref_id        INT,
    PRIMARY KEY (account_id),
    UNIQUE KEY (username)
) ENGINE=InnoDB;

-- 9. 管理员表
CREATE TABLE admin (
    admin_id    INT AUTO_INCREMENT,
    job_no      VARCHAR(20) NOT NULL,
    name        VARCHAR(50) NOT NULL,
    gender      CHAR(1) NOT NULL DEFAULT 'M',
    phone       VARCHAR(20),
    email       VARCHAR(100),
    department  VARCHAR(100),
    title       VARCHAR(50),
    PRIMARY KEY (admin_id),
    UNIQUE KEY (job_no)
) ENGINE=InnoDB;

-- 10. 转专业申请表 (FK → student + class×2 + admin)
CREATE TABLE major_transfer (
    transfer_id    INT AUTO_INCREMENT,
    sno            VARCHAR(20) NOT NULL,
    from_class_id  INT NOT NULL,
    to_class_id    INT NOT NULL,
    reason         TEXT,
    status         ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    apply_date     DATETIME DEFAULT CURRENT_TIMESTAMP,
    review_date    DATETIME,
    review_comment TEXT,
    reviewed_by    INT,
    PRIMARY KEY (transfer_id),
    FOREIGN KEY (sno) REFERENCES student(sno) ON DELETE CASCADE,
    FOREIGN KEY (from_class_id) REFERENCES class(class_id),
    FOREIGN KEY (to_class_id) REFERENCES class(class_id),
    FOREIGN KEY (reviewed_by) REFERENCES admin(admin_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 11. 放弃成绩申请表 (FK → student + course + admin)
CREATE TABLE score_abandon (
    abandon_id     INT AUTO_INCREMENT,
    sno            VARCHAR(20) NOT NULL,
    cno            INT NOT NULL,
    reason         TEXT,
    status         ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    apply_date     DATETIME DEFAULT CURRENT_TIMESTAMP,
    review_date    DATETIME,
    review_comment TEXT,
    reviewed_by    INT,
    PRIMARY KEY (abandon_id),
    FOREIGN KEY (sno) REFERENCES student(sno) ON DELETE CASCADE,
    FOREIGN KEY (cno) REFERENCES course(cno) ON DELETE CASCADE,
    FOREIGN KEY (reviewed_by) REFERENCES admin(admin_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 12. 奖惩记录表 (FK → student + admin)
CREATE TABLE reward_punishment (
    rp_id       INT AUTO_INCREMENT,
    sno         VARCHAR(20) NOT NULL,
    type        ENUM('reward','punishment') NOT NULL,
    title       VARCHAR(100) NOT NULL,
    description TEXT,
    rp_date     DATE NOT NULL,
    status      ENUM('effective','canceled') NOT NULL DEFAULT 'effective',
    created_by  INT,
    PRIMARY KEY (rp_id),
    FOREIGN KEY (sno) REFERENCES student(sno) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES admin(admin_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 13. 奖项申请表 (FK → student + admin)
CREATE TABLE award_application (
    app_id         INT AUTO_INCREMENT,
    sno            VARCHAR(20) NOT NULL,
    title          VARCHAR(100) NOT NULL,
    description    TEXT,
    file_path      VARCHAR(255),
    status         ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    apply_date     DATETIME DEFAULT CURRENT_TIMESTAMP,
    review_date    DATETIME,
    review_comment TEXT,
    reviewed_by    INT,
    PRIMARY KEY (app_id),
    FOREIGN KEY (sno) REFERENCES student(sno) ON DELETE CASCADE,
    FOREIGN KEY (reviewed_by) REFERENCES admin(admin_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 14. 课程视频表 (FK → course + teacher)
CREATE TABLE course_video (
    video_id    INT AUTO_INCREMENT,
    course_id   INT NOT NULL,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    file_path   VARCHAR(500) NOT NULL,
    file_size   BIGINT,
    duration    INT DEFAULT 0 COMMENT '时长(秒)',
    upload_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    uploaded_by INT,
    PRIMARY KEY (video_id),
    FOREIGN KEY (course_id) REFERENCES course(cno) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES teacher(tno) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 15. 成绩修改日志表（触发器自动写入）
CREATE TABLE score_log (
    log_id      INT AUTO_INCREMENT,
    sno         VARCHAR(20) NOT NULL,
    cno         INT NOT NULL,
    old_score   FLOAT,
    new_score   FLOAT,
    change_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id)
) ENGINE=InnoDB;
