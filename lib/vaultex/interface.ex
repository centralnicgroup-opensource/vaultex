defmodule Vaultex.Interface do

  require Logger
  use GenServer
  @version "v1"
  @cache Elixir.Vaultex

  def start_link(user_id) do
    GenServer.start_link(__MODULE__, %{progress: "starting", user_id: user_id}, name: :vault)
  end

  def get(key) do
    GenServer.call(:vault, {:get, key})
  end


# GenServer callbacks

  def init(state) do
    app_id = Application.get_env(:vaultex, :app_id, nil)
    url = "#{get_env(:scheme)}://#{get_env(:host)}:#{get_env(:port)}/#{@version}/"
    {:ok, req} = request(:post, "#{url}auth/app-id/login", %{app_id: app_id, user_id: state.user_id})
    Logger.debug("Got auth reponse: #{inspect req}")

	{:ok, Map.merge(state, %{url: url, token: req["auth"]["client_token"]})}
  end

  def handle_call({:get, key}, _from, state) do
    data = case :ets.lookup(@cache, key) do
      [] ->
        {:ok, req} = request(:get, state.url <> key, nil, state.token)
        Logger.debug("Got reponse: #{inspect req}")
        :ets.insert(@cache, {key, req["data"]})
        if req["lease_duration"] > 0 do
            # notify me and delete the ETS cache
            :erlang.send_after(req["lease_duration"], __MODULE__, {:purge, key})
        end
        req["data"]
      [{_, stuff}] -> stuff
    end
    {:reply, data, state}
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
			  {:error, json_err}
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
