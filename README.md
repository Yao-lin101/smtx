# SMTX - 语言学习模板应用

SMTX 是一个专为语言学习者设计的 iOS 应用，帮助用户创建、管理和练习语言学习模板。

## 功能特点

### 用户系统
- 邮箱注册和登录
- 个人资料管理
  - 头像上传与预览
  - 昵称修改
  - 个人简介编辑
- 用户认证
  - JWT Token 认证
  - Token 自动刷新
  - 本地持久化

### 模板管理
- 按语言分类管理模板
- 支持创建和删除语言分区
- 可自定义模板封面、标题和标签
- 提供编辑和删除功能

### 时间轴编辑
- 创建带有时间点的学习内容
- 支持文字脚本和图片内容
- 灵活的时长设置
- 实时预览时间轴

### 录音练习
- 根据模板内容进行录音练习
- 实时显示录音波形
- 录音完成自动进入预览模式
- 支持录音回放和删除
- 15秒快进/快退功能
- 流畅的动画过渡效果

## 技术特点

- 基于 SwiftUI 构建的原生 iOS 应用
- 使用 CoreData 进行数据持久化
- 集成 AVFoundation 处理音频录制和播放
- 响应式界面设计
- JWT Token 认证
- 图片缓存管理
- 优化的性能和内存管理

## 系统要求

- iOS 16.0 或更高版本
- Xcode 15.0 或更高版本（用于开发）

## 项目结构

```
smtx/
├── Views/                 # 视图相关文件
│   ├── MainTabView       # 主标签视图
│   ├── Profile          # 个人中心相关视图
│   ├── LanguageSection   # 语言分区视图
│   ├── TemplateDetail    # 模板详情视图
│   ├── Recording        # 录音和预览视图
│   └── Components       # 可复用组件
├── Services/            # 服务层
│   ├── AuthService     # 认证服务
│   └── ImageCacheManager # 图片缓存管理
├── Store/              # 状态管理
│   ├── UserStore      # 用户状态管理
│   └── TokenManager   # Token 管理
├── Navigation/         # 导航相关
│   └── NavigationRouter # 导航路由管理
├── Storage/           # 数据存储
│   └── TemplateStorage # 模板存储管理
└── Model/            # 数据模型
    └── CoreData      # CoreData 模型定义
```

### 主要组件

#### 视图层
- `MainTabView`: 应用主界面，管理标签页导航
- `ProfileView`: 个人中心，用户信息展示和管理
- `LocalTemplatesView`: 本地模板列表，支持语言分区管理
- `LanguageSectionView`: 语言分区详情，显示该语言下的所有模板
- `TemplateDetailView`: 模板详情页，管理录音记录
- `RecordingView`: 录音和预览界面，支持录音和回放功能

#### 服务层
- `AuthService`: 处理用户认证相关请求
- `ImageCacheManager`: 管理图片缓存，优化加载性能

#### 状态管理
- `UserStore`: 管理用户状态和信息
- `TokenManager`: 管理认证 Token

#### 数据层
- `TemplateStorage`: 管理模板和录音数据的存储
- `CoreData Model`: 定义数据结构和关系
  - Template: 模板实体
  - TimelineItem: 时间轴项目
  - Record: 录音记录

#### 导航系统
- `NavigationRouter`: 统一管理应用内导航
  - 模板相关路由
    - 语言分区列表 (.languageSection)
    - 模板详情 (.templateDetail)
    - 创建/编辑模板 (.createTemplate)
    - 录音页面 (.recording)
  - 个人中心路由
    - 个人资料 (.profileDetail)
    - 设置 (.settings)
    - 帮助与反馈 (.help)
    - 关于 (.about)
    - 头像预览 (.avatarPreview)

- 导航方式
  - `TabView`: 顶层页面切换（云模板、本地模板、个人中心）
  - `NavigationStack`: 页面层级导航，由 NavigationRouter 统一管理
  - `.sheet`: 模态视图（如登录、注册、图片裁剪等临时性操作）

- 导航特点
  - 统一的路由管理
  - 支持深层导航
  - 状态持久化
  - 类型安全的路由定义
  - 支持导航回退

## 开发计划

### 即将推出的功能
- [ ] 微信登录集成
- [ ] 云端模板同步
- [ ] 练习数据统计
- [ ] 模板分享功能

### 待优化项目
- [ ] 数据备份功能
- [ ] 批量操作支持
- [ ] 更多录音编辑功能
- [ ] 网络请求优化
- [ ] 离线支持

## 文件格式与导出

### 当前格式
- 图片文件：JPEG 格式
- 音频文件：M4A 格式 (AAC 编码)
- 用户头像：JPEG 格式，支持裁剪和预览

### 计划支持的功能
1. 音频格式转换
2. 图片格式转换
3. 批量处理
4. 分享功能

## 许可证

[待定]