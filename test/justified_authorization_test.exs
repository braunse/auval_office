# Copyright (c) 2020 Sebastien Braun
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule AuvalOfficeTest do
  use ExUnit.Case
  doctest AuvalOffice

  defmodule TrivialProhibitivePolicy do
    use AuvalOffice.Policy
  end

  defmodule TrivialPermissivePolicy do
    use AuvalOffice.Policy

    rule(:anyone_can_do_anything, :all, _, _, do: :ok)
  end

  defmodule RBACUser do
    defstruct [:role]

    def with(role), do: %__MODULE__{role: role}
  end

  defmodule RBACPolicy do
    use AuvalOffice.Policy

    rule :admins_can_do_anything, :all, %RBACUser{role: :admin}, _, do: :ok
    rule :readers_can_read, :read, %RBACUser{role: :reader}, _, do: :ok
    rule :writers_can_read_and_write, [:read, :write], %RBACUser{role: :writer}, _, do: :ok
  end

  defmodule RBACPolicy2 do
    use AuvalOffice.Policy

    rule :assistants_cannot_write_strategy, :write, %RBACUser{role: roles}, :financials,
      when: :assistant in roles,
      do: :error

    rule :accounting_can_access_financials, :all, %RBACUser{role: roles}, :financials,
      when: :accounting in roles,
      do: :ok

    rule :assistants_can_access_timesheets, :all, %RBACUser{role: roles}, :timesheet,
      when: :assistant in roles,
      do: :ok
  end

  defmodule ABACUser do
    defstruct [:id]
  end

  defmodule ABACResource do
    defstruct [:owner_id]
  end

  defmodule ABACPolicy do
    use AuvalOffice.Policy

    rule :owner_can_edit, :write, %ABACUser{id: user_id}, %ABACResource{owner_id: owner_id},
      when: user_id == owner_id,
      do: :ok

    rule :everybody_can_read, :read, _, _, do: :ok
  end

  defmodule FetcherPolicy do
    use AuvalOffice.Policy

    @user_db [the_admin: [:admin], the_blogger: [:blogger, :visitor], the_visitor: [:visitor]]

    fetch "groups for user", :groups, subject: %{id: user_id} do
      @user_db[user_id]
    end

    rule "admin_group_can_do_anything", :all, _subject, _object,
      context: %{groups: groups},
      when: :admin in groups do
      :ok
    end

    rule :bloggers_can_post, :post, _subject, _object,
      context: %{groups: groups},
      when: :blogger in groups do
      :ok
    end

    rule :anyone_can_read, :read, _subject, _object do
      :ok
    end
  end

  test "It evaluates a trivially permissive policy" do
    assert {:ok, :anyone_can_do_anything, _} =
             TrivialPermissivePolicy.authorize(:subject, :object, :action)
  end

  test "It evaluates a trivially prohibitive policy" do
    assert {:error, :default_deny, _} =
             TrivialProhibitivePolicy.authorize(:subject, :object, :action)
  end

  test "It evaluates a Role-Based Access Control policy" do
    assert {:ok, _, _} = RBACPolicy.authorize(%RBACUser{role: :admin}, :object, :read)
    assert {:ok, _, _} = RBACPolicy.authorize(%RBACUser{role: :admin}, :object, :write)
    assert {:ok, _, _} = RBACPolicy.authorize(%RBACUser{role: :admin}, :object, :administer)

    assert {:ok, _, _} = RBACPolicy.authorize(%RBACUser{role: :reader}, :object, :read)
    assert {:error, _, _} = RBACPolicy.authorize(%RBACUser{role: :reader}, :object, :write)
    assert {:error, _, _} = RBACPolicy.authorize(%RBACUser{role: :reader}, :object, :administer)

    assert {:ok, _, _} = RBACPolicy.authorize(%RBACUser{role: :writer}, :object, :read)
    assert {:ok, _, _} = RBACPolicy.authorize(%RBACUser{role: :writer}, :object, :write)
    assert {:error, _, _} = RBACPolicy.authorize(%RBACUser{role: :writer}, :object, :administer)
  end

  test "It evaluates a policy with guards" do
    assistant = %RBACUser{role: [:accounting, :assistant]}
    assert {:ok, _, _} = RBACPolicy2.authorize(assistant, :financials, :read)
    assert {:ok, _, _} = RBACPolicy2.authorize(assistant, :timesheet, :read)
    assert {:error, _, _} = RBACPolicy2.authorize(assistant, :financials, :write)

    boss = %RBACUser{role: [:accounting, :boss]}
    assert {:ok, _, _} = RBACPolicy2.authorize(boss, :financials, :read)
    assert {:error, _, _} = RBACPolicy2.authorize(boss, :timesheet, :read)
    assert {:ok, _, _} = RBACPolicy2.authorize(boss, :financials, :write)
  end

  test "It can evaluate a simple Attribute-Based policy" do
    owner = %ABACUser{id: 1}
    another = %ABACUser{id: 2}
    resource = %ABACResource{owner_id: owner.id}

    assert {:ok, _, _} = ABACPolicy.authorize(owner, resource, :read)
    assert {:ok, _, _} = ABACPolicy.authorize(owner, resource, :write)
    assert {:ok, _, _} = ABACPolicy.authorize(another, resource, :read)
    assert {:error, _, _} = ABACPolicy.authorize(another, resource, :write)
  end

  test "It can perform fetcher lookups" do
    admin = %ABACUser{id: :the_admin}
    blogger = %ABACUser{id: :the_blogger}
    visitor = %ABACUser{id: :the_visitor}

    assert {:ok, _, _} = FetcherPolicy.authorize(admin, "a blog post", :delete)
    assert {:ok, _, _} = FetcherPolicy.authorize(admin, "a blog post", :post)
    assert {:ok, _, _} = FetcherPolicy.authorize(admin, "a blog post", :read)

    assert {:error, _, _} = FetcherPolicy.authorize(blogger, "a blog post", :delete)
    assert {:ok, _, _} = FetcherPolicy.authorize(blogger, "a blog post", :post)
    assert {:ok, _, _} = FetcherPolicy.authorize(blogger, "a blog post", :read)

    assert {:error, _, _} = FetcherPolicy.authorize(visitor, "a blog post", :delete)
    assert {:error, _, _} = FetcherPolicy.authorize(visitor, "a blog post", :post)
    assert {:ok, _, _} = FetcherPolicy.authorize(visitor, "a blog post", :read)
  end
end
