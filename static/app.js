let socket = new WebSocket("ws://localhost:4000/ws/1")
let target = document.querySelector("#target");

function renderVirtualDom(parent, vdom) {
  if(vdom[0] == "text") {
    let node = document.createTextNode(vdom[2])
    parent.appendChild(node);
  } else {
    let node = document.createElement(vdom[0]);
    node.attributes = vdom[1];
    parent.appendChild(node);
    vdom[2].forEach(function(child) {
      renderVirtualDom(node, child);
    });
  }
}

function findNodeByPath(parent, path) {
  return path.reduce(function(node, index) {
    return node.childNodes[index];
  }, parent);
}

socket.addEventListener("open", (event) => {
  socket.send("hola");
})

socket.addEventListener("message", (event) => {
  let patches = JSON.parse(event.data);
  console.log(patches);

  patches.forEach(function(patch) {
    switch(patch[0]) {
      case "replace_node":
        {
          let replaceTarget = findNodeByPath(target, patch[1]);
          renderVirtualDom(replaceTarget, patch[2]);
        }
        break;

      case "replace_text":
        {
          findNodeByPath(target, patch[1]).replaceWith(patch[2]);
        }
        break;
    }
  });
})

