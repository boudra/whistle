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

  document.addEventListener("DOMContentLoaded", function(event) {
    var programs = document.querySelectorAll("[data-whistle-program]");

    programs.forEach(function(node) {
      var socketUrl = node.getAttribute("data-whistle-socket");
      var programName = node.getAttribute("data-whistle-program");
      var params = node.getAttribute("data-whistle-params");
      var socket = exports.open(socketUrl);
      var program = socket.mount(node, programName, JSON.parse(params));
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

  function findNodeByPath(parent, path) {
    return path.reduce(function(node, index) {
      var child = node.childNodes[index];
      if(child instanceof DocumentType) {
        child = child.nextSibling;
      }
      return child;
    }, parent);
  }

  function toVirtualDom(node) {
    if(!node) {
      return null;
    }

    if(node.nodeType == 3) {
      return node.nodeValue;
    }

    var tag = node.nodeName.toLowerCase();

    if(tag == "whistle-program") {
      return [
        "program",
        node.getAttribute("data-whistle-program"),
        JSON.parse(node.getAttribute("data-whistle-params"))
      ];
    }

    var attributes = Array.prototype.map.call(node.attributes, function(e) {
      var value = e.value;
      if(value === "true") {
        value = true;
      }
      return [e.name, value];
    });

    var children = Array.prototype.map.call(node.childNodes, function(child) {
      return toVirtualDom(child);
    });

    return [tag, attributes, children];
  }

  function Program(socket, elem, route, params) {
    var self = this;

    if(elem == elem.ownerDocument.documentElement) {
      elem = elem.ownerDocument;
    }

    this.hooks = {};
    this.name = route;
    this.socket = socket;
    this.params = params || {};
    this.rootElement = elem;
    this.listeners = [];
    this.eventHandlers = {};
    this.id = null;
    this.state = 0;
    this.joinResponseHandler = null;

    this.leave = function() {
      this.state = 2;
      if(this.id) {
        this.socket.send({
          type: "leave",
          program: this.id
        });
        this.state = 3;
      }
    }

    this.join = function() {
      if(this.joinResponseHandler) {
        return;
      }

      var initialDom = null;
      var requestId = this.name + "-" + (Math.random().toString(36).substr(2, 5));

      // If we're in fullscreen mode, get the root element's DOM
      if(!this.rootElement.ownerDocument) {
        initialDom = toVirtualDom(this.rootElement.documentElement);
      } else {
        initialDom = toVirtualDom(this.rootElement.childNodes[0]);
      }

      this.socket.send({
        type: "join",
        requestId: requestId,
        program: this.name,
        params: this.params,
        dom: initialDom
      });

      this.joinResponseHandler = function(data) {
        if(data.requestId == requestId) {
          self.id = data.programId;
          self.socket.removeListener("message", self.joinResponseHandler);

          if(self.state == 2) {
            self.leave();
            return;
          }

          self.state = 1;

          self.joinResponseHandler = null;

          var msgListener = self.socket.onMessageFor(self.id, function(data) {
            if(data.type == "render") {
              var patches = data.dom_patches;

              patches.forEach(function(patch) {
                switch(patch[0]) {
                  case 2:
                    {
                      var parent = findNodeByPath(self.rootElement, patch[1]);
                      var node = renderVirtualDom(patch[2]);
                      parent.appendChild(node);
                      self.callHooks("creatingElement", node);
                    }
                    break;

                  case 3:
                    {
                      var oldNode = findNodeByPath(self.rootElement, patch[1]);
                      self.unmountPrograms(oldNode);
                      self.callHooks("removingElement", oldNode);

                      var node = renderVirtualDom(patch[2]);
                      oldNode.replaceWith(node);
                      self.callHooks("creatingElement", node);
                    }
                    break;

                  case 4:
                    {
                      var node = findNodeByPath(self.rootElement, patch[1]);
                      self.unmountPrograms(node);
                      self.callHooks("removingElement", node);
                      node.remove();
                    }
                    break;

                  case 5:
                    {
                      var replaceTarget = findNodeByPath(self.rootElement, patch[1]);
                      setAttribute(replaceTarget, patch[2][0], patch[2][1]);
                    }
                    break;

                  case 7:
                    {
                      var node = findNodeByPath(self.rootElement, patch[1]);
                      var handler = patch[2];
                      var key = patch[1].join(".");
                      var fun = null;

                      if(handler.event === "history") {
                        fun = function(e) {
                          self.socket.send({
                            type: "event",
                            program: self.id,
                            handler: key + "." + handler.event,
                            args: [e.state.path]
                          });
                        }

                        window.addEventListener("popstate", fun);
                      } else {
                        fun = function(e) {
                          if(handler.prevent_default) {
                            e.preventDefault();
                          }

                          var args = [];

                          if(["change", "input", "submit"].indexOf(e.type) >= 0) {
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
                            program: self.id,
                            handler: key + "." + handler.event,
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

                      self.eventHandlers[key + "." + handler.event] = fun;
                    }
                    break;

                    // remove_event_handler
                  case 8:
                    {
                      var node = findNodeByPath(self.rootElement, patch[1]);
                      var event = patch[2];
                      var key = patch[1].join(".");
                      var fun = self.eventHandlers[key + "." + event];

                      if(event == "input") {
                        node.removeEventListener("input", fun);
                        node.removeEventListener("change", fun);
                      } else if(event == "history") {
                        window.removeEventListener("popstate", fun);
                      } else {
                        node.removeEventListener(event, fun);
                      }
                    }
                    break;

                  case 9:
                    {
                      var node = findNodeByPath(self.rootElement, patch[1]);
                      self.socket.programs.forEach(function(program) {
                        if(program.rootElement == node) {
                          self.socket.removeProgram(program.id);
                        }
                      });
                      setTimeout(function() {
                        self.socket.mount(node, patch[2], patch[3])
                      }, 0);
                    }
                    break;
                }
              });
            } else if(data.type == "msg" && data.payload[0] == "whi_navigate") {
              window.history.pushState({path: data.payload[1]}, "", data.payload[1]);
            }
          });

          self.listeners.push(["message", msgListener]);
        }
      };

      this.socket.on("message", this.joinResponseHandler);
    };

    function renderVirtualDom(vdom) {
      var node = null;

      if(typeof vdom == "string") {
        node = document.createTextNode(vdom)
      } else if (vdom[0] == "program") {
        node = document.createElement("whistle-program");
        node.setAttribute("data-whistle-program", vdom[1]);
        node.setAttribute("data-whistle-params", JSON.stringify(vdom[2]));

        self.socket.mount(node, vdom[1], vdom[2]);
      } else {
        node = document.createElement(vdom[0]);
        for (var key in vdom[1]) {
          var attributeValue = vdom[1][key];
          setAttribute(node, key, attributeValue);
        }

        vdom[2].forEach(function(child) {
          var childNode = renderVirtualDom(child);
          node.appendChild(childNode);
        });
      }

      return node;
    }

    this.unmount = function() {
      this.listeners.forEach(function(listener) {
        self.socket.removeListener(listener[0], listener[1]);
      });
    }

    this.send = function(name, payload) {
      this.socket.send({
        type: "msg",
        program: this.id,
        payload: payload
      });
    }

    this.addHook = function(name, funs) {
      this.hooks[name] = funs;
      this.callHook(name, funs, "creatingElement", this.rootElement);
    }

    this.unmountPrograms = function(target) {
      if(!target.querySelectorAll) {
        return;
      }

      var programs =
        Array.prototype.slice.call(target.querySelectorAll("[data-whistle-program]"))
          .concat([target]);

      programs.forEach(function(node) {
        self.socket.programs.forEach(function(program) {
          if(program.rootElement == node) {
            self.socket.removeProgram(program.id);
          }
        });
      });
    }

    this.callHook = function(name, funs, type, target) {
      if(typeof target.querySelector == "function") {
        var node = target.querySelector("#" + name);

        if(node && funs[type]) {
          funs[type](node);
        }
      }
    }

    this.callHooks = function(type, target) {
      for(var name in this.hooks) {
        this.callHook(name, this.hooks[name], type, target);
      }
    }

    this.on = function(event, fun) {
      var self = this;
      if(event == "join") {
        this.websocket.addEventListener("open", fun.bind(this));
      } else if(event == "message") {
        var listener = this.socket.onMessageFor(this.id, function(data) {
          if(data.type == "msg") {
            fun.call(self, data.payload);
          }
        });

        this.listeners.push(["message", listener]);
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
      var newFun = function(data) {
        if(data.program == program) {
          fun.call(self, data);
        }
      };

      return this.on("message", newFun);
    }

    this.removeProgram = function(id) {
      var index = -1;

      for(var i = 0; i < this.programs.length; i++) {
        if(this.programs[i].id == id) {
          index = i;
          break;
        }
      }

      if(index >= 0) {
        this.programs[index].unmount();
        this.programs[index].leave();
        this.programs.splice(index, 1);
      } else {
        throw "program not found";
      }
    }

    this.removeListener = function(type, fun) {
      var index = this.eventListeners[type].indexOf(fun);
      if(index >= 0) {
        this.eventListeners[type].splice(index, 1);
      }
    }

    this.on = function(event, fun, opts) {
      var self = this;
      var newFun = null;

      if(event == "message") {
        newFun = function(e) {
          var data = JSON.parse(e.data);
          if(data instanceof Array) {
            data.forEach(function(message) {
              fun.call(self, message);
            });
          } else {
            fun.call(self, data);
          }
        };
      } else {
        newFun = fun.bind(this);
      }

      this.eventListeners[event] = this.eventListeners[event] || [];
      this.eventListeners[event].push(newFun);

      return newFun;
    };

    this.send = function(data) {
      this.websocket.send(JSON.stringify(data));
    }

    this.mount = function(elem, route, params) {
      var program = new Program(this, elem, route, params)

      if(this.websocket.readyState == 1) {
        program.join();
      }

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
      setTimeout(function() {
        self.connectionRetries++;
        self.connect(self.websocketOpts);
      }, self.connectionRetries * 500);
    });

    this.on("connect", function() {
      self.connectionRetries = 1;

      self.programs.forEach(function(program) {
        program.join();
      });
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
