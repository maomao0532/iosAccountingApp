# Accounting

Accounting 是一个极简本地记账 iOS App，当前版本为 `1.0`。项目由 Xcode 创建，主工程位于 `Accounting/Accounting.xcodeproj`，后续开发都在该目录下进行。

## 产品定位

这个 App 面向个人日常收支记录，目标是尽量减少记账成本：

- 不需要登录
- 不需要联网
- 数据只保存在本机
- 支持语音快速记账
- 保留手动输入
- 首页查看近期情况
- 统计页查看时间范围内的收支和支出结构

## 1.0 功能

### 语音记账

用户可以说类似：

```text
通过微信支付100元，用于购买早饭
支付宝花了35块买水果
收到工资8000元，通过银行卡入账
```

App 会自动识别并解析：

- 类型：收入 / 支出
- 金额
- 途径：微信、支付宝、银行卡、现金、其他
- 用途或来源
- 时间：使用记录创建时的当前时间

语音识别结果会先展示在确认页中，用户确认后再保存。

### 手动输入

手动输入支持：

- 收入 / 支出切换
- 金额
- 途径
- 时间
- 用途 / 来源

途径选择使用和明细一致的颜色标签：

- 微信：绿色
- 支付宝：蓝色
- 银行卡：紫色
- 现金：橙色
- 其他：灰色

### 首页

首页包含：

- 本月收入
- 本月支出
- 本月结余
- 语音记账入口
- 手动输入入口
- 最近明细，最多显示最近 12 条

最近明细支持：

- 左滑显示“编辑 / 删除”
- 点按“编辑”后进入编辑界面
- 批量选择多条明细后一次性删除

### 统计页

统计页支持按时间范围查看：

- 本月
- 上月
- 今年
- 自定义时间范围

统计内容包括：

- 收入总额
- 支出总额
- 结余
- 支出分类饼状图
- 当前时间范围内的明细

明细支持：

- 左滑显示“编辑 / 删除”
- 批量选择多条明细后一次性删除

### 支出分类饼状图

统计页会把支出用途汇总到固定类别，而不是直接按原始用途文字拆分。

当前内置分类：

- 餐饮
- 购物
- 交通
- 居住
- 娱乐
- 医疗
- 学习办公
- 人情
- 其他

例如：

- 早餐、午饭、奶茶、水果会归入餐饮
- 地铁、打车、高铁会归入交通
- 房租、水电、物业会归入居住
- 无法识别的用途会归入其他

## 本地数据

数据只保存在本机 App 沙盒中，不上传云端。

当前使用 JSON 文件存储：

```text
Documents/ledger_entries.json
```

每条记录包含：

- id
- 类型
- 时间
- 途径
- 金额
- 用途 / 来源
- 原始语音文本

## 权限

语音记账需要：

- 麦克风权限
- 语音识别权限

如果在模拟器中无法使用麦克风，建议检查 macOS 对 Xcode / Simulator 的麦克风授权。中文语音识别在真机上测试会更可靠。

## App 图标

项目已补充 App 图标资源，位于：

```text
Accounting/Accounting/Assets.xcassets/AppIcon.appiconset
```

包含普通、深色、tinted 三套 1024x1024 图标。

## 技术结构

主要代码文件：

```text
Accounting/Accounting/AccountingApp.swift
Accounting/Accounting/ContentView.swift
Accounting/Accounting/LedgerEntry.swift
Accounting/Accounting/LedgerStore.swift
Accounting/Accounting/EntryParser.swift
Accounting/Accounting/VoiceRecorder.swift
```

核心职责：

- `LedgerEntry.swift`：账目模型、类型、支付途径、金额和时间格式
- `LedgerStore.swift`：本地 JSON 存储、增删改查、统计
- `EntryParser.swift`：语音文本解析
- `VoiceRecorder.swift`：麦克风录音和 Speech 语音识别
- `ContentView.swift`：首页、统计页、录入页、编辑页、图表和交互

## 构建

使用 Xcode 打开：

```text
Accounting/Accounting.xcodeproj
```

选择目标设备后运行即可。

命令行构建示例：

```bash
xcodebuild -project Accounting/Accounting.xcodeproj -scheme Accounting -destination 'generic/platform=iOS Simulator' build
```

如果本机没有可用模拟器 runtime、或真机签名 profile 未配置，命令行构建可能会被本机 Xcode 环境拦住；这和 App 代码本身无关。

## 1.0 范围外

当前版本暂不包含：

- 登录
- 云同步
- 多设备同步
- 预算管理
- 账户体系
- 导入导出
- 自定义分类管理

这些功能可以作为后续版本继续扩展。
