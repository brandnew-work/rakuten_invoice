# 楽天の指定年の領収書を一括でダウンロード｜Selenium（Ruby）
[brandnew.work](https://brandnew.work/) の記事より  
詳細は[こちら](https://brandnew.work/column/ruby/dl-all-rakuten_invoices/)から

## 留意点
通常とは異なる領収書発行が必要な決済については手動  
現在確認済み（楽天Kobo・ビックカメラ）

## 環境
- WSL / Mac Sonoma 14.6.1
- ruby 3.1.2p20
- selenium-webdriver 4.17.0
- pdf-reader 2.12.0

## Update
### 2025.01
- 楽天の仕様変更に伴う修正  
- pdfの保存先を指定できるよう調整
