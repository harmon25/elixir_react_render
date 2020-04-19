const React = require("react");
const ReactDOM = require("react-dom");
const { BrowserRouter } = require("react-router-dom");

/**
 * Used to hydrate a root browser router component on the client.
 * @param {React.Component} App
 * @param {String} rootElementId
 */
function hydrateRouter(App, rootElementId) {
  // find root element
  const reactRoot = document.getElementById(rootElementId);
  // grab props rendered as data attribute off root element
  const props = JSON.parse(reactRoot.dataset.props);
  // create the router component, with the App as its only child.
  const router = React.createElement(BrowserRouter, {
    children: React.createElement(App, props),
  });

  // trigger hydration
  ReactDOM.hydrate(router, reactRoot);
}

/**
 * Hydrates react components that had HTML created from server.
 * Looks for divs with 'data-rendered' attributes. Gets component
 * name from the 'data-component' attribute and props from the
 * 'data-props' attribute.
 * @param {Function} componentMapper - A function that takes in a name and returns the component
 */
function hydrateClient(componentMapper) {
  const serverRenderedComponents = document.querySelectorAll("[data-rendered]");
  const serverRenderedComponentsLength = serverRenderedComponents.length;

  for (let i = 0; i < serverRenderedComponentsLength; i++) {
    const serverRenderedComponent = serverRenderedComponents[i];

    const component = componentMapper(
      serverRenderedComponent.dataset.component
    );
    const props = JSON.parse(serverRenderedComponent.dataset.props);
    const router = React.createElement(BrowserRouter, {
      children: React.createElement(component, props),
    });

    ReactDOM.hydrate(router, serverRenderedComponent);
  }
}

module.exports = {
  hydrateClient,
  hydrateRouter,
};
