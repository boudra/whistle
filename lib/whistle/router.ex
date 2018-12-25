defmodule Whistle.Router do
  defmacro __using__(_opts) do
    quote do
      # @behaviour Whistle.Router
      import Whistle.Router
    end
  end

  defmacro route(expr, program, params) do
    match =
      expr
      |> String.split(":")
      |> case do
        [topic, "*"] ->
          quote do: "#{unquote(topic)}:" <> _

        [topic, subtopic] ->
          quote do: "#{unquote(topic)}:#{unquote(subtopic)}"
      end

    quote do
      def __route(unquote(match)) do
        {:ok, unquote(program), unquote(params)}
      end
    end
  end
end
