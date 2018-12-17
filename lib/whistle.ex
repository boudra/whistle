defmodule Whistle do
  @moduledoc """
  Documentation for Whistle.
  """

  alias Whistle.Html

  def init() do
    %{number: 0, text: "hola"}
  end

  def update(state, {:change_text, text}) do
    %{state | text: text}
  end

  def update(state = %{number: number}, {:increment, n}) do
    %{state | number: number + n}
  end

  def update(state = %{number: number}, {:decrement}) do
    %{state | number: number - 1}
  end

  def view(%{number: number, text: text}) do
    number = number |> Integer.to_string() |> Html.text()

    {0,
     Html.div([class: "text"], [
       Html.p([], [Html.text(text)]),
       Html.node("input", [value: text, on_input: &{:change_text, &1}], []),
       Html.p([], [number]),
       Html.button([on_click: {:increment, 2}], [
         Html.text("+1")
       ]),
       Html.button([on_click: {:decrement}], [
         Html.text("-1")
       ])
     ])}
  end
end
