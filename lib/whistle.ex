defmodule Whistle do
  alias Whistle.Html

  def init() do
    %{text: "hola", tasks: [], error: nil}
  end

  def update(state, {:change_text, text}) do
    %{state | text: text}
  end

  def update(state = %{tasks: tasks}, {:trigger_task, index}) do
    tasks =
      tasks
      |> Enum.with_index()
      |> Enum.map(fn {{done, task}, task_index} ->
        if task_index == index do
          {not done, task}
        else
          {done, task}
        end
      end)

    %{state | tasks: tasks}
  end

  def update(state = %{text: ""}, :add_task) do
    %{state | error: "Please write a task"}
  end

  def update(state = %{text: text, tasks: tasks}, :add_task) do
    %{state | error: nil, text: "", tasks: tasks ++ [{false, text}]}
  end

  def view_error(nil) do
    Html.text("")
  end

  def view_error(error) do
    Html.p([style: "color: red"], [
      Html.text(error)
    ])
  end

  def view_task({{done, task}, index}) do
    style =
      if done do
        "color: green"
      else
        ""
      end

    Html.li([style: style], [
      Html.input([
        type: "checkbox",
        on: [
          change: {:trigger_task, index}
        ],
        checked: done
      ], []),
      Html.text(task)
    ])
  end

  def view(state = %{text: text, tasks: tasks}) do
    tasks =
      tasks
      |> Enum.with_index()
      |> Enum.map(&view_task/1)

    Html.div([class: "text"], [
      Html.input([value: text, on: [input: &{:change_text, &1}]], []),
      view_error(state.error),
      Html.button([on: [click: :add_task]], [
        Html.text("Add task")
      ]),
      Html.ul([], tasks)
    ])
  end
end
