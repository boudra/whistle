defmodule Whistle.Navigation do
  alias Whistle.Html
  require Whistle.Html

  def link(path, attributes, children) do
    Html.a(
      attributes ++
        [
          href: path,
          on: [
            click: [
              prevent_default: true,
              msg: {:_whistle_navigate, path_to_segments(path)}
            ]
          ]
        ],
      children
    )
  end

  def html(attributes, children) do
    Html.html(attributes ++ [on: [history: &{:_whistle_update_path, &1}]], children)
  end

  def path_to_segments(path) do
    String.split(path, "/", trim: true)
  end

  defmacro __using__(_opts) do
    quote do
      alias Whistle.Navigation

      def update({:_whistle_navigate, path}, state, session) do
        path_info = Navigation.path_to_segments(path)

        case update({:whistle_navigate, path}, state, session) do
          {:ok, state, session} ->
            {:reply, state, %{session | path: path_info}, ["whistle_push_state", path]}
        end
      end

      def update({:_whistle_update_path, path}, state, session) do
        path_info = Navigation.path_to_segments(path)

        {:ok, state, %{session | path: path}}
      end
    end
  end
end
