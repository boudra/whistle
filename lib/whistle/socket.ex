defmodule Whistle.Socket do
  alias Whistle.Socket

  defstruct assigns: %{}

  @type t :: %Socket{
          assigns: map()
        }

  def assign(socket = %{assigns: assigns}, key, value) do
    %{socket | assigns: Map.put(assigns, key, value)}
  end
end
