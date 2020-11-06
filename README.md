# AuvalOffice

<!-- MDOC -->

This is a library to define an authorization policy.
It is modeled after the [authorize](https://github.com/jfrolich/authorize) package,
but I made my own for a simple reason:

- I wanted to exercise my Elixir skills and see what happened if I wrote my own

Compared to [authorize](https://github.com/jfrolich/authorize),
this library has a couple of additional features:

- Authorizations return a **justification**.

  The result of an `authorize` call is always a triple `{result, rule, parameters}`
  where `result` is `:ok` or `:error`,
  `rule` specifies the rule that made the decision, and
  `parameters` gives the input parameters for the decision and any additional values that the
  authorization rule chooses to include.
  The reason for this decision is to provide a self-contained context of the decision
  to enable historic auditing.

- Support authorization **context**.

  Authorization rules can make use of a context parameter, for any ambient information
  that is not part of the (Subject, Object, Action) triple to be authorized.

  Additionally, you can define **fetcher** functions to declare context values that
  can be fetched to implement your policy, for example group memberships of a user,
  if that information is not part of your user record.

  Fetcher functions will only be invoked if the context value they fetch is not yet
  part of the context.

## Installation

At the moment, this library is not available on Hex, so install it via a direct github reference:

```elixir
def deps do
  [
    # ...
    {:auval_office, github: "braunse/auval_office"}
  ]
```

## HOWTO

Authorization happens in a **policy module**, which contains all the rules for a specific policy,
and the associated fetchers:

```elixir
defmodule Example.Policy
  use AuvalOffice.Policy

  # To define a policy, list rules one after another.
  # Basic rule syntax is like this:
  rule :a_symbol_or_string_naming_the_rule, action, subject, object do
    # Allow the access, and stop evaluating further rules
    :ok

    # As above, but provide additional decision context (e.g. for building an audit trail)
    {:ok, pigs: :learned_to_fly}

    # Disallow the access, and stop evaluating further rules
    :error

    # As above, but provide additional decision context (e.g. for building an audit trail)
    {:error, moon: :was_not_in_the_seventh_house}

    # Make no decision, and evaluate further rules
    :next
  end

  # Subject and object can be patterns, and bound names are available in the body of the rule
  rule :author_can_edit_blog_post, :edit, %User{id: id}, %Post{author_id: author_id} do
    if author_id == id do
      :ok
    else
      :next
    end
  end

  # Rules can be guarded by a condition.
  # The rule will be skipped unless the condition is true
  rule :author_can_edit_blog_post_shorter_definition, :edit %User{id: id}, %Post{author_id: author_id},
    when: id == author_id,
    do: :ok

  # Rules can refer to context by pattern matching, for example when additional information
  # has to be fetched in the course of evaluation
  rule :author_can_delete_blog_post_while_it_has_no_comments, :delete, %User{id: id}, %Post{author_id},
    context: %{post_comments: 0} do
    if author_id == id, do: :ok, else: :next
  end

  # To fetch the number of blog posts, use a fetcher.
  # You can match on subject, object, action and context.
  # As with rules, a guard clause can be given; the fetcher is skipped when the guard clause evaluates to false
  # Basic syntax:
  fetch :fetcher_id, :field_name, [parameter: pattern] do
    {:ok, value}
    # or {:error, error} to fail evaluation
  end
  
  # For example to fetch the number of blog post comments:
  fetch :blog_post_comment_count, :post_comments, object: %Post{id: id} do
    {:ok, BlogPost.count_comments()}
  end
end
```
