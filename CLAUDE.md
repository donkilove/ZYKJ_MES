# CLAUDE.md

> 本文件基于 `AGENTS.md` 生成，供 Claude Code 自动加载。如有冲突，以 `AGENTS.md` 为准。

## 项目概览

ZYKJ_MES —— 制造执行系统（MES），前后端分离架构。

- 后端：Python 3.11+ / FastAPI / SQLAlchemy / PostgreSQL / Alembic
- 前端：Flutter 3.11+ (Dart) / Windows 桌面端
- 测试：Pytest
- CI：GitHub Actions（编码检查）

## 沟通规范

- 默认使用中文沟通、编写提交信息和文档。
- 标识符、API 字段、命令、路径、第三方库名称保持原文。
- 少问多做；仅在需求存在关键歧义、操作不可逆或缺少必要信息时提问。

## 编码规范

- 所有文本文件：UTF-8 无 BOM，LF 行尾。
- Windows 上写文件时必须显式确保 UTF-8 无 BOM。

## 常用命令

```bash
# 启动
python start_backend.py          # 后端
python start_frontend.py         # 前端

# 强制编码检查（代码改动后必须执行）
python backend/scripts/check_chinese_mojibake.py
python backend/scripts/check_frontend_chinese_mojibake.py
python -m pytest test/backend/test_chinese_mojibake_check.py test/backend/test_frontend_chinese_mojibake_check.py -q

# 测试
python -m pytest test/ -q

# 数据库迁移
cd backend && alembic upgrade head
```

## 验证要求

代码改动后，必须执行上述三条编码检查命令并报告结果。任一检查失败则任务未完成。

## Git 约定

- 提交信息默认中文，清楚表达改动意图。
- 未经用户明确要求，不创建提交、分支、标签或发布。

## 工作原则

- 修改前先阅读相关代码和上下文。
- 最小且有效的改动解决实际问题。
- 优先复用现有结构和实现模式。
- 未经要求不做无关重构、风格性改写或大范围清理。
- 不覆盖与当前任务无关的用户修改。
- 不引入 TODO、空桩函数或伪造逻辑作为最终交付。
- 修改公共接口或数据模型时，检查并同步更新受影响的调用方。
- 禁止输出或提交密钥、令牌等敏感信息。

## 项目结构

```
ZYKJ_MES/
├── backend/
│   ├── app/
│   │   ├── api/v1/endpoints/   # API 路由（14 个模块）
│   │   ├── models/             # SQLAlchemy 模型（44 个）
│   │   ├── schemas/            # Pydantic 验证模型
│   │   ├── services/           # 业务逻辑服务
│   │   ├── core/               # 配置、安全、RBAC
│   │   ├── db/session.py       # 数据库会话
│   │   └── main.py             # FastAPI 入口
│   ├── alembic/versions/       # 数据库迁移（34 个）
│   ├── scripts/                # 工具脚本
│   └── requirements.txt
├── mes_client/
│   └── lib/
│       ├── pages/              # 页面组件（39 个）
│       ├── services/           # 前端服务（11 个）
│       ├── models/             # 数据模型
│       └── widgets/            # 可复用组件
├── test/backend/               # 后端测试（15 个）
├── docs/                       # 项目文档
├── start_backend.py
├── start_frontend.py
└── AGENTS.md                   # 代理执行规则（最高优先级）
```
