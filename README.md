# Whole

多機能ユーティリティ iOS アプリ(17機能)。
**Liquid Glass 風のフローティングドックバー**で画面を切り替え、右端の **設定** から外観・アクセントカラー・**アプリアイコン** などをアプリ内で変更できます。

ビルドは GitHub Actions が **未署名(unsigned)IPA** を自動生成します。eSign などでサイドロードして使用します。

![アイコン](Resources/icon.png)

## 機能 (17)

| 分類 | 機能 |
|---|---|
| 変換・コード | 電卓 / 単位変換 / QRコード生成 / QRスキャナー / テキストツール / カラーツール |
| ツール | メモ(端末保存) / ランダム(ダイス・コイン・乱数) / カウンタ / トーン発生 / 懐中電灯 |
| 計測・デバイス | ストップウォッチ / タイマー / 世界時計 / デバイス情報 / モーション(加速度・ジャイロ・水準器) / コンパス |

## 画面構成

- 下部に **Liquid Glass ドックバー**(すりガラス素材 + 選択ピルがスライド)。
  - ホーム(全機能ランチャー) / ツール / 計測 / 変換 / **設定**
- 設定で変えられるもの:
  - 外観モード(システム / ライト / ダーク)
  - アクセントカラー(6色)
  - **アプリアイコン**(デフォルト / オーシャン / サクラ / サンセット / フォレスト)
  - ハプティクス ON/OFF、効果音 ON/OFF
  - ホーム画面のカード列数(2〜4列)
  - 設定リセット

## GitHub でビルドする

1. このフォルダを GitHub リポジトリに push:

   ```powershell
   cd D:\Whole
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/<あなたのユーザー名>/Whole.git
   git push -u origin main
   ```

2. GitHub の **Actions → Build IPA** が自動実行され、緑になったら run を開く。
3. **Artifacts → Whole-unsigned-ipa** をダウンロード → `Whole-unsigned.ipa`。
4. タグ `v1.0` などを push すると Release に IPA が添付されます。

Xcode プロジェクト(`Whole.xcodeproj`)は [XcodeGen](https://github.com/yonaskolb/XcodeGen) が CI 内で `project.yml` から自動生成します(ローカルにコミット不要)。

## eSign でインストール

1. IPA を iPhone へ転送(AirDrop / iCloud / ファイルアプリ)。
2. eSign で IPA を開き、自分の証明書で署名してインストール。
3. 「設定 → 一般 → VPNとデバイス管理」で証明書を信頼。

## カスタマイズ

- **アイコン差し替え**: `Resources/icon.png` を入れ替え → `python Tools/gen_app_icons.py` で代替アイコン再生成(Pillow / numpy 必須)。
- **バージョン**: `project.yml` の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`。
- **機能追加**: `Sources/Features/` に View を追加 → `project.yml` はそのまま → `Sources/RootView.swift` の `FeatureData` に登録。

## 構成

```
Whole/
├── project.yml                 # XcodeGen 定義
├── Sources/
│   ├── Info.plist              # 権限 + 代替アイコン登録
│   ├── WholeApp.swift
│   ├── RootView.swift          # タブ構成 + Liquid Glass バー
│   ├── SettingsView.swift      # 設定ストア + 設定画面
│   ├── Utils.swift
│   └── Features/               # 17機能
├── Resources/
│   ├── icon.png                # 元アイコン
│   └── Assets.xcassets/        # AppIcon + 代替アイコン4種 + プレビュー
├── Tools/gen_app_icons.py      # アイコン生成スクリプト
└── .github/workflows/build.yml # unsigned IPA ビルド
```

## 動作要件

- iOS 15.0+(eSign でサイドロード)
- カメラ(QRスキャナー)・位置情報(コンパス)は初回起動時に権限を要求
