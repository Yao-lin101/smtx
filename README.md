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

3. **模板制作**
   - 添加时间轴
   - 插入图片和台词
   - 设置播放时间
   - 添加分类标签

4. **跟读功能**
   - 录音功能
   - 暂停和取消支持
   - 本地保存录音

### 待实现功能

1. **云同步功能**（预留）
   - 模板云端存储
   - 用户系统

2. **社交功能**（预留）
   - 评论功能
   - 分享录音
   - 点赞功能

## 技术架构

### 核心技术

- **Swift** 和 **SwiftUI** 用于 UI 开发
- **JSON** 用于模板数据存储
- **AVFoundation** 用于音频处理
- **FileManager** 用于文件管理

### 存储架构

#### 文件系统结构
```
Templates/
    ├── local_{template-uuid}/           # 本地模板（未登录用户）
    │   ├── template.json               # 模板数据
    │   ├── cover.jpg                  # 封面图片
    │   ├── images/                    # 时间轴图片
    │   │   ├── {timestamp}_{uuid}.jpg
    │   │   └── ...
    │   └── records/                   # 录音文件
    │       ├── {timestamp}_{uuid}.m4a
    │       └── ...
    └── {uid}_{template-uuid}/          # 用户模板（已登录用户）
        ├── template.json
        └── ...
```

#### 模板数据结构 (template.json)
```json
{
    "version": "1.0",
    "metadata": {
        "id": "template-uuid",
        "creator": {
            "type": "local",           // "local" 或 "user"
            "id": "uid或null"          // 本地用户为null
        },
        "createdAt": "ISO8601时间",
        "updatedAt": "ISO8601时间",
        "status": "local"             // "local", "synced", "modified"
    },
    "template": {
        "title": "模板标题",
        "language": "语言",
        "coverImage": "cover.jpg",
        "totalDuration": 10.5,
        "timelineItems": [
            {
                "id": "uuid",
                "timestamp": 1.5,
                "script": "台词内容",
                "image": "images/1234567890_uuid.jpg"
            }
        ]
    },
    "records": [
        {
            "id": "uuid",
            "createdAt": "ISO8601时间",
            "duration": 10.5,
            "audioFile": "records/1234567890_uuid.m4a"
        }
    ]
}
```

### 命名规范

1. **模板文件夹**
   - 本地模板：`local_{template-uuid}`
   - 用户模板：`{uid}_{template-uuid}`

2. **资源文件**
   - 封面图片：`cover.jpg`
   - 时间轴图片：`{timestamp}_{uuid}.jpg`
   - 录音文件：`{timestamp}_{uuid}.m4a`

3. **相对路径**
   - 所有文件引用使用相对路径
   - 路径相对于模板根目录

## 开发环境

- Xcode 15.0+
- iOS 16.0+
- Swift 5.9
- SwiftUI 4.0

## 安装说明

1. 克隆项目到本地
2. 使用 Xcode 打开 `smtx.xcodeproj`
3. 选择目标设备或模拟器
4. 点击运行按���或按下 `Cmd + R`

## 开发计划

### 第一阶段（已完成）
- [x] 基础框架搭建
- [x] 语言分区管理
- [x] 本地模板管理

### 第二阶段（已完成）
- [x] JSON 模板存储实现
- [x] 模板制作功能
- [x] 录音和回放功能
- [x] 文件管理优化

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