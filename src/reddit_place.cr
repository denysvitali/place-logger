require "./reddit_place/*"
require "http/web_socket"
require "json"
module RedditPlace
  UA = "Mozilla/5.0 (X11; Linux x86_64; rv:54.0) Gecko/20100101 Firefox/54.0"
  class HTTP::WebSocket::Protocol
    def self.new(host : String, path : String, port = nil, tls = false, query = nil)
        {% if flag?(:without_openssl) %}
          if tls
            raise "WebSocket TLS is disabled because `-D without_openssl` was passed at compile time"
          end
        {% end %}

        port = port || (tls ? 443 : 80)

        socket = TCPSocket.new(host, port)

        {% if !flag?(:without_openssl) %}
          if tls
            if tls.is_a?(Bool) # true, but we want to get rid of the union
              context = OpenSSL::SSL::Context::Client.new
            else
              context = tls
            end
            socket = OpenSSL::SSL::Socket::Client.new(socket, context: context, sync_close: true)
          end
        {% end %}

        headers = HTTP::Headers.new
        headers["Host"] = "#{host}:#{port}"
        headers["Connection"] = "Upgrade"
        headers["Upgrade"] = "websocket"
        headers["Accept-Language"] = "en-US,en;q=0.5"
        headers["Origin"] = "https://www.reddit.com"
        headers["Sec-WebSocket-Version"] = VERSION.to_s
        headers["Sec-WebSocket-Key"] = Base64.strict_encode(StaticArray(UInt8, 16).new { rand(256).to_u8 })
        path = "/" if path.empty?
        handshake = HTTP::Request.new("GET", path + "?#{query}", headers)
        handshake.to_io(socket)
        handshake_response = HTTP::Client::Response.from_io(socket)
        unless handshake_response.status_code == 101
          raise Socket::Error.new("Handshake got denied. Status code was #{handshake_response.status_code}")
        end

        new(socket, masked: true)
    end

    def self.new(uri : URI | String)
        uri = URI.parse(uri) if uri.is_a?(String)

        if (host = uri.host) && (path = uri.path)
          tls = uri.scheme == "https" || uri.scheme == "wss"
          return new(host, path, uri.port, tls, uri.query)
        end

        raise ArgumentError.new("No host or path specified which are required.")
    end
  end

  def self.getSocketUrl
    headers = HTTP::Headers{
        "User-Agent" => UA,
    }
    response = HTTP::Client.get("https://www.reddit.com/r/place/", headers: headers)
    match = response.body.match(/"place_websocket_url": "(.*?)"/)
    if match
      return match[1]
    end
    ""
  end

  uri = URI.parse(RedditPlace.getSocketUrl)
  ws = HTTP::WebSocket.new(uri)
  ws.on_message do |msg|
    json = JSON.parse(msg)
    puts json["payload"].to_json
  end

  ws.run
end
