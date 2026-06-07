# 3NF证明

## 一、模式分解（3NF 范式分析）

### 1.1 函数依赖分析

从 ER 图转换得到初始关系模式，分析各表的函数依赖：

#### ① Admin（管理员表）
```
admin_id → job_no, name, gender, phone, email, department, title
```
- 候选键：`admin_id`
- 非主属性完全函数依赖于候选键
- 无传递依赖
- ✅ **满足 3NF**

#### ② College（学院表）
```
college_id → name, dean, description
```
- 候选键：`college_id`
- 非主属性完全函数依赖于候选键
- 无传递依赖
- ✅ **满足 3NF**

#### ③ Major（专业表）
```
major_id → name, college_id
```
- 候选键：`major_id`
- 非主属性完全函数依赖于候选键
- `college_id` 是外键，不构成传递依赖
- ✅ **满足 3NF**

#### ④ Class（班级表）
```
class_id → name, major_id, enroll_year
```
- 候选键：`class_id`
- 非主属性完全函数依赖于候选键
- 无传递依赖（major_id 是外键）
- ✅ **满足 3NF**

#### ⑤ Student（学生表）
```
sno → name, gender, birth, status, enroll_year, phone, email, photo_path, class_id
```
- 候选键：`sno`
- 非主属性完全函数依赖于候选键
- 无传递依赖（class_id 是外键）
- ✅ **满足 3NF**

#### ⑥ Teacher（教师表）
```
tno → name, gender, title, college_id
```
- 候选键：`tno`
- 非主属性完全函数依赖于候选键
- `college_id` 是外键，不决定其他非主属性，无传递依赖
- ✅ **满足 3NF**

#### ⑦ Course（课程表）
```
cno → name, credit, hours, type, semester, tno
```
- 候选键：`cno`
- 非主属性完全函数依赖于候选键
- 无传递依赖
- ✅ **满足 3NF**

#### ⑧ SC（选课/成绩表）
```
(sno, cno) → score, status
```
- 候选键：`(sno, cno)`（复合主键）
- 非主属性 `score` 和 `status` 完全函数依赖于复合候选键
- 无传递依赖
- ✅ **满足 3NF**

#### ⑨ Account（账号表）
```
account_id → username, password_hash, role, ref_id
```
- 候选键：`account_id`
- 非主属性完全函数依赖于候选键
- `ref_id` 根据 role 关联不同实体（admin/teacher/student），不构成传递依赖
- ✅ **满足 3NF**

#### ⑩ MajorTransfer（转专业申请表）
```
transfer_id → sno, from_class_id, to_class_id, reason, status, apply_date, review_date, review_comment, reviewed_by
```
- 候选键：`transfer_id`
- 非主属性完全函数依赖于候选键
- `reviewed_by` 完全依赖于 `transfer_id`，不构成传递依赖
- ✅ **满足 3NF**

#### ⑪ ScoreAbandon（放弃成绩申请表）
```
abandon_id → sno, cno, reason, status, apply_date, review_date, review_comment, reviewed_by
```
- 候选键：`abandon_id`
- 非主属性完全函数依赖于候选键
- ✅ **满足 3NF**

#### ⑫ RewardPunishment（奖惩记录表）
```
rp_id → sno, type, title, description, rp_date, status, created_by
```
- 候选键：`rp_id`
- 非主属性完全函数依赖于候选键
- `created_by` 完全依赖于 `rp_id`
- ✅ **满足 3NF**

#### ⑬ AwardApplication（奖项申请表）
```
app_id → sno, title, description, file_path, status, apply_date, review_date, review_comment, reviewed_by
```
- 候选键：`app_id`
- 非主属性完全函数依赖于候选键
- ✅ **满足 3NF**

#### ⑭ CourseVideo（课程视频表）
```
video_id → course_id, title, description, file_path, file_size, duration, upload_time, uploaded_by
```
- 候选键：`video_id`
- 非主属性完全函数依赖于候选键
- `course_id` 和 `uploaded_by` 是外键，不构成传递依赖
- ✅ **满足 3NF**

#### ⑮ score_log（成绩日志表）
```
log_id → sno, cno, old_score, new_score, change_time
```
- 候选键：`log_id`
- 非主属性完全函数依赖于候选键
- 无传递依赖
- ✅ **满足 3NF**

### 1.2 结论

> 所有 15 张表均满足第三范式（3NF）。未出现部分依赖和传递依赖，模式设计合理，无需进一步分解。
