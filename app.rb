require 'sinatra/base'
require 'json'
require 'rest-client'
require 'rakuten_web_service'

class App < Sinatra::Base
  post '/linebot/callback' do
    params = JSON.parse(request.body.read)

    RakutenWebService.configuration do |c|
      c.application_id = ENV["RAKUTEN_APPLICATION_ID"]
      c.affiliate_id = ENV["RAKUTEN_AFFILIATE_ID"]
    end

    params['result'].each do |msg|
      keyword = msg['content']["text"]
      items = RakutenWebService::Ichiba::Item.search(:keyword => keyword, :shopCode => ENV["RAKUTEN_SHOPCODE"], :genreId => ["RAKUTEN_GENREID"])

      if items.count == 0
        messages = [ "ごめんね。#{keyword} では見つからなかったよ" ]
      else
        item = items.sort_by{rand}[0,1].first
        messages = [
                     "#{keyword} が欲しいんだね！\n\n#{item['itemName']} なんてどう？\n\n値段は#{item['itemPrice']} 円だよ。",
                     "詳しい情報はここから見てみてね\n\n#{item['itemUrl']}"
                   ]
      end

      endpoint_uri = 'https://trialbot-api.line.me/v1/events'
      RestClient.proxy = ENV['FIXIE_URL'] if ENV['FIXIE_URL']

      request_header = {
        'Content-Type' => 'application/json; charset=UTF-8',
        'X-Line-ChannelID' => ENV["LINE_CHANNEL_ID"],
        'X-Line-ChannelSecret' => ENV["LINE_CHANNEL_SECRET"],
        'X-Line-Trusted-User-With-ACL' => ENV["LINE_CHANNEL_MID"]
      }

      request_content = {
        to: [msg['content']['from']],
        toChannel: 1383378250,
        eventType: "138311608800106203",
        content: msg['content']
      }

      # POST texts
      messages.each do |message|
        msg['content']['text'] = message
        request_content['content'] = msg['content']
        content_json = request_content.to_json

        RestClient.post(endpoint_uri, content_json, request_header)
      end

      # POST image
      msg['content']['contentType'] = 2
      msg['content']['originalContentUrl'] = item['mediumImageUrls'].first['imageUrl']
      msg['content']['previewImageUrl'] = item['mediumImageUrls'].first['imageUrl']
      request_content['content'] = msg['content']
      content_json = request_content.to_json
      RestClient.post(endpoint_uri, content_json, request_header)
    end
    "OK"
  end
end
