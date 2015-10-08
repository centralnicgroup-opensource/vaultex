ExUnit.start()

# set up vault
# run `vault server -dev` somehow automagically so that it keeps running
# and dies at the end of the tests

{:ok, token} = File.read("#{System.user_home}/.vault-token")
IO.puts("Found root token: '#{token}'")
{:ok, :authenticated} = Vaultex.Client.auth({:token, token})
Vaultex.Client.write("sys/auth/app-id", %{"type" => "app-id"})
Vaultex.Client.write("auth/app-id/map/app-id/foo", %{"value" => "root", "display_name" => "foo"})
Vaultex.Client.write("auth/app-id/map/user-id/bar", %{"value" => "foo"})
