defmodule Whistle.Router do
  @callback join(Plug.Conn.t(), map()) :: {:ok, atom()}
end
