-- =============================================================================
-- init_database.sql — 学生管理系统 · 数据库一键重建入口
-- =============================================================================
-- 数据库：MySQL 8.x | 字符集：utf8mb4
-- 包含：15 张表 + 1 函数 + 6 存储过程 + 5 触发器
-- 
-- 使用方法（MySQL CLI，在项目根目录 Lab2/ 下执行）：
--   mysql -u root -p < sql/init_database.sql
--
-- 手动导入（按顺序执行）：
--   mysql> SOURCE sql/01_tables.sql;
--   mysql> SOURCE sql/02_routines.sql;
--   mysql> SOURCE sql/03_triggers.sql;
--
-- 子文件说明：
--   01_tables.sql   — 15 张数据表 DDL
--   02_routines.sql — 1 函数(fn_score_to_gp_43) + 6 存储过程
--   03_triggers.sql — 5 触发器
--
-- 作者：肖烺 | 学号：PB23111650 | 更新：2026-06-04
-- =============================================================================

DROP DATABASE IF EXISTS student_management;
CREATE DATABASE student_management DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE student_management;

-- 按依赖顺序导入：表 → 函数/过程 → 触发器 → 数据
SOURCE sql/01_tables.sql;
SOURCE sql/02_routines.sql;
SOURCE sql/03_triggers.sql;
SOURCE sql/04_data.sql;
