# 技术架构文档

## 1. 架构设计
纯前端应用，无后端服务。数据存储使用浏览器 LocalStorage。

```mermaid
graph TD
    User[用户] --> Frontend[React 前端应用]
    Frontend --> GameLoop[游戏循环 Hook]
    Frontend --> Render[Canvas/Grid 渲染]
    Frontend --> Storage[LocalStorage (最高分)]
```

## 2. 技术说明
- **前端框架**: React@18 + TypeScript
- **构建工具**: Vite
- **样式方案**: TailwindCSS@3 (用于 UI 布局和霓虹特效)
- **状态管理**: Zustand (用于管理分数、游戏状态)
- **游戏引擎**: 自研简易 Grid 系统 (基于 React State 或 Ref 驱动)

## 3. 路由定义
| 路由 | 用途 |
|-------|---------|
| / | 游戏主页面，包含所有功能 |

## 4. 数据模型
### 4.1 本地存储 Schema
- `snake_game_highscore`: string (数字)

### 4.2 游戏内部状态 (TypeScript Interface)
```typescript
type Direction = 'UP' | 'DOWN' | 'LEFT' | 'RIGHT';

interface Position {
  x: number;
  y: number;
}

interface GameState {
  snake: Position[];
  food: Position;
  direction: Direction;
  score: number;
  status: 'IDLE' | 'PLAYING' | 'PAUSED' | 'GAME_OVER';
  speed: number;
}
```
