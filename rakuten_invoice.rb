require 'selenium-webdriver'
require 'pdf-reader'
require 'dotenv'
Dotenv.load

id       = ENV['RAKUTEN_ID']       || (p 'IDを入力してください';       gets.chomp)
password = ENV['RAKUTEN_PASSWORD'] || (p 'パスワードを入力してください'; gets.chomp)
year     = ENV['RAKUTEN_YEAR']     || (p '取得する年を入力してください'; gets.chomp)

if ENV['RAKUTEN_NAME']
  $myname = ENV['RAKUTEN_NAME']
  p "宛名: #{$myname}（.envより）"
else
  loop do
    p '請求書の宛名を入力してください'
    $myname = gets.chomp
    # 一度発行された領収書の宛名は変更不可のため、強めに聞いておく
    p "一度発行された領収書の宛名は変更できません。「#{$myname}」で間違いありませんか？(Y/N)"
    confirmation = gets.chomp.upcase
    break if confirmation == 'Y'
    p '宛名を再入力してください。' if confirmation == 'N'
  end
end

def getInvoice(session)
  pp "start: #{session.current_url}"

  # 初回発行フラグの初期化
  is_first_publish = false

  # 宛名入力フィールドを取得
  receipt_name = session.find_elements(:xpath, "//input[@placeholder='楽天 太郎、楽天株式会社など']").first

  if receipt_name
    # 宛名入力が可能な場合=初回発行なので、フラグをTrueにして名前を入力
    unless receipt_name.attribute('disabled')
      is_first_publish = true
      receipt_name.send_keys($myname)
    end

    # 宛名入力の可否にかかわらず発行するボタンは押す
    issue_button = session.find_elements(:xpath, "//button[@aria-label='発行する']").first
    issue_button&.click

    # 2回目以降の発行の場合、Modalが出現しないのでCompleteを出力
    if !is_first_publish
      pp "complete: #{session.current_url}"

    # 初回発行の場合のみ、発行ボタンを押した後にOKボタンを押すModalが出現する
    else is_first_publish
      # 宛名を入力した場合（初回発行の場合）は「OK」ボタンを取得してクリック
      ok_button = session.find_elements(:xpath, "//div[@aria-label='modal-options-1']//div[text()='OK']").first
      if ok_button
        ok_button.click
        pp "complete: #{session.current_url}"
      else
        pp "error: 宛名は入力しましたが、領収書が出力できません #{session.current_url}"
      end
    end
  else
    # 宛名フィールドがない場合は手動入力対象
    pp "error: 要手動出力 #{session.current_url}"
  end
end

# 保存先ディレクトリを指定（.envのRAKUTEN_DOWNLOAD_PATHで変更可、デフォルト: ./invoices）
download_path = File.expand_path(ENV['RAKUTEN_DOWNLOAD_PATH'] || './invoices')
# 保存先ディレクトリを作成
Dir.mkdir(download_path) unless Dir.exist?(download_path)

# headless指定
options = Selenium::WebDriver::Chrome::Options.new
prefs = {
  'download.default_directory' => download_path, # 保存先を指定
  'download.prompt_for_download' => false,       # ダウンロード確認を無効化
  'download.directory_upgrade' => true,         # 既存のディレクトリを使用
  'plugins.always_open_pdf_externally' => true  # PDFを直接ダウンロード
}
options.add_option(:prefs, prefs) # add_preference を add_option に変更
options.add_argument('--headless')
# ブラウザの指定(Chrome)
session = Selenium::WebDriver.for :chrome, options: options
# 10秒経過しても進まない場合はエラー
session.manage.timeouts.implicit_wait = 10

# ログイン処理（2段階ログイン対応）
# 購入履歴ページへアクセスするとログインページへリダイレクトされる
session.navigate.to 'https://order.my.rakuten.co.jp/'
sleep(3)

# ステップ1: ユーザーID/メールアドレスを入力してEnter（buttonタグは存在しない）
login_name = session.find_element(:id, 'user_id')
login_name.send_keys(id)
login_name.send_keys(:return)
sleep(3)

# ステップ2: パスワードを入力してEnter
login_pass = session.find_element(:id, 'password_current')
login_pass.send_keys(password)
login_pass.send_keys(:return)
sleep(5)

# 購入履歴ページへ移動
session.navigate.to 'https://order.my.rakuten.co.jp/'
sleep(2)

# 指定年の購入履歴ページへ移動
year_value = session.find_element(:name, 'year')
year_value.send_keys(year)

sleep(1)


# 注文詳細URLの一覧取得

# 一覧ページ数取得
list_item_count = 25 # 1ページに表示される商品数（注文数が少ないことによる減少は無視）
total_item_count = session.find_element(:xpath, "//html/body/div[1]/div/div[2]/div/div[1]/div/div[1]/div/div[2]/div[1]/div[3]/div[1]/div/div[1]/div/span").text.gsub(/件/, '').to_i # 合計件数（'件'は不要なため削除）
total_item_pages = total_item_count.quo(list_item_count).to_f.ceil

# 注文詳細URLの一覧取得
# 合計件数から割り出した合計ページ数分ループさせる
1.upto(total_item_pages) do |num|

  # インボイスの取得
  # 1ページごとに処理（0〜24件毎: 計25件
  0.upto(list_item_count - 1) do |i|
    item_list_url = "https://order.my.rakuten.co.jp/purchase-history/order-list/?order_year=#{year}&page=#{num.to_s}" # ページごとのURL
    session.navigate.to item_list_url
    sleep(1)
    detail_link_list = session.find_elements(:xpath, "//a[@aria-label='注文詳細']") # 注文詳細ボタン

    # 注文詳細ページでの処理
    if detail_link_list[i]
      href = detail_link_list[i].attribute('href')
      if href.include?('order.my.rakuten.co.jp') # 注文詳細ページが左記URLの場合、領収書発行が可能なため、それ以外はerrorを返す
        session.navigate.to href
        sleep(1)
        getInvoice(session)
        sleep(1)
      else
        pp "error: #{href}"
      end
    end
  end
  pp "complete: #{num}"
end
pp 'complete: all'

# ブラウザを終了
session.quit

# 領収書pdfファイル名を変更
invoice_files = Dir.glob("#{download_path}/*.pdf")
invoice_files.each do |path|
  reader = PDF::Reader.new(path)

  # pdfの2ページ目に対する処理は不要なので、1ページ目のみ処理する
  reader.pages.each do |page|
    if page.number == 1
      page_text = page.text

      # PDFの内容からファイル名を抽出
      price = page_text.match(/([0-9|\,]{1,})円領収しました/)[1]
      full_date = page_text.match(/注文日[:|：][\s]??([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日??/)
      date = "#{full_date[1]}#{full_date[2].rjust(2, '0')}#{full_date[3].rjust(2, '0')}"
      store = page_text.match(/但し[:|：][\s]??(.+)との取引/)[1]
      base_name = "#{date}_#{store}_#{price}.pdf"
      new_file_name = File.join(download_path, base_name)

      # ファイル名が重複していた場合の処理
      counter = 1
      while File.exist?(new_file_name)
        new_file_name = File.join(download_path, "#{base_name.gsub('.pdf', "_#{counter}.pdf")}")
        counter += 1
      end

      # リネーム
      File.rename(path, new_file_name)
    end
  end
end
