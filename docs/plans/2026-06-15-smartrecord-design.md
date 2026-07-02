# SmartRecord 设计文档

- 日期：2026-06-15
- 平台：macOS 26 (Tahoe)，SwiftUI + SwiftData 原生应用
- 定位：录屏后自动生成"点击驱动缩放 + 电影级光标"成片，一键多平台导出

## 范围（第一版切片）

本切片聚焦：**录制（屏幕 + 麦克风 + 系统声音）+ 自动缩放 + 电影级光标 + 多平台导出**，全自动、无时间线编辑器。

明确**不在本切片**：填充词/静音剪除、AI 多语言字幕、可拖拽时间线编辑、多显示器录制。

## 核心设计决策

1. **非破坏式后期渲染**：录制只存原始全屏画面 + 音频 + 鼠标元数据；缩放与光标特效在预览/导出时根据元数据实时渲染。原始录制永不改动。
2. **预览与导出共用一套渲染核心**（Core Image）：保证所见即所得。
3. **缩放片段不持久化**：每次渲染从 `clickEvents + settings` 实时计算，改全局参数立即生效。
4. **第一版只录主显示器**：砍掉多屏坐标换算复杂度。
5. **音频默认麦克风/系统声音 50/50 混音**，混音比例为全局参数。
6. **导出默认 H.264**（各平台兼容性最好）。

## 整体架构（四层）

```
UI 层 (SwiftUI)          录制控制 · 实时预览 · 全局参数 · 导出
渲染核心 (Core Image+Metal) 缩放变换 · 光标合成 · 背景留白阴影（预览/导出共用）
采集层                   ScreenCaptureKit(屏幕+系统声音+麦克风) · CGEventTap(点击/光标)
数据层 (SwiftData)        Project · 原始视频引用 · 事件元数据 · 全局参数
```

技术选型：
- 采集：`ScreenCaptureKit`（`SCStream` 一次拿屏幕/系统音/麦克风三路，macOS 15+ 原生支持麦克风捕获）。
- 事件：`CGEventTap` 监听全局鼠标点击与移动，记录 `(时间戳, 坐标, 类型)`，需"辅助功能"权限。
- 渲染：基于 `Core Image` 的渲染函数，预览绘到 `MTKView`，导出逐帧写 `AVAssetWriter`。
- 存储：原始视频存 `.mov`，元数据/项目用 SwiftData（替换模板的 `Item`）。

## 采集层

启动流程：请求权限 → 配置 SCStream（屏幕+系统音+麦克风）→ 启动 CGEventTap → 共用时间基准 → 视频/音频写 .mov、鼠标事件写内存 → 停止时落盘元数据并创建 Project。

**两路数据，一个时钟**：录制起点记 `t0`，SCStream 帧用 presentation timestamp，CGEventTap 事件用 `mach_absolute_time()`，全部换算成"相对录制起点的秒数"以便对齐。

采集的鼠标事件：
- `leftMouseDown` → 触发自动缩放（缩放到点击点）
- `mouseMoved` / `leftMouseDragged` → 重建光标轨迹做平滑

音频：`SCStreamConfiguration` 同开系统声音与麦克风捕获，写入时混成一条音轨。

坐标系：CGEventTap 给屏幕全局坐标（左上原点），SCStream 给某 display 像素缓冲；第一版只录主屏规避换算。

## 元数据模型与自动缩放算法

### 自动缩放（无需用户设置）
```
输入：点击事件 [(t, x, y), ...]
输出：缩放片段 [(开始t, 结束t, 中心x, 中心y, 缩放倍数), ...]

规则：
1. 每次点击 → 一个放大意图，点击前 0.3s 开始放大
2. 相邻点击间隔 < 2s 且位置相近 → 合并成连续缩放
3. 点击后 1.5s 无新点击 → 平滑缩回原始尺寸
4. 缩放倍数固定 1.8x（全局参数可调 1.2~2.5x）
5. 缩放中心 = 点击点，边缘约束避免露出画面外黑边
```
缓动：放大/缩回用 `easeInOut`（spring 阻尼），不可线性突变——这是"电影感"来源。

### 光标轨迹平滑（电影级运动）
```
原始 mouseMoved → 重采样到帧率
→ Catmull-Rom 样条插值
→ 速度自适应：快速移动轻微放大+拖尾，停下弹性回弹
→ 可选轻微透视倾斜模拟 3D（全局开关，默认关）
```

### SwiftData 数据模型（替换模板 Item）
```
Project
  ├ id, 创建时间, 时长
  ├ rawVideoURL (.mov 文件路径)
  ├ clickEvents: [ClickEvent]      // 原始，不可变
  ├ cursorSamples: [CursorSample]  // 原始，不可变
  └ settings: RenderSettings        // 全局参数，可调
       ├ zoomScale, zoomEnabled
       ├ cursorSmoothing, cursor3D
       ├ backgroundPadding, cornerRadius
       └ micSystemMix
```
缩放片段不存，每次渲染从 `clickEvents + settings` 实时算。

## 渲染管线（预览 + 导出共用）

**一个纯函数，两个出口。**
```
renderFrame(time t, rawFrame, metadata, settings) -> CIImage
  1. 原始帧 (CVPixelBuffer → CIImage)
  2. 算 t 时刻缩放状态（clickEvents + 缓动）→ 仿射变换（缩放+平移到中心）
  3. 算 t 时刻光标位置（样条+弹性）→ 合成光标图层（可选 3D 倾斜+拖尾）
  4. 背景留白：结果缩小+圆角+阴影，叠在渐变背景上
  5. 返回合成 CIImage
```

| | 预览 | 导出 |
|---|---|---|
| 驱动 | CADisplayLink 按播放头取 t | 逐帧 t = 0,1/fps,2/fps... |
| 取帧 | AVPlayerItemVideoOutput | AVAssetReader 顺序读 |
| 出口 | 渲染到 MTKView | AVAssetWriter 写新 .mov |
| 音频 | 原始播放 | 混音轨拷贝+重新封装 |

所见即所得：预览与导出调同一个 `renderFrame`。

导出预设（只改分辨率/宽高比/码率，渲染逻辑不变）：
- X / YouTube → 16:9，最高 4K (3840×2160)
- TikTok / Instagram → 9:16 竖屏 (1080×1920)，背景留白自动补足
- Instagram 方形 → 1:1
- 编码：H.264（默认），AVAssetWriter 硬件加速

竖屏预设：16:9 录屏放进 9:16 画布时，上下用渐变背景自动补满，不变形。

性能：4K 逐帧渲染走后台 + 进度条；预览可降半分辨率保流畅。

## UI 与流程（线性，零学习成本）

三个界面：
1. **主界面**：开始录制按钮 + 最近项目列表（SwiftData 读取）。
2. **录制中悬浮窗**：无边框 NSPanel，录制时用 ScreenCaptureKit `excludingWindows` 排除自身，不进画面。
3. **编辑/导出**：左侧大预览 (MTKView)，右侧全局参数面板（缩放强度/光标平滑/背景留白/3D 光标开关/麦系混音）+ 一条可拖动播放进度条（非可编辑时间线）+ 导出按钮（4 预设）。

关键交互：拖任意滑块 → 预览实时重渲染（缩放片段实时算）。滑动时半分辨率快速预览，松手后渲染一帧全分辨率。

## 工程结构

```
SmartRecord/
├ SmartRecordApp.swift          // @main, SwiftData 容器
├ Models/  Project / ClickEvent / CursorSample / RenderSettings
├ Capture/ ScreenRecorder(SCStream) / MouseEventTap(CGEventTap)
├ Render/  FrameRenderer(★核心) / ZoomSolver / CursorSolver / VideoExporter
├ Views/   HomeView / RecordingPanel / EditorView
└ Info.plist  权限声明
```

## 权限

- 屏幕录制：`NSScreenCaptureUsageDescription`（系统自动弹）
- 麦克风：`NSMicrophoneUsageDescription`
- 辅助功能：CGEventTap 需要，引导用户去系统设置授权（无法纯代码弹窗）

## 里程碑（每步可独立验证）

```
M1 采集闭环   录主屏+音频出 .mov，事件落盘        验证:能播放,事件数>0
M2 渲染核心   renderFrame 出单帧静态缩放          验证:导出一帧PNG肉眼对
M3 自动缩放   ZoomSolver+缓动,预览看到推拉        验证:点击处平滑放大
M4 光标+背景  平滑光标+留白阴影渐变               验证:预览质感达标
M5 导出       4预设+H.264+进度                    验证:4个文件各平台能放
M6 收尾       权限引导+最近项目+悬浮窗排除自身     验证:全流程跑通
```

## 测试策略

- `ZoomSolver` / `CursorSolver` 是纯函数 → 单元测试（给定事件序列，断言输出片段）。
- 渲染/采集靠手动验证 + 导出帧比对。
