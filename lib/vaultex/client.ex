defmodule Vaultex.Client do

  require Logger
  use GenServer
  @version "v1"
  @cache Elixir.Vaultex

  def start_link() do
    GenServer.start_link(__MODULE__, %{progress: "starting"}, name: :vault)
  end

  def auth(creds) do
    GenServer.call(:vault, {:auth, creds})
  end

  def read(key) do
    GenServer.call(:vault, {:read, key})
  end

  def write(key) do
    GenServer.call(:vault, {:write, key, nil})
  end

  def write(key, data) do
    GenServer.call(:vault, {:write, key, data})
  end

  def encrypt(key, data) do
    GenServer.call(:vault, {:encrypt, key, data})
  end

  def decrypt(key, data) do
    GenServer.call(:vault, {:decrypt, key, data})
  end


# GenServer callbacks

  def init(state) do
    url = "#{get_env(:scheme)}://#{get_env(:host)}:#{get_env(:port)}/#{@version}/"
	{:ok, Map.merge(state, %{url: url})}
  end

  # authenticate and save the access token in `token`
  def handle_call({:auth, {:user_id, user_id}}, _from, state) do
    app_id = Application.get_env(:vaultex, :app_id, nil)
    # TODO should call write here now that we have it
    {:ok, req} = request(:post, "#{state.url}auth/app-id/login", %{app_id: app_id, user_id: user_id})
    Logger.debug("Got auth reponse: #{inspect req}")

	{:reply, {:ok, :authenticated}, Map.merge(state, %{token: req["auth"]["client_token"]})}
  end
  def handle_call({:auth, {:token, token}}, _from, state) do
    Logger.debug("Merged in token auth")
	{:reply, {:ok, :authenticated}, Map.merge(state, %{token: token})}
  end


  def handle_call({:read, key}, _from, state) do
    data = case :ets.lookup(@cache, key) do
      [] ->
        {:ok, req} = request(:get, state.url <> key, nil, state.token)
        Logger.debug("Got reponse: #{inspect req}")
        :ets.insert(@cache, {key, req["data"]})
        case req["lease_duration"] do
          nil -> Logger.debug("No lease duration, no need to purge the key later")
          sec ->
            # notify me and delete the ETS cache
            Logger.debug("Purge the key from our internal cache after #{sec} seconds")
            :erlang.send_after(sec, __MODULE__, {:purge, key})
        end
        req["data"]
      [{_, stuff}] -> stuff
    end
    {:reply, {:ok, data}, state}
  end

  def handle_call({:write, key, data}, _from, state) do
    case request(:post, state.url <> key, data, state.token) do
      {:ok, req} -> 
        Logger.debug("Got reponse: #{inspect req}")
        {:reply, {:ok, req}, state}
      {:error, error} ->
        Logger.debug("Got error: #{inspect error}")
        {:reply, {:error, error}, state}
    end
  end

  def handle_info({:purge, key}, state) do
    :ets.delete(@cache, key)
    Logger.info("Expired '#{key}' from cache")
    {:noreply, state}
  end


# internal helper functions

  defp request(method, url, params) do
    request(method, url, params, nil)
  end
  defp request(method, url, params, auth) do
    case get_content(method, url, params, auth) do
      {:ok, code, _headers, body_ref} ->
        {:ok, res} = :hackney.body body_ref
        Logger.debug("[body] #{inspect res}")
		case Poison.decode(res) do
		  {:ok, json} ->
			cond do
			  200 ->
				{:ok, json}
			  204 ->
				{:ok, :no_data}
			  code in 400..599 ->
				{:error, {{:http_status, code}, json}}
			  true ->
				{:error, res}
			end
		  {:error, json_err} ->
            case res do
              "" -> {:ok, :no_data}
			  _  -> {:error, json_err}
            end
		end
      error -> error
    end
  end

  defp get_content(method, url, params, auth) do
    headers = case auth do
      nil -> [{"Content-Type", "application/json"}]
      token -> 
        [{"Content-Type", "application/json"}, {"X-Vault-Token", token}]
    end
    Logger.debug("[#{method}] #{url}")
    Logger.debug("[HEADER] #{inspect headers}")

    case Poison.encode(params) do
      # empty params
      {:ok, "null"} ->
        :hackney.request(method, url, headers)
      {:ok, json} ->
        Logger.debug("[JSON] #{inspect json}")
        :hackney.request(method, url, headers, json)
      error -> error
    end
  end

  defp get_env(:host) do
      System.get_env("VAULT_PORT_8200_TCP_ADDR") || Application.get_env(:vaultex, :host) || "localhost"
  end
  defp get_env(:port) do
      System.get_env("VAULT_PORT_8200_TCP_PORT") || Application.get_env(:vaultex, :port) || 8200
  end
  defp get_env(:scheme) do
      System.get_env("VAULT_SCHEME") || Application.get_env(:vaultex, :scheme) || "http"
  end
end
