defmodule VaultexTest do
  use ExUnit.Case, async: false
  # doctest Vaultex


  test "authenticate the app" do
    res = Vaultex.Client.auth({:user_id, "bar"})
    assert res == {:ok, :authenticated}
  end

  test "write secret/foo" do
    {:ok, data} = Vaultex.Client.write("secret/foo", %{"value" => "bar"})
    assert data == :no_data
  end

  test "read secret/foo" do
    {:ok, data} = Vaultex.Client.read("secret/foo")
    assert data == %{"value" => "bar"}
  end
end
