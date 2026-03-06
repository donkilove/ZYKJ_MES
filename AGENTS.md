# Agent Execution Rules

## Priority
- If there is any conflict between this file and other docs, this file takes precedence for agent execution behavior.

## Encoding And Line Endings
- All newly created or modified text files MUST be UTF-8 without BOM.
- All repository text files MUST use LF line endings.

## Mandatory Encoding Gates
- Encoding checks MUST NOT be skipped before reporting task completion.
- If any encoding check fails, the task is considered incomplete.
- After code changes, run and report these commands:
  - `python backend/scripts/check_chinese_mojibake.py`
  - `python backend/scripts/check_frontend_chinese_mojibake.py`
  - `python -m pytest test/backend/test_chinese_mojibake_check.py test/backend/test_frontend_chinese_mojibake_check.py -q`

## Commit Message Convention
- Git commit messages MUST use Chinese by default.
- If the user explicitly requires another language for a specific commit, follow the user request for that commit.

## Windows Write Requirement
- On Windows, when writing files via scripts or shell, explicitly use UTF-8 without BOM.
- Example for PowerShell: `UTF8Encoding($false)`
