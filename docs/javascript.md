# Javascript API

Whistle uses Javascript in the client to apply Virtual DOM patches, attach event handlers and manage Websocket communication. 

While we try to do this without making you write any actual Javascript through various helpers. But we also provide a Javscript API for when you need to do advanced client-side logic like uploading files, fancy transitions etc.

As always, you can include the file directly in your HTML

```html
<script src="/js/whistle.js"></script>
<script>
  // whistle will detect is being included in HTML and put the api in window.Whistle
  assert(window.Whistle !== undefined)
</script>
```

or import it as a Javscript module, with a build tool like Webpack:
 
```js
import { Whistle } from 'js/whistle';
```

# Opening a connection to a router

You can use the method `open` for that, it takes the Websocket handler URL and it will return a socket object, you can call this as many times as you want, we will always only open one connection per URL.

```js
const socket = Whistle.open("ws://localhost:4000/socket");
```

Remember that you can always use the helper to get the router URL:

```js
const routerUrl = "<%= Whistle.Router.url(conn, MyAppWeb.ProgramRouter) %>";
const socket = Whistle.open(routerUrl);
```

# Mounting programs

```js
const socket = Whistle.open("ws://localhost:4000/socket");
const root = document.getElementById("target");
const counter = socket.mount(root, "counter");

counter.on("join", () {
  console.log("component mounted!");
});
```

# Lifecycle Hooks

Lifecycle hooks are a way to hook functions when elements are created or deleted, this way you can attach events or do anything you would normally do in a client side framework.

```js
const socket = Whistle.open("ws://localhost:4000/socket");
const root = document.getElementById("target");
const counter = socket.mount(root, "counter");

counter.addHook("button", {
  creatingElement(node) {
    node.addEventListener("click", e => {
      e.preventDefault();
      alert("hello world!");
    });
  },
  removingElement(node) {
    console.log("removing element");
  }
});
```
