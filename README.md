# 自测宝（quiz_app）

声明：该项目全程用 AI 生成，主要使用的是 deepseek-V4-pro 模型。

概述：这是安卓手机的 App，能导入选择题和判断题用来练习。起初是因为我大一下学期挂科了要补考，想用 AI 做一个在手机上就能刷题的 App，题型主要是选择和判断（老师给的题库就是几百道选择和判断题），所以该 App 的功能就是导入题目并刷题。

## 功能

- 顺序练习（自动保留进度）、随机抽题（自定义数量与题型比例）、错题本、答题统计
- 题库管理：搜索、编辑题目、批量增删、回收站恢复
- 导入题库：扫描/批量选择文档、粘贴文本、扫描手机目录、微信文档「用其他应用打开」直接导入

## 快速安装

### 方式一：直接安装 APK（推荐，无需编译）

1. 打开本仓库的 [Releases](https://github.com/zhongys07061/pratice/releases) 页面，下载最新 `app-release.apk`
2. 传到安卓手机，点击安装（首次需允许「安装未知来源应用」）

### 方式二：从源码构建

1. 安装 [Flutter SDK](https://docs.flutter.dev/get-started/install)（Dart 3.11+）
2. 克隆仓库：

   ```bash
   git clone https://github.com/zhongys07061/pratice.git
   cd pratice
   ```

3. 拉取依赖并打包：

   ```bash
   flutter pub get
   flutter build apk --release
   ```

4. 产物在 `build/app/outputs/flutter-apk/app-release.apk`，传到手机安装即可

## 项目结构

| 目录/文件 | 说明 |
|---|---|
| `lib/` | App 源码（入口、页面、服务、数据模型、内置题库） |
| `android/` | Android 原生工程（包名 `com.yourname.zicebao`） |
| `web/` | 网页版支持文件（可选，本项目未使用） |
| `tools/` | 开发用脚本与题目数据（解析原始文档、生成题库，非 App 运行必需） |
| `pubspec.yaml` | Flutter 依赖与版本配置 |

## 题目导入格式

- `|||` 分隔格式：`题干|||A|||B|||C|||D|||答案`，判断题 `题干|||对/错`
- 常见题库格式：`1、题干（A）` + `A、… B、… C、… D、…`
- 聊天记录格式：自动忽略发送者前缀，识别 `答案：X` 行与判断题 `对/错`
