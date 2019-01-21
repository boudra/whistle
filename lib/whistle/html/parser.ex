defmodule Whistle.Html.Parser do
  import NimbleParsec

  require Whistle.Html
  alias Whistle.Html

  defmodule ParseError do
    defexception string: "", line: 0, col: 0, message: "error parsing HTML"

    def message(e) do
      """

      Failed to parse HTML: #{e.message}

      Check your syntax near line #{e.line} and col #{e.col}:

      #{e.string}
      """
    end
  end

  defp string_to_quoted(expr) do
    case Code.string_to_quoted(expr) do
      {:ok, quoted} ->
        quoted

      {:error, {_, reason, _}} ->
        raise %ParseError{string: expr, message: reason}
    end
  end

  defp html_text(string) do
    if Macro.quoted_literal?(string) do
      to_string(string)
    else
      quote do: to_string(unquote(string))
    end
  end

  expr =
    ignore(string("{{"))
    |> repeat(lookahead_not(string("}}")) |> utf8_char([]))
    |> ignore(string("}}"))
    |> reduce({List, :to_string, []})
    |> map(:string_to_quoted)

  tag_name = ascii_string([?a..?z, ?A..?Z], min: 1)

  text =
    utf8_char(not: ?<)
    |> repeat(
      lookahead_not(
        choice([
          ignore(string("<")),
          ignore(string("{{"))
        ])
      )
      |> utf8_char([])
    )
    |> reduce({List, :to_string, []})
    |> map(:html_text)

  whitespace = ascii_char([?\s, ?\n]) |> repeat() |> ignore()

  closing_tag =
    ignore(string("</"))
    |> concat(tag_name)
    |> ignore(string(">"))
    |> unwrap_and_tag(:closing_tag)

  attribute_value =
    ignore(ascii_char([?"]))
    |> repeat(
      lookahead_not(ignore(ascii_char([?"])))
      |> choice([
        ~S(\") |> string() |> replace(?"),
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})

  attribute =
    utf8_string([?a..?z, ?-], min: 1)
    |> concat(whitespace)
    |> optional(
      choice([
        ignore(string("=")) |> concat(expr),
        ignore(string("=")) |> concat(attribute_value)
      ])
    )
    |> wrap()

  opening_tag =
    ignore(string("<"))
    |> concat(tag_name)
    |> unwrap_and_tag(:opening_tag)
    |> repeat(whitespace |> concat(attribute) |> unwrap_and_tag(:attributes))
    |> concat(whitespace)

  comment =
    ignore(string("<!--"))
    |> repeat(lookahead_not(string("-->")) |> utf8_char([]))
    |> ignore(string("-->"))
    |> ignore()

  children =
    parsec(:parse_children)
    |> tag(:child)

  tag =
    opening_tag
    |> choice([
      ignore(string("/>")),
      ignore(string(">"))
      |> concat(whitespace)
      |> concat(children)
      |> concat(closing_tag)
      |> concat(whitespace)
    ])
    |> post_traverse(:validate_node)

  defparsecp(
    :parse_children,
    whitespace
    |> repeat(
      choice([
        tag,
        comment,
        expr |> map(:html_text),
        text
      ])
    )
  )

  defparsecp(:parse_root, parsec(:parse_children) |> eos)

  defp validate_node(_rest, args, context, _line, _offset) do
    opening_tag = Keyword.get(args, :opening_tag)
    closing_tag = Keyword.get(args, :closing_tag)

    cond do
      opening_tag == closing_tag or closing_tag == nil ->
        tag = opening_tag

        attributes =
          Keyword.get_values(args, :attributes)
          |> Enum.reverse()
          |> Enum.map(fn
            ["on-" <> event, value] ->
              {:on, [{String.to_atom(event), value}]}

            [key] ->
              underscore_key = String.replace(key, "-", "_")

              {String.to_atom(underscore_key), true}

            [key, value] ->
              underscore_key = String.replace(key, "-", "_")

              {String.to_atom(underscore_key), value}
          end)

        children =
          args
          |> Keyword.get_values(:child)
          |> Enum.reverse()

        acc =
          if(tag == "program") do
            params = Keyword.get(attributes, :params, Macro.escape(%{}))

            Html.program(
              Keyword.get(attributes, :name),
              params
            )
          else
            Html.build_node(tag, attributes, List.flatten(children))
          end

        {[acc], context}

      true ->
        {:error, "Closing tag #{closing_tag} did not match opening tag #{opening_tag}"}
    end
  end

  defp do_parse(string) do
    case parse_root(string) do
      {:ok, [], _, _, _, _} ->
        nil

      {:ok, [node], _, _, _, _} ->
        node

      {:ok, _, _, _, _, _} ->
        raise %ParseError{
          string: String.slice(string, 0..40),
          line: 1,
          col: 0,
          message: "HTML literals must return one root node"
        }

      {:error, reason, rest, _, {line, col}, _} ->
        raise %ParseError{
          string: String.slice(rest, 0..40),
          line: line,
          col: col,
          message: reason
        }
    end
  end

  defmacro parse(string) do
    do_parse(string)
  end

  defmacro sigil_H({:<<>>, _, [string]}, _) do
    do_parse(string)
  end
end
