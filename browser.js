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

function drawSingleLevel(tree, embedded) {
    assert_is_arraylike(tree);

    var ul = document.createElement("ul");
    ul.class = "dirlist";

    if (embedded) {
        var li = document.createElement("li");
        li.className = "linknode";
        var a = document.createElement("a");
        a.className = "linknode";
        a.href = "";
        a.innerHTML = "&rarr;open this folder";
        a.onclick = function () { alert("CLICK"); }
        li.appendChild(a);
        ul.appendChild(li);
    }

    for (var i = 1; i < tree.length; ++i) {
        var li = document.createElement("li");
        ul.appendChild(li);
        li.appendChild(document.createTextNode(typeof(tree[i]) == "string" ? tree[i] : tree[i][0]));
        li.className = "node " + (typeof(tree[i]) == "string" ? "file" : "dir");
        li.open = false;

        if (typeof(tree[i]) != "string") {
            (function(i, li) { // No true lexical scoping with 'var'.
                li.onclick = function () {
                    if (li.open) {
                        ul.removeChild(li.open);
                        li.open = false;
                    }
                    else {
                        var r = drawSingleLevel(tree[i], true);
                        li.open = r;
                        ul.insertBefore(r, li.nextSibling);
                    }
                }
            })(i, li);
        }
    }

    return ul;
}