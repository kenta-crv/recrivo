# frozen_string_literal: true

require "net/http"
require "nokogiri"

module SituationJobInfo
  # 公開URLから本文テキストを取得する（媒体特化スクレイピングではない）。
  # JS描画・ログイン壁・ボット拒否では失敗しうる → 呼び出し側で貼り付けフォールバック。
  class PageFetcher
    class FetchError < StandardError; end

    MAX_CHARS = 20_000
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    USER_AGENT = "RecrivoJobInfoBot/1.0 (+https://recrivo.pro)"

    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url.to_s.strip
    end

    def call
      uri = parse_uri!
      response = request(uri)
      unless response.is_a?(Net::HTTPSuccess)
        raise FetchError, "ページを取得できませんでした（HTTP #{response.code}）"
      end

      text = extract_text(response.body.to_s)
      raise FetchError, "ページから本文を抽出できませんでした。求人テキストの貼り付けをお試しください。" if text.blank?

      text
    rescue FetchError
      raise
    rescue StandardError => e
      Rails.logger.warn("[SituationJobInfo::PageFetcher] #{e.class}: #{e.message}")
      raise FetchError, "URLの読み取りに失敗しました。求人テキストの貼り付けをお試しください。"
    end

    private

    def parse_uri!
      raise FetchError, "URLを入力してください" if @url.blank?

      uri = URI.parse(@url)
      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        raise FetchError, "http/https のURLを指定してください"
      end
      uri
    rescue URI::InvalidURIError
      raise FetchError, "URLの形式が正しくありません"
    end

    def request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      req["Accept"] = "text/html,application/xhtml+xml"
      http.request(req)
    end

    def extract_text(html)
      doc = Nokogiri::HTML(html)
      doc.search("script, style, noscript, nav, footer, header, iframe, svg").remove

      main = doc.at_css("main, article, [role='main'], .job, .job-description, #content, .content") || doc.at_css("body")
      return "" unless main

      text = main.text.to_s.gsub(/\u00a0/, " ").gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip
      text.truncate(MAX_CHARS, omission: "")
    end
  end
end
