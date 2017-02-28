defmodule VaultexTest do
  use ExUnit.Case
  # doctest Vaultex


  test "write secret/foo" do
    {:ok, data} = Vaultex.Client.write("secret/foo", %{"value" => "bar"})
    assert data == :no_data
  end

  test "read secret/foo" do
    # write first then read
    {:ok, _data} = Vaultex.Client.write("secret/foo", %{"value" => "bar"})
    {:ok, req} = Vaultex.Client.read("secret/foo")
    assert req["data"] == %{"value" => "bar"}
  end

  test "encrypt some data" do
    text = "This is secure!"
    {:ok, res} = Vaultex.Client.encrypt("foo", %{"plaintext" => text})
    assert Map.keys(res["data"]) == ["ciphertext"]
    IO.puts("Got encrypted string: #{res["data"]["ciphertext"]}")

    # and back again
    {:ok, res1} = Vaultex.Client.decrypt("foo", %{"ciphertext" => res["data"]["ciphertext"]})

    # test round trip
    assert text == res1["data"]["plaintext"]
    
  end
end
