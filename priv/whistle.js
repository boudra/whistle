(function(exports) {
  function setAttribute(node, key, value) {
    if(key == "on") {
    } else if(key == "value") {
      node.value = value;
    } else if (key == "checked") {
      node.checked = value;
    } else if (key == "required") {
      node.required = value;
    } else if (key == "scroll_top") {
      if(value == "bottom") {
        node.scrollTop = node.scrollHeight;
      } else {
        node.scrollTop = value;
      }
    } else{
      node.setAttribute(key, value);
    }
  }

  function renderVirtualDom(vdom) {
    var node = null;

    if(vdom[0] == "text") {
      node = document.createTextNode(vdom[2])
    } else {
      node = document.createElement(vdom[0]);
      for (var key in vdom[1]) {
        var attributeValue = vdom[1][key];
        if(key == "on") {
          attributeValue.forEach(function(eventName) {
            node.addEventListener(eventName, function(e) {
              e.preventDefault();

              socket.send(JSON.stringify({
                type: "event",
                program: program,
                handler: vdom[1].key + "." + eventName,
                arguments: [e.target.value]
              }));
            });
          });
        } else {
          setAttribute(node, key, attributeValue);
        }
      }

      vdom[2].forEach(function(child) {
        var childNode = renderVirtualDom(child);
        node.appendChild(childNode);
      });
    }

    return node;
  }

  function findNodeByPath(parent, path) {
    return path.reduce(function(node, index) {
      return node.childNodes[index];
    }, parent);
  }

  function Program(socket, elem, route, params) {
    this.hooks = {};
    this.name = route;
    this.socket = socket;
    this.params = {} || params;

    this.socket.send({
      type: "join",
      program: this.name,
      params: this.params
    });

    this.socket.websocket.addEventListener("message", (event) => {
      var data = JSON.parse(event.data);

      if(data.program != this.name) {
        return;
      }

      if(data.type == "render") {
        var patches = data.dom_patches;

        patches.forEach(function(patch) {
          switch(patch[0]) {
            case "replace_node":
              {
                var node = renderVirtualDom(patch[2]);
                findNodeByPath(target, patch[1]).replaceWith(node);
              }
              break;

            case "add_node":
              {
                var parent = findNodeByPath(target, patch[1]);
                var node = renderVirtualDom(patch[2]);
                parent.appendChild(node);
              }
              break;

            case "set_attribute":
              {
                var replaceTarget = findNodeByPath(target, patch[1]);
                setAttribute(replaceTarget, patch[2][0], patch[2][1]);
              }
              break;

            case "replace_text":
              {
                findNodeByPath(target, patch[1]).replaceWith(patch[2]);
              }
              break;
          }
        });
      }

    });

    this.send = function(name, payload) {
      this.socket.send({
        type: "msg",
        program: this.name,
        payload: payload
      });
    }

    this.hook = function(name, funs) {
      this.hooks[name] = funs;
    }

    this.on = function(event, fun) {
      if(event == "join") {
        this.websocket.addEventListener("open", fun.bind(this));
      }
    }
  };

  function Socket() {
    var self = this;

    this.programs = [];
    this.connectionRetries = 0;
    this.eventListeners = {
      connect: [],
      disconnect: [],
    };

    this.setWebsocket = function(websocket) {
      this.websocket = websocket;

      this.websocket.addEventListener("open", function() {
        self.eventListeners["connect"].forEach(function(fun) {
          fun();
        });
      });

      this.websocket.addEventListener("close", function() {
        self.eventListeners["disconnect"].forEach(function(fun) {
          fun();
        });
      });
    };

    this.connect = function(opts) {
      var websocket = new WebSocket(opts);

      this.websocketOpts = opts;
      this.setWebsocket(websocket);
    }

    this.on = function(event, fun) {
      this.eventListeners[event] = this.eventListeners[event] || [];
      this.eventListeners[event].push(fun.bind(this));
    };

    this.send = function(data) {
      this.websocket.send(JSON.stringify(data));
    }

    this.init = function(elem, route, params) {
      var program = new Program(this, elem, route, params)
      this.programs.push(program);
      return program;
    }

    this.on("disconnect", function() {
      setTimeout(function() {
        self.connectionRetries++;
        self.connect(self.websocketOpts);
      }, self.connectionRetries * 500);
    });
  }

  exports.connect = function(url) {
    var socket = new Socket();
    socket.connect(url);

    return socket;
  };

})(typeof(exports) === "undefined" ? window.Whistle = window.Whistle || {} : exports);
