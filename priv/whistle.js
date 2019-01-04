(function(exports) {
  var sockets = {};

  exports.open = function(url) {
    if(sockets[url]) {
      return sockets[url];
    }

    var socket = new Socket();
    socket.connect(url);

    sockets[url] = socket;

    return socket;
  };

  var programs = document.querySelectorAll("[data-whistle-program]");

  programs.forEach(function(node) {
    var socketUrl = node.getAttribute("data-whistle-socket");
    var programName = node.getAttribute("data-whistle-program");
    var params = node.getAttribute("data-whistle-params");
    var socket = exports.open(socketUrl);

    socket.on("connect", function() {
      var program = this.mount(node, programName, JSON.parse(params));
    });
  });

  function setAttribute(node, key, value) {
    if(key == "value") {
      node.value = value;
    } else if (key == "checked") {
      node.checked = value;
    } else if (key == "required") {
      node.required = value;
    } else {
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
    var self = this;

    this.hooks = {};
    this.name = route;
    this.socket = socket;
    this.params = {} || params;
    this.rootElement = elem;

    this.socket.send({
      type: "join",
      program: this.name,
      params: this.params,
      dom: this.rootElement.innerHTML
    });

    this.socket.onMessageFor(this.name, function(data) {
      if(data.type == "render") {
        var patches = data.dom_patches;

        patches.forEach(function(patch) {
          switch(patch[0]) {
            case 3:
              {
                var node = renderVirtualDom(patch[2]);
                var oldNode = findNodeByPath(self.rootElement, patch[1]);
                self.__callHooks("removingElement", oldNode);
                oldNode.replaceWith(node);
                self.__callHooks("creatingElement", node);
              }
              break;

            case 4:
              {
                var node = findNodeByPath(self.rootElement, patch[1]);
                self.__callHooks("removingElement", oldNode);
                node.remove(node);
              }
              break;

            case 2:
              {
                var parent = findNodeByPath(self.rootElement, patch[1]);
                var node = renderVirtualDom(patch[2]);
                parent.appendChild(node);
                self.__callHooks("creatingElement", node);
              }
              break;

            case 5:
              {
                var replaceTarget = findNodeByPath(self.rootElement, patch[1]);
                setAttribute(replaceTarget, patch[2][0], patch[2][1]);
              }
              break;

            case 1:
              {
                findNodeByPath(self.rootElement, patch[1]).replaceWith(patch[2]);
              }
              break;

            case 7:
              {
                var node = findNodeByPath(self.rootElement, patch[1]);
                var handler = patch[2];

                var fun = function(e) {
                  if(handler.prevent_default) {
                    e.preventDefault();
                  }

                  var args = [];

                  if(["change", "input"].indexOf(e.type) >= 0) {
                    if(e.target.tagName.toLowerCase() == "form") {

                      var formValue =
                        Array.prototype.reduce.call(e.target.elements, function(obj, node) {
                          if(node.name && node.name.length > 0) {
                            obj[node.name] = node.value;
                            return obj;
                          } else {
                            return obj;
                          }
                        }, {});

                      args = [formValue];
                    } else {
                      args = [e.target.value];
                    }
                  }

                  self.socket.send({
                    type: "event",
                    program: self.name,
                    handler: patch[1].join(".") + "." + handler.event,
                    args: args
                  });
                };

                if(handler.event == "input") {
                  fun = debounceInputEvent(fun, 250);

                  node.addEventListener("input", fun);
                  node.addEventListener("change", fun);
                } else {
                  node.addEventListener(handler.event, fun);
                }
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

    this.addHook = function(name, funs) {
      this.hooks[name] = funs;
      this.__callHook(name, funs, "creatingElement", this.rootElement);
    }

    this.__callHook = function(name, funs, type, target) {
      if(typeof target.querySelector == "function") {
        var node = target.querySelector("#" + name);

        if(node && funs[type]) {
          funs[type](node);
        }
      }
    }

    this.__callHooks = function(type, target) {
      for(var name in this.hooks) {
        this.__callHook(name, this.hooks[name], type, target);
      }
    }

    this.on = function(event, fun) {
      var self = this;
      if(event == "join") {
        this.websocket.addEventListener("open", fun.bind(this));
      } else if(event == "message") {
        this.socket.onMessageFor(this.name, function(data) {
          if(data.type == "message") {
            fun.call(self, data.payload);
          }
        });
      }
    }
  };

  function Socket() {
    var self = this;

    this.programs = [];
    this.connectionRetries = 1;
    this.eventListeners = {
      connect: [],
      disconnect: [],
      message: []
    };

    function websocketOnOpen(e) {
      self.eventListeners["connect"].forEach(function(fun) {
        fun.call(self, e);
      });
    }

    function websocketOnClose(e) {
      self.eventListeners["disconnect"].forEach(function(fun) {
        fun(e);
      });
    }

    function websocketOnMessage(e) {
      self.eventListeners["message"].forEach(function(fun) {
        fun(e);
      });
    }

    this.setWebsocket = function(websocket) {
      if(this.websocket) {
        this.websocket.removeEventListener("open", websocketOnOpen);
        this.websocket.removeEventListener("close", websocketOnClose);
        this.websocket.removeEventListener("message", websocketOnMessage);
      }

      this.websocket = websocket;

      this.websocket.addEventListener("open", websocketOnOpen);
      this.websocket.addEventListener("close", websocketOnClose);
      this.websocket.addEventListener("message", websocketOnMessage);
    };

    this.connect = function(opts) {
      var websocket = new WebSocket(opts);

      this.websocketOpts = opts;
      this.setWebsocket(websocket);
    }

    this.onMessageFor = function(program, fun) {
      this.eventListeners["message"].push(function(e) {
        var data = JSON.parse(e.data);
        if(data.program == program) {
          fun.call(self, data);
        }
      });
    }

    this.on = function(event, fun, opts) {
      this.eventListeners[event] = this.eventListeners[event] || [];
      this.eventListeners[event].push(fun.bind(this));
    };

    this.send = function(data) {
      this.websocket.send(JSON.stringify(data));
    }

    this.mount = function(elem, route, params) {
      var program = new Program(this, elem, route, params)

      this.programs.push(program);
      return program;
    }

    this.getProgram = function(name) {
      var program = null;

      for(var i = 0; i < this.programs.length; i++) {
        if(this.programs[i].name == name) {
          program = this.programs[i];
        }
      }

      return program;
    }

    this.on("disconnect", function() {
      self.eventListeners["message"] = [];

      setTimeout(function() {
        self.connectionRetries++;
        self.connect(self.websocketOpts);
      }, self.connectionRetries * 200);
    });
  }

  function debounceInputEvent(func, wait) {
    wait = wait || 100;
    var timeout;

    return function(event) {
      var self = this;
      clearTimeout(timeout);

      if(event.type == "change") {
        func.call(self, event);
      } else {
        timeout = setTimeout(function() {
          func.call(self, event);
        }, wait);
      }
    };
  }

})(typeof(exports) === "undefined" ? window.Whistle = window.Whistle || {} : exports);
