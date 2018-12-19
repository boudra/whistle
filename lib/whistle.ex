defmodule Whistle do
  alias Whistle.Html

  def init() do
    %{text: "hola", tasks: [], error: nil}
  end

  def update(state, {:change_text, text}) do
    %{state | text: text}
  end

  def update(state = %{text: ""}, :add_task) do
    %{state | error: "Please write a task"}
  end

  def update(state = %{text: text, tasks: tasks}, :add_task) do
    %{state | error: nil, text: "", tasks: [text | tasks]}
  end

  def view_error(nil) do
    Html.text("")
  end

  def view_error(error) do
    Html.p([style: "color: red"], [
      Html.text(error)
    ])
  end

  def view_task(task) do
    Html.li([], [Html.text(task)])
  end

  def view(state = %{text: text, tasks: tasks}) do
    Html.div([class: "text"], [
      Html.input([value: text, on: [input: &{:change_text, &1}]], []),
      view_error(state.error),
      Html.button([on: [click: :add_task]], [
        Html.text("Add task")
      ]),
      Html.ul([], Enum.map(tasks, &view_task/1))
    ])
  end
end
