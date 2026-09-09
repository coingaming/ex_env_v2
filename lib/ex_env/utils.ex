defmodule ExEnv.Utils do
  @moduledoc """

  ExEnv general utilities.

  """

  # Date/time sigils are safe: uppercase sigils never interpolate,
  # so their content is always a literal string evaluated by Kernel.
  @date_time_sigils [:sigil_D, :sigil_T, :sigil_N, :sigil_U]

  @doc """

  Returns :ok if otp_app is acceptable, else raises exception.

  ## Example

    ```
    iex> ExEnv.Utils.validate_otp_app(:hello_world)
    :ok

    iex> ExEnv.Utils.validate_otp_app(:hello_123)
    :ok

    iex> ExEnv.Utils.validate_otp_app(:"123_hello")
    ** (RuntimeError) invalid OTP application name 123_hello

    iex> ExEnv.Utils.validate_otp_app(:"Hello_World")
    ** (RuntimeError) invalid OTP application name Hello_World
    ```

  """

  def validate_otp_app(otp_app) when is_atom(otp_app) do
    ~r/^[a-z][a-z0-9]*(_[a-z0-9]+)*_?$/
    |> Regex.match?(Atom.to_string(otp_app))
    |> case do
      true ->
        :ok

      false ->
        "invalid OTP application name #{otp_app}"
        |> raise
    end
  end

  @doc """

  Returns :ok if config AST is acceptable, else raises exception.

  ## Example

    ```
    iex> quote do [foo: 123] end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do [1, 2, 3] end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do %{hello: "world"} end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do {:hello, "world"} end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do {:hello, "world", 123} end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do [{Hello.World, [foo: "bar"]}] end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do %Date{year: 1990, month: 1, day: 1} end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do ~D[2026-09-09] end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do [starts_at: ~T[10:00:00], created_at: ~N[2026-09-09 10:00:00], deadline: ~U[2026-09-09 10:00:00Z]] end |> ExEnv.Utils.validate_config_ast
    :ok
    iex> quote do ~D[2026-09-09 Calendar.ISO] end |> ExEnv.Utils.validate_config_ast
    :ok

    iex> {:__aliases__, [], [Foo, "Bar"]} |> ExEnv.Utils.validate_config_ast
    ** (RuntimeError) wrong submodule "Bar" name in AST chunk {:__aliases__, [], [Foo, "Bar"]}

    iex> quote do Foo.bar("hello") end |> ExEnv.Utils.validate_config_ast
    ** (RuntimeError) invalid or unsafe config AST {{:., [], [{:__aliases__, [alias: false], [:Foo]}, :bar]}, [], ["hello"]}

    iex> quote do ~D[2026-09-09 Evil.Calendar] end |> ExEnv.Utils.validate_config_ast
    ** (RuntimeError) unsupported calendar Evil.Calendar in sigil ~D[2026-09-09 Evil.Calendar], only Calendar.ISO is allowed

    iex> quote do ~D[2026-09-09]x end |> ExEnv.Utils.validate_config_ast
    ** (RuntimeError) sigil ~D[2026-09-09]x does not accept modifiers

    iex> Code.string_to_quoted!("~s[hello]") |> ExEnv.Utils.validate_config_ast
    ** (RuntimeError) invalid or unsafe config AST {:sigil_s, [delimiter: "[", line: 1], [{:<<>>, [line: 1], ["hello"]}, []]}
    ```

  """

  def validate_config_ast(list) when is_list(list) do
    list
    |> Enum.each(&(:ok = validate_config_ast(&1)))
  end

  def validate_config_ast({:%{}, _, pairs}) when is_list(pairs) do
    pairs
    |> Enum.each(fn {key, value} ->
      :ok = validate_config_ast(key)
      :ok = validate_config_ast(value)
    end)
  end

  def validate_config_ast({:%, _, ast}) do
    :ok = validate_config_ast(ast)
  end

  def validate_config_ast({el1, el2}) do
    :ok = validate_config_ast(el1)
    :ok = validate_config_ast(el2)
  end

  def validate_config_ast({:{}, _, values}) do
    values
    |> Enum.each(&validate_config_ast/1)
  end

  def validate_config_ast(ast = {sigil, _, [{:<<>>, _, [string]}, modifiers]})
      when sigil in @date_time_sigils and is_binary(string) and is_list(modifiers) do
    :ok = validate_sigil_modifiers(ast, modifiers)
    :ok = validate_sigil_calendar(ast, string)
  end

  def validate_config_ast(ast = {:__aliases__, _, submodules = [_ | _]}) do
    submodules
    |> Enum.each(fn sub ->
      unless is_atom(sub) do
        "wrong submodule #{inspect(sub)} name in AST chunk #{inspect(ast)}"
        |> raise
      end
    end)
  end

  def validate_config_ast(data)
      when is_atom(data) or
             is_binary(data) or
             is_number(data) do
    :ok
  end

  def validate_config_ast(ast) do
    "invalid or unsafe config AST #{inspect(ast)}"
    |> raise
  end

  defp validate_sigil_modifiers(_ast, []), do: :ok

  defp validate_sigil_modifiers(ast, _modifiers) do
    "sigil #{Macro.to_string(ast)} does not accept modifiers"
    |> raise
  end

  # Kernel date/time sigils treat a trailing capitalized word
  # (like ~D[2026-09-09 Foo.Bar]) as a calendar module and call it,
  # creating atoms from untrusted input. Only the default calendar is allowed.
  defp validate_sigil_calendar(ast, string) do
    string
    |> String.split(" ")
    |> List.last()
    |> case do
      <<first, _::binary>> = calendar when first in ?A..?Z and calendar != "Calendar.ISO" ->
        "unsupported calendar #{calendar} in sigil #{Macro.to_string(ast)}, only Calendar.ISO is allowed"
        |> raise

      _ ->
        :ok
    end
  end
end
