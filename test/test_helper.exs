ExUnit.start()

defmodule TestHelper do
  def request do
    %{
      bindings: %{},
      body_length: 0,
      cert: :undefined,
      has_body: false,
      headers: %{
        "accept-encoding" => "gzip, deflate, br",
        "accept-language" => "en-US,en;q=0.9,da;q=0.8,nb;q=0.7,sv;q=0.6",
        "cache-control" => "no-cache",
        "connection" => "Upgrade",
        "cookie" => "_foo_key=cookie",
        "host" => "localhost:4000",
        "origin" => "http://localhost:4000",
        "pragma" => "no-cache",
        "sec-websocket-extensions" => "permessage-deflate; client_max_window_bits",
        "sec-websocket-key" => "asdasdasdasd==",
        "sec-websocket-version" => "13",
        "upgrade" => "websocket",
        "user-agent" =>
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36"
      },
      host: "localhost",
      host_info: :undefined,
      method: "GET",
      path: "/ws",
      path_info: :undefined,
      peer: {{127, 0, 0, 1}, 56570},
      pid: "pid",
      port: 4000,
      qs: "",
      ref: HTTP,
      scheme: "http",
      sock: {{127, 0, 0, 1}, 4000},
      streamid: 1,
      version: :"HTTP/1.1"
    }
  end
end
