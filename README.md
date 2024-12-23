# SMTX - 语言学习模板工具

SMTX 是一个专注于语言学习的 iOS 应用，允许用户创建和管理学习模板，进行跟读练习。

## 功能特点

### 已实现功能

1. **语言分区管理**
   - 预置英语、日语、韩语三个基础分区
   - 支持自定义添加新的语言分区
   - 分区可以独立存在，不依赖于模板
   - 支持删除分区（包括预置分区）

2. **模板管理**
   - 在语言分区下创建学习模板
   - 显示模板创建时间、总时长等信息
   - 支持删除模板
   - 按时间倒序排列展示

### 待实现功能

1. **模板制作**
   - 添加时间轴
   - 插入图片和台词
   - 设置播放时间
   - 添加分类标签

2. **跟读功能**
   - 录音功能
   - 暂停和取消支持
   - 本地保存录音

3. **云同步功能**（预留）
   - 模板云端存储
   - 用户系统

4. **社交功能**（预留）
   - 评论功能
   - 分享录音
   - 点赞功能

## 技术架构

### 核心技术

- **Swift** 和 **SwiftUI** 用于 UI 开发
- **CoreData** 用于本地数据存储
- **AVFoundation**（待实现）用于音频处理
- **FileManager** 用于文件管理

### 数据模型

1. **LanguageSection（语言分区）**
   - id: UUID
   - name: String
   - createdAt: Date
   - templates: [Template]

2. **Template（模板）**
   - id: UUID
   - title: String
   - createdAt: Date
   - coverImageData: Binary
   - totalDuration: Double
   - languageSection: LanguageSection
   - timelineItems: [TimelineItem]
   - records: [VoiceRecord]

3. **TimelineItem（时间轴项目）**
   - id: UUID
   - imageData: Binary
   - script: String
   - timestamp: Double
   - template: Template

4. **VoiceRecord（录音记录）**
   - id: UUID
   - audioFileURL: URL
   - createdAt: Date
   - duration: Double
   - template: Template

### 项目结构 

```
smtx/
├── smtxApp.swift              # 应用入口
├── ContentView.swift          # 主内容视图
├── Persistence.swift          # Core Data 持久化管理
├── smtx.xcdatamodeld/        # Core Data 数据模型
│   └── smtx.xcdatamodel/
├── Navigation/               # 导航管理
│   └── NavigationRouter.swift
├── Views/                    # 视图组件
│   ├── MainTabView.swift     # 主标签视图
│   ├── LanguageSectionView.swift
│   ├── TemplateDetailView.swift
│   ├── CreateTemplateView.swift
│   ├── RecordingView.swift
│   └── RecordDetailView.swift
├── ViewModels/              # 视图模型
│   └── TemplateViewModel.swift
└── Utilities/               # 工具类
    └── FileManager.swift
```

## 主要组件说明

### 1. 导航系统
- `NavigationRouter`: 管理应用内导航和路由
- 实现标签页导航和视图堆栈管理
- 支持模态视图展示

### 2. 视图层级
- `MainTabView`: 底部标签栏，包含云端模板、本地模板和个人中心
- `LanguageSectionView`: 语言分区列表和管理
- `TemplateDetailView`: 模板详情和编辑
- `CreateTemplateView`: 新建模板界面
- `RecordingView`: 录音界面
- `RecordDetailView`: 录音回放和管理

### 3. 数据管理
- Core Data 实现本地数据持久化
- `FileManager` 处理音频文件和图片存储
- `TemplateViewModel` 管理模板相关业务逻辑

## 开发环境

- Xcode 15.0+
- iOS 16.0+
- Swift 5.9
- SwiftUI 4.0

## 安装说明

1. 克隆项目到本地
2. 使用 Xcode 打开 `smtx.xcodeproj`
3. 选择目标设备或模拟器
4. 点击运行按钮或按下 `Cmd + R`

## 开发计划

### 第一阶段（已完成）
- [x] 基础框架搭建
- [x] 语言分区管理
- [x] 本地模板管理

### 第二阶段（进行中）
- [ ] 模板制作功能
- [ ] 录音和回放功能
- [ ] 文件管理优化

### 第三阶段（计划中）
- [ ] 云端同步
- [ ] 用户系统
- [ ] 社交功能

## 贡献指南

1. Fork 项目
2. 创建特性分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证