# ReactRender

[![Build Status](https://travis-ci.org/revelrylabs/elixir_react_render.svg?branch=master)](https://travis-ci.org/revelrylabs/elixir_react_render)
[![Hex.pm](https://img.shields.io/hexpm/dt/react_render.svg)](https://hex.pm/packages/react_render)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage Status](https://opencov.prod.revelry.net/projects/11/badge.svg)](https://opencov.prod.revelry.net/projects/11)

Renders React as HTML

## Documentation

The docs can
be found at [https://hexdocs.pm/react_render](https://hexdocs.pm/react_render).

## Installation

```elixir
def deps do
  [
    {:react_render, "~> 3.0.0"}
  ]
end
```

## Getting Started with Phoenix

- Add `react_render` to your dependencies in package.json

  ```js
  "react_render": "file:../deps/react_render"
  ```

- Run `npm install`

  ```bash
  npm install
  ```

- Create a file named `render_server.js` in your `assets` folder and add the following

  ```js
  require("@babel/polyfill");
  require("@babel/register")({ cwd: __dirname });

  module.exports = require("react_render/priv/server");
  ```

- If you are doing server rendering that includes split chunks, or some css-in-js that emitts tags to be injected, a customized render method can be defined:

  ```js
  require("@babel/polyfill");
  require("@babel/register")({ cwd: __dirname });
  // think this should work.
  const ReactServer = require("react-dom/server");
  const React = require("react");
  const path = require("path");
  const { ChunkExtractor } = require("@loadable/server");

  function deleteCache(componentPath) {
    if (
      process.env.NODE_ENV !== "production" &&
      require.resolve(componentPath) in require.cache
    ) {
      delete require.cache[require.resolve(componentPath)];
    }
  }

  function requireComponent(componentPath) {
    // remove from cache in non-production environments
    // so that we can see changes
    deleteCache(componentPath);
    return require(componentPath);
  }

  function customRender(componentPath, props) {
    try {
      const component = requireComponent(componentPath);
      const element = component.default ? component.default : component;
      const createdElement = React.createElement(element, props);

      const statsFilePath = path.resolve(
        "./priv/static/js/loadable-stats.json"
      );
      const extractor = new ChunkExtractor({
        statsFile: statsFilePath,
        entrypoints: ["app"],
      });

      const markup = ReactServer.renderToString(createdElement);

      const scriptTags = extractor.getScriptTags(); // or extractor.getScriptElements();
      // You can also collect your "preload/prefetch" links
      const linkTags = extractor.getLinkTags(); // or extractor.getLinkElements();

      return {
        error: null,
        markup,
        component: element.name,
        meta: { tags: { scriptTags, linkTags } },
      };
    } catch (err) {
      return {
        args: { componentPath, props },
        path: componentPath,
        error: {
          type: err.constructor.name,
          message: err.message,
          stack: err.stack,
        },
        markup: null,
        component: null,
      };
    }
  }

  module.exports = { render: customRender };
  ```

Note: You must move any `@babel` used for server-side rendering from `devDependencies` to `dependencies` in your `package.json` file. This is required when installing dependencies required for production as these packages.

- Add `ReactRender` to your Supervisor as a child. We're using the absolute path to ensure we are specifying the correct working directory that contains the `render_server.js` file we created earlier.

```elixir
render_service_path = "#{File.cwd!}/assets"
pool_size = 4

supervisor(ReactRender, [[render_service_path: render_service_path, pool_size: 4]])
```

- Create a react component like:

  ```js
  import React, { Component, createElement } from "react";

  class HelloWorld extends Component {
    render() {
      const { name } = this.props;

      return <div>Hello {name}</div>;
    }
  }

  export default HelloWorld;
  ```

- Call `ReactRender.render/2` inside the action of your controller

  ```elixir
  def index(conn, _params) do
    component_path = "#{File.cwd!}/assets/js/HelloWorld.js"
    props = %{name: "Revelry"}

    { :safe, helloWorld } = ReactRender.render(component_path, props)

    render(conn, "index.html", helloWorldComponent: helloWorld)
  end
  ```

  `component_path` can either be an absolute path or one relative to the render service. The stipulation is that components must be in the same path or a sub directory of the render service. This is so that the babel compiler will be able to compile it. The service will make sure that any changes you make are picked up. It does this by removing the component_path from node's `require` cache. If do not want this to happen, make sure to add `NODE_ENV` to your environment variables with the value `production`.

- Render the component in the template

  ```elixir
  <%= raw @helloWorldComponent %>
  ```

- To hydrate server-created components in the client, add the following to your `app.js`

  ```js
  import { hydrateClient } from "react_render/priv/client";
  import HelloWorld from "./HelloWorld.js";

  function getComponentFromStringName(stringName) {
    // Map string component names to your react components here
    if (stringName === "HelloWorld") {
      return HelloWorld;
    }

    return null;
  }

  hydrateClient(getComponentFromStringName);
  ```

- Update `assets/webpack.config` to include under the `resolve` section so that module resolution is handled properly:

  ```
  resolve: {
    symlinks: false
  }
  ```
