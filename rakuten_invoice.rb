require 'selenium-webdriver'
require 'pdf-reader'

p 'IDを入力してください'
id = gets.chomp
p 'パスワードを入力してください'
password = gets.chomp
p '取得する年を入力してください'
year = gets.chomp
p '請求書の宛名を入力してください'
$myname = gets.chomp

def getInvoice(session)
  pp "start: #{session.current_url}"
  if !session.find_elements(:name, 'receipt_name').empty?
    receipt_name = session.find_element(:name, 'receipt_name')
    receipt_disabled = receipt_name.attribute('disabled')
    if !receipt_disabled
      receipt_name.send_keys($myname)
    end
    session.find_element(:class, 'receiptBtn').click
    if !session.find_elements(:id, 'invoiceReceiptDonwloadBtn').empty? && !receipt_disabled
      session.find_element(:id, 'invoiceReceiptDonwloadBtn').click
    end
    pp "complete: #{session.current_url}"
  else
    pp "error: #{session.current_url}"
  end
end

# headless指定
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')
# ブラウザの指定(Chrome)
session = Selenium::WebDriver.for :chrome, options: options
# 10秒経過しても進まない場合はエラー
session.manage.timeouts.implicit_wait = 10

# ログイン処理
session.navigate.to 'https://grp02.id.rakuten.co.jp/rms/nid/vc?__event=login&service_id=s08&fidomy=1'
login_form = session.find_element(:name, 'LoginForm')
login_name = session.find_element(:name, 'u')
login_pass = session.find_element(:name, 'p')
login_name.send_keys(id)
login_pass.send_keys(password)
login_form.submit

sleep(1)

# 購入履歴ページへ移動
session.find_element(:xpath, "//a[@aria-label='購入履歴']").click
sleep(1)

# 指定年の購入履歴ページへ移動
year_value = session.find_element(:name, 'display_span')
year_value.send_keys(year)

sleep(1)


# 注文詳細URLの一覧取得

# 一覧ページ数取得
total_item_count = session.find_element(:xpath, "//div[@class='oDrPager']//*[@class='totalItem']").text.to_i
total_item_pages = total_item_count.quo(25).to_f.ceil

# 注文詳細URLの一覧取得
1.upto(total_item_pages) do |num|

  # インボイスの取得
  0.upto(24) do |i|
    item_list_url = 'https://order.my.rakuten.co.jp/?page=myorder&act=list&page_num=' + num.to_s
    session.navigate.to item_list_url
    sleep(1)
    return session.find_elements(:xpath, "//a[@data-ratid='ph_pc_orderdetail']")

    # 注文詳細ページでの処理
    if detail_link_list[i]
      href = detail_link_list[i].attribute('href')
      if href.include?('order.my.rakuten.co.jp')
        session.navigate.to href
        sleep(1)
        getInvoice(session)
        sleep(1)
      else
        pp "error: #{href}"
      end
    else
      pp 'complete: all'
      break
    end
  end
  if total_item_pages == 1
    pp 'complete: all'
    break
  end
  pp "complete: #{num}"
end


# ブラウザを終了
session.quit


# ファイル名を変更
invoice_files = Dir.glob('./*.pdf')
invoice_files.each do |path|
  pdf_file = File.basename(path)
  reader = PDF::Reader.new(pdf_file)
  reader.pages.each do |page|
    if page.number == 1
      page_text = page.text
      price = page_text.match(/([0-9|\,]{1,})円領収しました/)[1]
      full_date = page_text.match(/注文日[:|：][\s]??([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日??/) # 最後の日が別行として読み込まれている場合有
      date = "#{full_date[1]}#{full_date[2]}#{full_date[3]}"
      store = page_text.match(/但し[:|：][\s]??(.+)との取引/)[1]
      new_file_name = "#{date}_#{store}_#{price}.pdf"
      File.rename(pdf_file, new_file_name)
    end
  end
end
