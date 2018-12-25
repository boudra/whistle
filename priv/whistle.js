(function(exports) {

  exports.connect = function(url) {
    var socket = new WebSocket(url);
    return socket;
  };

  exports.mount = function(socket, target, program, params) {

    socket.send(JSON.stringify({
      type: "join",
      channel: program,
      params: params
    }));

    function setAttribute(node, key, value) {
      if(key == "on") {
      } else if(key == "value") {
        node.value = value;
      } else if (key == "checked") {
        node.checked = value;
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
                socket.send(JSON.stringify({
                  type: "event",
                  channel: program,
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

    socket.addEventListener("message", (event) => {
      var data = JSON.parse(event.data);
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
    });
  }

})(typeof(exports) === "undefined" ? window.Whistle = window.Whistle || {} : exports);
