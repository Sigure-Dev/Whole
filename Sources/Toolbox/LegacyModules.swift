import SwiftUI
import AVFoundation

// MARK: - Tools モジュール(旧実績ビューの再登録)

let toolsCalculator = ToolboxModule(
    id: "tools.calculator", title: "電卓", summary: "四則演算・パーセント",
    icon: "plus.forwardslash.minus", category: .tools, permissions: [],
    makeView: { AnyView(CalculatorView()) }
)

let toolsUnits = ToolboxModule(
    id: "tools.units", title: "単位変換", summary: "長さ・重さ・温度・データ",
    icon: "arrow.left.arrow.right", category: .tools, permissions: [],
    makeView: { AnyView(UnitConverterView()) }
)

let toolsQRGen = ToolboxModule(
    id: "tools.qrgen", title: "QR生成", summary: "テキストからQR作成",
    icon: "qrcode", category: .tools, permissions: [],
    makeView: { AnyView(QRGeneratorView()) }
)

let toolsQRScan = ToolboxModule(
    id: "tools.qrscan", title: "QRスキャン", summary: "カメラでQR・バーコード",
    icon: "qrcode.viewfinder", category: .tools,
    permissions: [
        PermissionRequirement(name: "カメラ", detail: "QR読み取りに必要") {
            AVCaptureDevice.authorizationStatus(for: .video) == .authorized ? .granted : .denied
        }
    ],
    makeView: { AnyView(QRScannerView()) }
)

let toolsText = ToolboxModule(
    id: "tools.text", title: "テキスト", summary: "文字数・Base64・変換",
    icon: "textformat", category: .tools, permissions: [],
    makeView: { AnyView(TextToolView()) }
)

let toolsColor = ToolboxModule(
    id: "tools.color", title: "カラー", summary: "カラーピッカーとHEX",
    icon: "paintpalette", category: .tools, permissions: [],
    makeView: { AnyView(ColorToolView()) }
)

let toolsNotes = ToolboxModule(
    id: "tools.notes", title: "メモ", summary: "端末内に保存",
    icon: "note.text", category: .tools, permissions: [],
    makeView: { AnyView(NotesView()) }
)

let toolsRandom = ToolboxModule(
    id: "tools.random", title: "ランダム", summary: "ダイス・コイン・乱数",
    icon: "dice", category: .tools, permissions: [],
    makeView: { AnyView(RandomToolsView()) }
)

let toolsCounter = ToolboxModule(
    id: "tools.counter", title: "カウンタ", summary: "タップして数を数える",
    icon: "number", category: .tools, permissions: [],
    makeView: { AnyView(CounterView()) }
)

let toolsStopwatch = ToolboxModule(
    id: "tools.stopwatch", title: "ストップウォッチ", summary: "ラップ付き計測",
    icon: "stopwatch", category: .tools, permissions: [],
    makeView: { AnyView(StopwatchView()) }
)

let toolsTimer = ToolboxModule(
    id: "tools.timer", title: "タイマー", summary: "カウントダウン",
    icon: "timer", category: .tools, permissions: [],
    makeView: { AnyView(TimerToolView()) }
)

let toolsWorldClock = ToolboxModule(
    id: "tools.worldclock", title: "世界時計", summary: "主要都市の現在時刻",
    icon: "clock", category: .tools, permissions: [],
    makeView: { AnyView(WorldClockView()) }
)

let toolsFlashlight = ToolboxModule(
    id: "tools.flashlight", title: "懐中電灯", summary: "ライト点灯・明るさ",
    icon: "flashlight.on.fill", category: .tools, permissions: [],
    makeView: { AnyView(FlashlightView()) }
)
