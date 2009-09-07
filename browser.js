// Cross-browser AJAX.
function getXMLHttpRequest()
{
    if (window.XMLHttpRequest) {
        return new XMLHttpRequest()
    }
    else if (window.ActiveXObject) {
        return new ActiveXObject("Microsoft.XMLHTTP")
    }
    else {
        return null;
    }
}

// Taken from http://aymanh.com/9-javascript-tips-you-may-not-know
function AssertException(message) { this.message = message; }
AssertException.prototype.toString = function () {
    return 'AssertException: ' + this.message;
}
function assert(exp, message) {
    if (! exp) {
        if (message)
            alert("ERROR: " + message);
        throw new AssertException(message);
    }
}
function assert_is_arraylike(expr, message) {
    assert((! (expr == null)) && typeof(expr.length) == "number", message)
}

function getDirJSON(dir, callback) {
    xmlhttp = getXMLHttpRequest();
    xmlhttp.open('GET', 'ajax_dirlist.pl?dir=' + escape(dir), true);
    xmlhttp.onreadystatechange = function () {
        if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
            callback(eval(xmlhttp.responseText));
        }
    }
    xmlhttp.send(null);
}

// Cross-browser.
function stop_event_propagating(e) {
    if (! e) var e = window.event;
    e.cancelBubble = true;
    if (e.stopPropagation) e.stopPropagation();
}

function drawDir(path, tree, embedded) {
    assert_is_arraylike(tree);

    var ul = document.createElement("ul");
    ul.className = "dirlist";

    /*if (embedded) {
        var li = document.createElement("li");
        li.className = "linknode";
        var a = document.createElement("a");
        a.className = "linknode";
        a.href = "";
        a.innerHTML = "[open this folder]";
        a.onclick = function () { alert("CLICK"); }
        li.appendChild(a);
        ul.appendChild(li);
    }*/

    for (var i = 1; i < tree.length; ++i) {
        (function (li, subdir) {

        ul.appendChild(li);
        li.appendChild(document.createTextNode(tree[i][1]));
        li.className = "node " + (tree[i][0] ? "dir" : "file");
        li.open = false;

        // Cross-browser fancy event adding (note that IE always uses bubbling, so no need to specify).
        li.addEventListender = li.addEventListener ? li.addEventListener : function (name, func, capture) { li.attachEvent(name, func); };

        if (tree[i][0]) { // If it's a dir.
            li.addEventListener('click', function(e) { // So we can specify event handling in the 'bubble' phase.
                if (! li.open) {
                     var lp = document.createElement("p");
                     var tn = document.createTextNode("loading...");
                     lp.appendChild(tn);
                     li.appendChild(lp);
                     getDirJSON(subdir, function (json) {
                         var nul = drawDir(subdir, json, true);
                         li.open = true;
                         li.removeChild(lp);
                         li.appendChild(nul);
                         li.className = "node opendir";
                     });
                }
                else {
                    for (var j = 0; j < li.childNodes.length; ++j) {
                        if (li.childNodes[j].tagName == "UL") {
                            li.removeChild(li.childNodes[j]);
                            li.open = false;
                            li.className = "node dir";
                        }
                    }
                }

                // Prevent the event from propagating (cross browser).
                stop_event_propagating(e);
            }, false); // False for 'bubble'.
        }
        else {
            // If it's a file, we just want to stop the event from propagating to the parent and closing it.
            li.addEventListener('click', function(e) { stop_event_propagating(e); }, false); // False for 'bubble'.
        }

        })(document.createElement("li"), path + (path.match(/\/$/) ? '' : '/') + tree[i][1]);
    }

    return ul;
}
