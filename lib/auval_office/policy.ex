# Copyright (c) 2020 Sebastien Braun
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule AuvalOffice.Policy do
  @moduledoc """
  Use to make a policy like:

  ```elixir
  defmodule MyPolicy do
    use AuvalOffice.Policy
  end
  ```

  See the high-level docs in `AuvalOffice` to understand what's going on.
  """

  defmacro __using__(_options \\ []) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :rules, accumulate: true)
      Module.register_attribute(__MODULE__, :fetchers, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  defp do_fetch(id, attr, options) do
    subject_param = Keyword.get(options, :subject, quote(do: _))
    object_param = Keyword.get(options, :object, quote(do: _))
    action_param = Keyword.get(options, :action, quote(do: _))
    context_param = Keyword.get(options, :context, quote(do: _))
    guard = Keyword.get(options, :when, quote(do: true))
    fetch_block = Keyword.fetch!(options, :do)
    func_name = String.to_atom("fetch_#{to_string(id)}")

    quote generated: true do
      @fetchers unquote(func_name)
      def unquote(func_name)(s, o, a, c) when not is_map_key(c, unquote(attr)) do
        case {s, o, a, c} do
          {unquote(subject_param), unquote(object_param), unquote(action_param),
           unquote(context_param)}
          when unquote(guard) ->
            Map.put(c, unquote(attr), unquote(fetch_block))

          _ ->
            {:ok, c}
        end
      end

      def unquote(func_name)(_, _, _, c), do: c
    end
  end

  @doc false
  def expand_result(:next, _id), do: :next
  def expand_result(true, id), do: {:ok, id, []}
  def expand_result(false, _id), do: :next
  def expand_result(:ok, id), do: {:ok, id, []}
  def expand_result({:ok, reason}, id), do: {:ok, id, reason}
  def expand_result({:ok, _, reason}, id), do: {:ok, id, reason}
  def expand_result(:error, id), do: {:error, id, []}
  def expand_result({:error, reason}, id), do: {:error, id, reason}
  def expand_result({:error, :default_deny, _reason}, _id), do: :next
  def expand_result({:error, _, reason}, id), do: {:error, id, reason}

  @doc """
  Define a fetcher.
  """
  defmacro fetch(id, attr, options), do: do_fetch(id, attr, options)
  defmacro fetch(id, attr, options, do: fetch_block), do: do_fetch(id, attr, [do: fetch_block] ++ options)

  defp do_rule(id, actions, subject, object, options) do
    rule_block = Keyword.fetch!(options, :do)
    rule_func = String.to_atom("rule_#{to_string(id)}")
    action_param = Keyword.get(options, :action, quote(do: _))
    context_param = Keyword.get(options, :context, quote(do: _))
    guard_clause = Keyword.get(options, :when, quote(do: true))

    quote generated: true do
      @rules {unquote(actions), unquote(rule_func)}
      def unquote(rule_func)(s, o, a, c) do
        case {s, o, a, c} do
          {unquote(subject), unquote(object), unquote(action_param), unquote(context_param)} ->
            if unquote(guard_clause) do
              unquote(rule_block)
            else
              :next
            end

          _ ->
            :next
        end
        |> unquote(__MODULE__).expand_result(unquote(id))
      end
    end
  end

  @doc """
  Define a rule
  """
  defmacro rule(id, actions, subject, object, options), do: do_rule(id, actions, subject, object, options)
  defmacro rule(id, actions, subject, object, options, do: rule_block), do: do_rule(id, actions, subject, object, [do: rule_block] ++ options)

  def make_evaluator() do
    quote do
      @rules_o Enum.reverse(@rules)
      @fetchers_o Enum.reverse(@fetchers)
      def authorize(subject, object, action, context \\ %{}) do
        context =
          @fetchers_o
          |> Enum.reduce({:ok, context}, fn
            func, {:ok, ctx} ->
              apply(__MODULE__, func, [subject, object, action, ctx])

            _func, {:error, _} = err ->
              err

            _func, :error ->
              :error
          end)

        @rules_o
        |> Stream.filter(fn
          {rule_action, _} when is_atom(rule_action) ->
            rule_action == :all || rule_action == action

          {rule_actions, _} when is_list(rule_actions) ->
            :all in rule_actions || action in rule_actions
        end)
        |> Enum.reduce(:next, fn
          {_, func}, :next ->
            apply(__MODULE__, func, [subject, object, action, context])

          rule, short_circuited ->
            short_circuited
        end)
        |> case do
          :next ->
            {:error, :default_deny, []}

          {result, id, reason} ->
            {result, id,
             [subject: subject, object: object, action: action, context: context] ++ reason}
        end
      end
    end
  end

  defmacro __before_compile__(_env) do
    make_evaluator()
  end
end
