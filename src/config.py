# =============================================================================
# config.py — 数据库与 Flask 配置文件
# =============================================================================
# 包含：MySQL 连接参数 (DB_CONFIG) 和 Flask SECRET_KEY
# 使用方式：在 app.py 中 from config import DB_CONFIG, SECRET_KEY
# 注意：生产环境应使用环境变量存储敏感信息，此处为课程设计简化
# =============================================================================
# config.py - 数据库与Flask配置

DB_CONFIG = {
    'host': 'localhost',
    'port': 3306,
    'user': 'root',
    'password': '123456',       # MySQL密码
    'database': 'student_management',
    'charset': 'utf8mb4',
}

SECRET_KEY = 'student-management-secret-key-2026'
