defmodule ReactRender do
  use Supervisor

  @timeout 10_000
  @default_pool_size 4

  @type rendered_component :: binary()
  @type component_path :: binary()
  @type props :: map()
  @type meta :: map()
  @type root_opts :: Keyword.t()

  @moduledoc """
  React Renderer
  """

  @doc """
  Starts the ReactRender and workers.

  ## Options
    * `:render_service_path` - (required) is the path to the react render service relative
  to your current working directory
    * `:pool_size` - (optional) the number of workers. Defaults to 4
  """
  @spec start_link(keyword()) :: {:ok, pid} | {:error, any()}
  def start_link(args) do
    default_options = [pool_size: @default_pool_size]
    opts = Keyword.merge(default_options, args)

    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stops the ReactRender and underlying node react render service
  """
  @spec stop() :: :ok
  def stop() do
    Supervisor.stop(__MODULE__)
  end

  @doc """
  Given the `component_path` and `props`, returns html.

  `component_path` is the path to your react component module relative
  to the render service.

  `props` is a map of props given to the component. Must be able to turn into
  json
  """
  @spec get_html(component_path(), props()) :: {:ok, rendered_component()} | {:error, map()}
  def get_html(component_path, props \\ %{}) do
    case do_get_html(component_path, props) do
      {:error, _} = error ->
        error

      {:ok, %{"markup" => markup}} ->
        {:ok, markup}
    end
  end

  @doc """
  Same as `get_html/2` but wraps html in a div which is used
  to hydrate react component on client side.

  This is the preferred function when using with Phoenix

  `component_path` is the path to your react component module relative
  to the render service.

  `props` is a map of props given to the component. Must be able to turn into json
  """
  @spec render(component_path(), props()) :: {:safe, rendered_component()}
  def render(component_path, props \\ %{}) do
    case do_get_html(component_path, props) do
      {:error, %{message: message, stack: stack}} ->
        raise ReactRender.RenderError, message: message, stack: stack

      {:ok, %{"markup" => markup, "component" => component}} ->
        encoded_props = Jason.encode!(props) |> String.replace("\"", "&quot;")

        html =
          "<div data-rendered data-component=\"#{component}\" data-props=\"#{encoded_props}\">" <>
            markup <> "</div>"

        {:safe, html}
    end
  end

  @doc """
  Given the `component_path` and `props`, returns html.

  `component_path` is the path to your react component module relative
  to the render service.

  `props` is a map of props given to the component. Must be able to turn into json

  This differs slightly from `render/2` in that its' container element is intended to house a full page react application.
  There is also consideration of data being passed back to elixir that is not just the rendered content, but other data (meta).
  This is to handle things like split chunks, and styled-component tags that also need to be injected into the page.
  This lets us choose what we want to do with them, and inject accordingly in eex, just like the main content.

  In order to do this the render_server file needs to override the render method with a custom render method that passes back the meta key.
  See README for an example.

  This version should be paired with the `hydrateRoot` js function in the client that only considers hydrating the single react tree on the page.
  """
  @spec render_root(component_path(), props(), root_opts()) ::
          {{:safe, rendered_component()}, meta()}
  def render_root(component_path, props, opts \\ []) do
    root_id = Keyword.get(opts, :root_id, "react-root")

    case do_get_root_html(component_path, props) do
      {:error, %{message: message, stack: stack}} ->
        raise ReactRender.RenderError, message: message, stack: stack

      # handle case when meta is passed back from node renderer
      {:ok, %{"markup" => markup, "component" => component, "meta" => meta}} ->
        {gen_html(root_id, markup, component, props), meta}

      {:ok, %{"markup" => markup, "component" => component}} ->
        {gen_html(root_id, markup, component, props), %{}}
    end
  end

  defp gen_html(root_id, markup, component, props) do
    encoded_props = Jason.encode!(props) |> String.replace("\"", "&quot;")

    html =
      "<div id=\"#{root_id}\" data-component=\"#{component}\" data-props=\"#{encoded_props}\">" <>
        markup <> "</div>"

    {:safe, html}
  end

  defp do_get_root_html(component_path, props) do
    # do not think this needs to be in a task, is likely already being called in an isolated request process...
    NodeJS.call(
      {:render_server, :render},
      [component_path, props],
      binary: true
    )
    |> case do
      {:ok, %{"error" => error}} when not is_nil(error) ->
        normalized_error = %{
          message: error["message"],
          stack: error["stack"]
        }

        {:error, normalized_error}

      ok ->
        ok
    end
  end

  defp do_get_html(component_path, props) do
    task =
      Task.async(fn ->
        NodeJS.call({:render_server, :render}, [component_path, props], binary: true)
      end)

    case Task.await(task, @timeout) do
      {:ok, %{"error" => error}} when not is_nil(error) ->
        normalized_error = %{
          message: error["message"],
          stack: error["stack"]
        }

        {:error, normalized_error}

      {:ok, result} ->
        {:ok, result}
    end
  end

  # --- Supervisor Callbacks ---
  @doc false
  def init(opts) do
    pool_size = Keyword.fetch!(opts, :pool_size)
    render_service_path = Keyword.fetch!(opts, :render_service_path)

    children =
      case Application.get_application(:nodejs) do
        nil ->
          [
            supervisor(NodeJS.Supervisor, [
              [path: render_service_path, pool_size: pool_size]
            ])
          ]

        _ ->
          []
      end

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
