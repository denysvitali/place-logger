require "http/client"
module RedditPlace
  URL = "https://www.reddit.com/api/place/board-bitmap"

  while true
    res = HTTP::Client.get(URL)
    File.write("boards/board_#{Time.new.epoch}.bmp", res.body)
    sleep 30
  end
end
