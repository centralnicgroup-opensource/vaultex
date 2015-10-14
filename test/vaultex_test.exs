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
    # every now and then vault is too slow on my laptop and triggers a
    # false positive here :( [norbu09]
    {:ok, data} = Vaultex.Client.read("secret/foo")
    assert data == %{"value" => "bar"}
  end

  test "encrypt some data" do
    text = "This is secure!"
    {:ok, res} = Vaultex.Client.write("transit/encrypt/foo",
      %{"plaintext" => text  |> Base.encode64})
    assert Map.keys(res["data"]) == ["ciphertext"]
    IO.puts("Got encrypted string: #{res["data"]["ciphertext"]}")

    # and back again
    {:ok, res1} = Vaultex.Client.write("transit/decrypt/foo", %{"ciphertext" => res["data"]["ciphertext"]})

    # test round trip
    {:ok, text1} = res1["data"]["plaintext"] |> Base.decode64
    assert text == text1
    
  end
end
