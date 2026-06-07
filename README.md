# 学生管理系统 — 数据库课程设计

**选题**：学生管理系统（仿 USTC 教务系统）  
**架构**：B/S（Browser/Server）  
**数据库**：MySQL 8.0.45  
**后端**：Python 3.13 + Flask 3 + PyMySQL  
**前端**：Bootstrap 5.3 + Bootstrap Icons（CDN）

---

## 一、项目概述

基于 Flask + MySQL 的 B/S 架构学生管理系统，支持**管理员**、**教师**、**学生**三种角色。

### 核心功能

| 角色 | 功能 |
|------|------|
| **管理员** | 学院/专业/班级/学生/教师/课程 CRUD、成绩录入、奖惩管理、审批中心（转专业/放弃成绩/奖项）、账号管理 |
| **教师** | 查看授课课程、录入/修改成绩、成绩分布统计 |
| **学生** | 查看成绩/GPA/学院排名、选课/退课、转专业申请、放弃成绩申请、奖项申请（支持文件上传）、个人信息编辑 |

---

## 二、系统架构

```
┌──────────────────────────────────────────────────────────┐
│                    🌐 浏览器 (前端)                        │
│  ┌─────────────────────┐  ┌────────────────────────────┐ │
│  │  Jinja2 模板引擎      │  │  Bootstrap 5.3 CSS 框架    │ │
│  │  · {{变量}} 插入数据   │  │  · .btn .card .table 美化  │ │
│  │  · {% for %} 循环行   │  │  · 栅格布局 / 响应式        │ │
│  │  · {% if %} 条件分支  │  │  · 导航栏 / 表单 / 模态框   │ │
│  └─────────────────────┘  └────────────────────────────┘ │
│              ↑ 两者在服务端融合成纯 HTML/CSS                  │
└──────────────────────┬───────────────────────────────────┘
                       │  HTTP 请求 (GET/POST)
                       ▼
┌──────────────────────────────────────────────────────────┐
│                    ⚙️ Flask (后端)                         │
│  app.py — 路由分发 · 权限控制 · 业务逻辑                     │
│  config.py — 数据库连接配置                                │
│  render_template('页面.html', 数据=...) → Jinja2 填充      │
└──────────────────────┬───────────────────────────────────┘
                       │  PyMySQL 执行 SQL
                       ▼
┌──────────────────────────────────────────────────────────┐
│                  🗄️ MySQL (数据库)                         │
│  15 张数据表 + 5 触发器 + 7 存储过程 + 1 函数                │
│  student_management 数据库                                │
└──────────────────────────────────────────────────────────┘
```

**一次典型的请求过程**（学生查看成绩）：

```
学生点击「我的成绩」
  → 浏览器 GET /student/scores
    → app.py 执行 student_scores()
      → SELECT ... FROM sc JOIN course ...  (查成绩)
      → CALL sp_calc_gpa_43(...)            (算GPA)
      → SELECT ... 同学院同年级排名            (算排名)
    ← 渲染 student_scores.html 返回
  ← 浏览器展示页面（GPA / 排名 / 学分卡片）
```

---

## 三、项目结构

```
Database_project/
├── README.md                          # 本文件 — 项目说明
├── docs/
│   ├── 3NF分析.md        				 # 3NF模式证明
│   ├── ER图_实际.png                   # ER 图 
├── sql/
│   ├── init_database.sql              # 入口（SOURCE 四个子文件）
│   ├── 01_tables.sql                  # 15 张数据表 DDL
│   ├── 02_routines.sql                # 1 函数 + 7 存储过程
│   ├── 03_triggers.sql                # 5 触发器
│   └── 04_data.sql                	  # 示例基础数据
├── src/
│   ├── app.py                         # Flask 主应用（路由/业务逻辑）
│   ├── config.py                      # 数据库连接与 Flask 配置
│   ├── requirements.txt               # pip 依赖
│   ├── static/                        # 静态资源（预留）
│   ├── uploads/                       # 上传文件存储
│   │   ├── photos/                    # 证件照
│   │   ├── videos/                    # 课程视频
│   │   ├── awards/                    # 奖项凭证
│   │   ├── 学生导入模板.xlsx            # 学生批量导入模板
│   │   └── 教师导入模板.xlsx            # 教师批量导入模板
│   └── templates/                     # 29 个 Jinja2 HTML 模板
```

---

## 四、快速启动

### 4.1 环境要求

- Python 3.10+
- MySQL 8.0+
- pip

### 4.2 数据库配置

1. 确保 MySQL 服务已启动
2. 数据库 `student_management` 已存在并包含数据
3. 如需修改数据库连接参数，编辑 `src/config.py`

### 4.3 启动应用

```powershell
cd src
python app.py
```

访问 http://127.0.0.1:5000

## 五、数据库设计

### 5.1 数据表（15 张）

| 表名 | 说明 | 关键字段 |
|------|------|----------|
| `college` | 学院 | college_id, name, dean, description |
| `major` | 专业 | major_id, name, college_id(FK) |
| `class` | 班级 | class_id, name, major_id(FK), enroll_year |
| `student` | 学生 | sno(PK), name, gender, birth, phone, email, photo_path, class_id(FK), status, enroll_year |
| `teacher` | 教师 | tno(PK), name, gender, title, college_id(FK) |
| `course` | 课程 | cno(PK), name, credit, hours, type, semester, tno(FK) |
| `sc` | 选课/成绩 | (sno,cno) PK, score, status |
| `account` | 账号 | account_id, username, password_hash(SHA256), role, ref_id |
| `admin` | 管理员 | admin_id, job_no, name, gender, phone, email, department, title |
| `major_transfer` | 转专业申请 | transfer_id, sno, from/to_class_id, reason, status, apply_date, review_date, review_comment, reviewed_by(FK) |
| `score_abandon` | 放弃成绩申请 | abandon_id, sno, cno, reason, status, apply_date, review_date, review_comment, reviewed_by(FK) |
| `reward_punishment` | 奖惩记录 | rp_id, sno, type, title, description, rp_date, status, created_by(FK) |
| `award_application` | 奖项申请 | app_id, sno, title, description, file_path, status, apply_date, review_date, review_comment, reviewed_by(FK)（审批后触发器自动同步到奖励表） |
| `course_video` | 课程视频 | video_id, course_id(FK), title, description, file_path, file_size, duration, upload_time, uploaded_by(FK) |
| `score_log` | 成绩日志 | log_id, sno, cno, old_score, new_score, change_time |

### 5.2 范式

所有表均满足 **3NF**，无部分依赖和传递依赖。

