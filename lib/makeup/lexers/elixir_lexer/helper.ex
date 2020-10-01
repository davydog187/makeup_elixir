defmodule Makeup.Lexers.ElixirLexer.Helper do
  @moduledoc false
  import NimbleParsec
  alias Makeup.Lexer.Combinators
  alias Makeup.Lexers.ElixirLexer.BST

  defmacro defbstfinder(name, list) do
    {evaluated_list, _} = Code.eval_quoted(list)
    bst = BST.create(evaluated_list)
    name__0 = String.to_atom(Atom.to_string(name) <> "__0")

    quote do
      def unquote(name)(input) do
        unquote(name__0)(input, [], [], %{}, {1, 0}, 0)
      end

      def unquote(name__0)(<< char::utf8, rest::binary >> = input, acc, stack, context, line_offset, column) do
        bst = unquote(Macro.escape(bst))
        case Makeup.Lexers.ElixirLexer.BST.find(bst, char) do
          true ->
            bin = << char::utf8 >>
            length = byte_size(bin)
            # -----------------------------------------------------------------
            # For efficiency reason ignore line numbers; we won't be using them
            # -----------------------------------------------------------------
            {:ok, [bin | acc], rest, context, line_offset, column + length}

          false ->
            {:error, "expected to match given pattern", input, context,
             line_offset, column}
        end
      end

      def unquote(name__0)("", acc, stack, context, line_offset, column) do
        {:error, "expected to match given pattern", "", context, line_offset, column}
      end

      def unquote(name__0)(input, acc, stack, context, line_offset, column) do
        {:error, "expected to match given pattern", input, context, line_offset, column}
      end
    end
  end

  def with_optional_separator(combinator, separator) when is_binary(separator) do
    combinator |> repeat(string(separator) |> concat(combinator))
  end

  # Allows escaping of the first character of a right delimiter.
  # This is used in sigils that don't support interpolation or character escapes but
  # must support escaping of the right delimiter.
  def escape_delim(rdelim) do
    rdelim_first_char = String.slice(rdelim, 0..0)
    string("\\" <> rdelim_first_char)
  end

  def sigil(ldelim, rdelim, ranges, middle, ttype, attrs \\ %{}) do
    left = string("~") |> utf8_string(ranges, 1) |> string(ldelim)
    right = string(rdelim)

    choices = middle ++ [utf8_char([])]

    left
    |> repeat(lookahead_not(right) |> choice(choices))
    |> concat(right)
    |> optional(utf8_string([?a..?z, ?A..?Z], min: 1))
    |> post_traverse({Combinators, :collect_raw_chars_and_binaries, [ttype, attrs]})
  end

  def escaped(literal) when is_binary(literal) do
    string("\\" <> literal)
  end

  def keyword_matcher(kind, fun_name, words) do
    heads =
      for {ttype, words} <- words do
        for word <- words do
          case kind do
            :defp ->
              quote do
                defp unquote(fun_name)([{:name, attrs, unquote(ttype)} | tokens]) do
                  [{unquote(ttype), attrs, unquote(word)} | unquote(fun_name)(tokens)]
                end
              end
              |> IO.inspect()

            :def ->
              quote do
                def unquote(fun_name)([{:name, attrs, unquote(ttype)} | tokens]) do
                  [{unquote(ttype), attrs, unquote(word)} | unquote(fun_name)(tokens)]
                end
              end
          end
        end
      end

    quote do
      (unquote_splicing(heads))
    end
  end
end
