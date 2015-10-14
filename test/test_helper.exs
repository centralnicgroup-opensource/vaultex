ExUnit.start()

# set up vault
# run `vault server -dev` somehow automagically so that it keeps running
# and dies at the end of the tests
#
# vault server -dev
# PID=ps ax | grep "vault server -dev" | grep -v grep | cut -d " " -f 1
# and at the end $ kill ${PID}

{:ok, token} = File.read("#{System.user_home}/.vault-token")
IO.puts("Found root token: '#{token}'")
{:ok, :authenticated} = Vaultex.Client.auth({:token, token})

# setup app-id
Vaultex.Client.write("sys/auth/app-id", %{"type" => "app-id"})
Vaultex.Client.write("auth/app-id/map/app-id/foo", %{"value" => "root", "display_name" => "foo"})
Vaultex.Client.write("auth/app-id/map/user-id/bar", %{"value" => "foo"})

# setup transit backend
Vaultex.Client.write("sys/mounts/transit", %{"type" => "transit"})
Vaultex.Client.write("transit/keys/foo")

