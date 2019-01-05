defmodule Whistle.Socket do
  alias Whistle.Socket

  defstruct conn: nil, assigns: %{}

  @type t :: %Socket{
          conn: Plug.Conn.t(),
          assigns: map()
        }

  def assign(socket = %{assigns: assigns}, key, value) do
    %{socket | assigns: Map.put(assigns, key, value)}
  end
end
