defmodule Whistle.Router do
  @callback router(Plug.Conn.t()) :: atom()
end
