const ReactServer = require("react-dom/server");
const React = require("react");

// this is not being used?
// const readline = require("readline");

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

function render(componentPath, props) {
  try {
    const component = requireComponent(componentPath);
    const Component = component.default ? component.default : component;
    // const createdElement = React.createElement(element, props);

    const markup = ReactServer.renderToString(<Component {...props} />);

    return {
      error: null,
      markup: markup,
      component: Component.name,
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

module.exports = {
  render,
};
