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
    var xmlhttp = getXMLHttpRequest();
    var query = 'ajax_dirlist.pl?dir=' + escape(dir);
    xmlhttp.open('GET', query, true);
    xmlhttp.onreadystatechange = function () {
        if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
            var r = eval(xmlhttp.responseText);
            r.sort(function (x,y) { return x[1] > y[1]; });
            callback(r)
        }
    }
    xmlhttp.send(null);
}

// Cross-browser.
function getEvent(e) {
    return e || window.event;
}

// Cross-browser.
function stop_event_propagating(e) {
    if (! e) var e = window.event;
    e.cancelBubble = true;
    if (e.stopPropagation) e.stopPropagation();
}

function prevent_default(e)
{
    if (e) e.preventDefault();
}

// Cross-browser fancy event adding (note that IE always uses bubbling, so no need to specify).
function addEventListener(elem, name, func, capture)
{
    if (elem.addEventListener) {
        return elem.addEventListener(name, func, capture);
    }
    else {
        return elem.attachEvent(name, func);
    }
}

var body = document.getElementsByTagName("body")[0];

function getNormalTextPxHeight()
{
    var x = document.createElement("table");
    var x = document.createElement("div");
    x.style.visibility = "hidden";
    x.appendChild(document.createTextNode("AXpj"));
    body.appendChild(x);
    var h = x.clientHeight;
    body.removeChild(x);
    return h;
}

function getNormalTextStringPxWidth(s)
{
    var x = document.createElement("table");
    var tr = document.createElement("tr");
    var td = document.createElement("td");
    x.appendChild(tr);
    tr.appendChild(td);
    x.style.visibility = "hidden";
    td.appendChild(document.createTextNode(s));
    body.appendChild(x);
    var w = td.clientWidth;
    body.removeChild(x);
    return w;
}

function drawDir(path, tree, url_prefix, embedded) {
    assert_is_arraylike(tree);

    g_openDirs[path] = true;

    // Guaranteed to end with '/'
    full_url_prefix = url_prefix + (url_prefix.match(/\/$/) ? "" : "/") + (path.match(/^\//) ? path.substr(1) : path) + (path.match(/\/$/) ? "" : "/");

    var div = document.createElement("div");
    div.className = "dircontainer";

    function refresh () {
        getDirJSON(path, function(json) {
            var newdiv = drawDir(path, json, url_prefix, embedded);
            div.parentNode.replaceChild(newdiv, div);
        });
    }

    if (embedded) { // Don't want to alllow uploading files to root dir.
        var a = document.createElement("a");
        a.href="";
        a.className = "diraction";
        a.innerHTML = "&raquo; upload a file to this folder.";
        a.id = path + "\nupload";

        var up = new AjaxUpload(a, {
            action: "ajax_file_upload.pl",
            data: { dir: path },
            autoSubmit: true,
            responseType: false,
            onComplete: function(file, response) {
                setTimeout(function () { refresh(); }, 100);
            }
        });

        div.appendChild(a);
    }

    var ul = document.createElement("ul");
    ul.className = "dirlist";
    div.appendChild(ul);

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

    for (var i = 0; i < tree.length; ++i) {
        (function (li, subdir) {

        ul.appendChild(li);
        if (! tree[i][0]) { // If it's a file.
            var a = document.createElement("a");
            a.className = "file";
            a.href = full_url_prefix + tree[i][1];
            a.appendChild(document.createTextNode(tree[i][1]));
            li.appendChild(a);
        }
        else {
            li.appendChild(document.createTextNode(tree[i][1]));
        }
        li.className = "node " + (tree[i][0] ? "dir" : "file");

        li.locked = false; // Ingore clicks while this is true (e.g. during loading).

        if (tree[i][0]) { // If it's a dir.
            function openitup() {
                 li.locked = true;

                 li.style.listStyleImage = "url('ajax-loader.gif')";
                 getDirJSON(subdir, function (json) {
                     var nul = drawDir(subdir, json, url_prefix, true);
                     li.open = true;
                     li.appendChild(nul);
                     li.className = "node opendir";
                     li.style.listStyleImage = "url('downarrow.png')";

                     li.locked = false;
                 });
            }

            // Is it open?
            li.open = g_openDirs[subdir];
            if (li.open) { openitup(); }

            addEventListener(li, 'click', function(e) { // So we can specify event handling in the 'bubble' phase.
                if (li.locked) { return; }

                if (! li.open) {
                    openitup();
                }
                else {
                    // The finicky bit -- we don't want the subtree to close wherever the user clicks within the
                    // li that isn't contained within a nested li (e.g. the blank space to the left). Unfortunately,
                    // we just have to look at the pixel position of the event to figure out whether or not this is
                    // the case.
                    var clickScreenX = getEvent(e).layerX || getEvent(e).offsetX;
                    var clickScreenY = getEvent(e).layerY || getEvent(e).offsetY;
                    var liScreenY = li.offsetTop;
                    var linktext = li.firstChild.nodeValue; // The text in the text node.
                    var liScreenX = li.offsetLeft;
                    if ((clickScreenY - liScreenY <= getNormalTextPxHeight()) && (clickScreenX < liScreenX + 25 + getNormalTextStringPxWidth(linktext))) {
                        for (var j = 0; j < li.childNodes.length; ++j) {
                            if (li.childNodes[j].tagName == "DIV" && li.childNodes[j].className == "dircontainer") {
                                li.removeChild(li.childNodes[j]);
                                li.open = false;
                                delete g_openDirs[subdir];
                                li.className = "node dir";
                                li.style.listStyleImage = "url('arrow.png')";
                            }
                        }
                    }
                }

                // Prevent the event from propagating (cross browser).
                stop_event_propagating(e);
            }, false); // False for 'bubble'.
        }
        else {
            // If it's a file, we just want to stop the event from propagating to the parent and closing it.
            addEventListener(li, 'click', function(e) { stop_event_propagating(e); }, false); // False for 'bubble'.
        }

        })(document.createElement("li"), path + (path.match(/\/$/) ? '' : '/') + tree[i][1]);
    }

    return div;
}
